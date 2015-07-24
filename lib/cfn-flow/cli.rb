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

    desc 'publish TEMPLATE [...]', 'Validate & upload templates to the CFN_FLOW_DEV_NAME prefix'
    method_option 'dev-name', type: :string, desc: 'Personal development prefix'
    method_option :release,   type: :string, desc: 'Upload release', lazy_default: CfnFlow::Git.sha
    method_option :verbose,   type: :boolean, desc: 'Verbose output', default: false
    def publish(*templates)

      # TODO: test this
      invoke :validate
      CfnFlow::Git.check_status if options['release']

      validate
      @templates.each do |t|
        say "Uploading #{t.from} to #{t.url}"
        t.upload!
      end

    end

    ##
    # Stack methods

    desc 'deploy ENVIRONMENT', 'Launch a stack'
    def deploy(environment)
      # TODO

      # Invoke events?
      invoke :events

      # Optionally invoke cleanup
      invoke :cleanup, '--exclude', stack_name
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

      table_header = options['no-header'] ? [] : [['NAME',  'ENVIRONMENT', 'STATUS']]
      table_data = stacks.map do |s|
        env_tag = s.tags.detect {|tag| tag.key == 'CfnFlowEnvironment'}
        env = env_tag ? env_tag.value : 'NONE'

        [ s.name, env, s.stack_status ]
      end

      print_table(table_header + table_data)
    end

    desc 'show STACK', 'Show details about STACK'
    method_option :json, type: :boolean, desc: 'Show stack as JSON (default is YAML)'
    def show(name)
      data = find_stack_in_service(name).data.to_hash
      say options[:json] ? MultiJson.dump(data, pretty: true) : data.to_yaml
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

    def publish_prefix
      # Add the release or dev name to the prefix
      parts = []
      parts << options['to']
      if options['release']
        parts += [ 'release',  options['release'] ]
      else
        parts += [ 'dev', options['dev-name'] ]
      end
      File.join(*parts)
    end
  end
end
