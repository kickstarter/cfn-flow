module CfnFlow
  class CLI < Thor

    def self.exit_on_failure?
      CfnFlow.exit_on_failure?
    end

    ##
    # Template methods

    desc 'validate TEMPLATE [...]', 'Validates templates'
    def validate(*templates)

      if templates.empty?
        raise Thor::RequiredArgumentMissingError.new('You must specify a template to validate')
      end

      templates.map{|path| Template.new(path) }.each do |template|
        say "Validating #{template.local_path}... "
        template.validate!
        say 'valid.', :green
      end
    rescue Aws::CloudFormation::Errors::ValidationError => e
      raise Thor::Error.new("Invalid template. Message: #{e.message}")
    rescue CfnFlow::Template::Error => e
      raise Thor::Error.new("Error loading template. (#{e.class}) Message: #{e.message}")
    end

    desc 'publish TEMPLATE [...]', 'Validate & upload templates'
    method_option 'dev-name', type: :string, desc: 'Personal development prefix'
    method_option :release,   type: :string, desc: 'Upload release', lazy_default: true
    method_option :verbose,   type: :boolean, desc: 'Verbose output', default: false
    def publish(*templates)
      if templates.empty?
        raise Thor::RequiredArgumentMissingError.new('You must specify a template to publish')
      end

      validate(*templates)

      release = publish_release
      templates.each do |path|
        t = Template.new(path)

        say "Publishing #{t.local_path} to #{t.url(release)}"
        t.upload(release)
      end
    end

    ##
    # Stack methods

    desc 'deploy ENVIRONMENT', 'Launch a stack'
    method_option :cleanup, type: :boolean, desc: 'Prompt to shutdown other stacks in ENVIRONMENT after launching'
    def deploy(environment)
      # Export environment as an env var so it can be interpolated in config
      ENV['CFN_FLOW_ENVIRONMENT'] = environment

      begin
        params = CfnFlow.stack_params(environment)
        stack = CfnFlow.cfn_resource.create_stack(params)
      rescue Aws::CloudFormation::Errors::ValidationError => e
        raise Thor::Error.new(e.message)
      end

      say "Launching stack #{stack.name}"

      # Invoke events
      say "Polling for events..."
      invoke :events, [stack.name], ['--poll']

      say "Stack Outputs:"
      invoke :show, [stack.name], ['--format=outputs-table']

      # Optionally cleanup other stacks in this environment
      if options[:cleanup]
        puts "Finding stacks to clean up"
        list_stacks_in_service.select {|s|
          s.name != stack.name && \
            s.tags.any? {|tag| tag.key == 'CfnFlowEnvironment' && tag.value == environment }
        }.map(&:name).each do |name|
          delete(name)
        end
      end
    end

    desc 'update ENVIRONMENT STACK', 'Updates a stack (use sparingly for mutable infrastructure)'
    def update(environment, name)
      # Export environment as an env var so it can be interpolated in config
      ENV['CFN_FLOW_ENVIRONMENT'] = environment

      stack = find_stack_in_service(name)

      # Check that environment matches
      unless stack.tags.any?{|tag| tag.key == 'CfnFlowEnvironment' && tag.value == environment }
        raise Thor::Error.new "Stack #{name} is not tagged for environment #{environment}"
      end

      begin
        params = CfnFlow.stack_params(environment)
        params.delete(:tags) # No allowed for Stack#update
        stack.update(params)
      rescue Aws::CloudFormation::Errors::ValidationError => e
        raise Thor::Error.new(e.message)
      end

      say "Updating stack #{stack.name}"

      # NB: there's a potential race condition where polling for events would
      # see the last complete state before the stack has a chance to begin updating.
      # Consider putting a sleep, wait_for an UPDATE_IN_PROGRESS state beforehand,
      # or look for events newer than the last event before updating.

      # Invoke events
      say "Polling for events..."
      invoke :events, [stack.name], ['--poll']
    end

    desc 'list [ENVIRONMENT]', 'List running stacks in all environments, or ENVIRONMENT'
    method_option 'no-header', type: :boolean, desc: 'Do not print column headers'
    def list(environment=nil)
      stacks = list_stacks_in_service
      if environment
        stacks.select! do |stack|
          stack.tags.any? {|tag| tag.key == 'CfnFlowEnvironment' && tag.value == environment }
        end
      end

      return if stacks.empty?

      table_header = options['no-header'] ? [] : [['NAME',  'ENVIRONMENT', 'STATUS', 'CREATED']]
      table_data = stacks.map do |s|
        env_tag = s.tags.detect {|tag| tag.key == 'CfnFlowEnvironment'}
        env = env_tag ? env_tag.value : 'NONE'

        [ s.name, env, s.stack_status, s.creation_time ]
      end

      print_table(table_header + table_data)
    end

    desc 'show STACK', 'Show details about STACK'
    method_option :format, type: :string, default: 'yaml', enum: %w(yaml json outputs-table), desc: "Format in which to display the stack."
    def show(name)
      formatters = {
        'json' =>          ->(stack) { say MultiJson.dump(stack.data.to_hash, pretty: true) },
        'yaml' =>          ->(stack) { say stack.data.to_hash.to_yaml },
        'outputs-table' => ->(stack) do
          outputs = stack.outputs.to_a
          if outputs.any?
            table_header = [['KEY',  'VALUE', 'DESCRIPTION']]
            table_data = outputs.map do |s|
              [ s.output_key, s.output_value, s.description ]
            end

            print_table(table_header + table_data)
          else
            say "No stack outputs to show."
          end
        end
      }
      stack = find_stack_in_service(name)
      formatters[options[:format]].call(stack)
    end

    desc 'events STACK', 'List events for  STACK'
    method_option :poll, type: :boolean, desc: 'Poll for new events until the stack is complete'
    method_option 'no-header', type: :boolean, desc: 'Do not print column headers'
    def events(name)
      stack = find_stack_in_service(name)

      say EventPresenter.header unless options['no-header']
      EventPresenter.present(stack.events) {|p| say p }

      if options[:poll]
        # Display events until we're COMPLETE/FAILED
        delay = (ENV['CFN_FLOW_EVENT_POLL_INTERVAL'] || 2).to_i
        stack.wait_until(max_attempts: -1, delay: delay) do |s|
          EventPresenter.present(s.events) {|p| say p }
          # Wait until the stack status ends with _FAILED or _COMPLETE
          s.stack_status.match(/_(FAILED|COMPLETE)$/)
        end
      end
    end

    desc 'delete STACK', 'Shut down STACK'
    method_option :force, type: :boolean, default: false, desc: 'Shut down without confirmation'
    def delete(name)
      stack = find_stack_in_service(name)
      if options[:force] || yes?("Are you sure you want to shut down #{name}?", :red)
        stack.delete
        say "Deleted stack #{name}"
      end
    end

    ##
    # Version command
    desc "version", "Prints the version information"
    def version
      say CfnFlow::VERSION
    end
    map %w(-v --version) => :version

    private
    def find_stack_in_service(name)
      stack = CfnFlow.cfn_resource.stack(name).load
      unless stack.tags.any? {|tag| tag.key == 'CfnFlowService' && tag.value == CfnFlow.service }
        raise Thor::Error.new "Stack #{name} is not tagged for service #{CfnFlow.service}"
      end
      stack
    rescue Aws::CloudFormation::Errors::ValidationError => e
      # Handle missing stacks: 'Stack with id blah does not exist'
      raise Thor::Error.new(e.message)
    end

    def list_stacks_in_service
      CfnFlow.cfn_resource.stacks.select do |stack|
        stack.tags.any? {|tag| tag.key == 'CfnFlowService' && tag.value == CfnFlow.service }
      end
    end

    def publish_release
      # Add the release or dev name to the prefix
      if options[:release]
        release = options[:release] == true ? CfnFlow::Git.sha : options[:release]
        'release/' + release
      elsif options['dev-name']
        'dev/' + options['dev-name']
      elsif ENV['CFN_FLOW_DEV_NAME']
        'dev/' + ENV['CFN_FLOW_DEV_NAME']
      else
        raise Thor::Error.new("Must specify --release or --dev-name; or set CFN_FLOW_DEV_NAME env var")
      end
    end
  end
end
