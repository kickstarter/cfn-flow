class CfnFlow::CLI < Thor

  def self.shared_options
    method_option :bucket,     type: :string, desc: 'S3 bucket for templates'
    method_option :to,         type: :string, desc: 'S3 path prefix for templates'
    method_option :from,       type: :string, desc: 'Local source directory for templates'
    method_option 'dev-name',  type: :string, desc: 'Personal development prefix'
    method_option :region,     type: :string, desc: 'AWS Region'
    method_option :verbose,    type: :boolean, desc: 'Verbose output', default: false
  end

  # Exit with status code = 1 when raising a Thor::Error
  # Override thor default
  def self.exit_on_failure?
    true
  end

  no_commands do
    def load_config
      defaults = { 'from' => '.' }
      file_config = begin
                      YAML.load_file(ENV['CFN_FLOW_CONFIG'] || './cfn-flow.yml')
                    rescue Errno::ENOENT
                      {}
                    end
      env_config = {
        'bucket'      => ENV['CFN_FLOW_BUCKET'],
        'to'          => ENV['CFN_FLOW_TO'],
        'from'        => ENV['CFN_FLOW_FROM'],
        'dev-name'    => ENV['CFN_FLOW_DEV_NAME'],
        'region'      => ENV['AWS_REGION']
      }.delete_if {|_,v| v.nil?}

      # Env vars override config file. Command args override env vars.
      self.options = defaults.merge(file_config).merge(env_config).merge(options)

      # Ensure region env var is set for AWS client
      ENV['AWS_REGION'] = options['region']

      # validate required options are present
      %w(region bucket to from).each do |arg|
        unless options[arg]
          raise Thor::RequiredArgumentMissingError.new("Missing required argument '#{arg}'")
        end
      end

      unless options['dev-name'] || options['release']
        raise Thor::RequiredArgumentMissingError.new("Missing either 'dev-name' or 'release' argument")
      end
    end

    shared_options
    def load_templates
      load_config
      glob = File.join(options['from'], '**/*.{yml,json,template}')

      puts Dir.glob(glob.inspect)
      @templates = Dir.glob(glob).map { |path|
        CfnFlow::Template.new(from: path, bucket: options['bucket'], prefix: prefix)
      }.select {|t|
        verbose "Checking file #{t.from}... "
        if t.is_cfn_template?
          verbose "loaded"
          true
        else
          verbose "skipped."
          false
        end
      }
    end
  end

  desc :validate, 'Validates templates'
  shared_options
  def validate
    load_templates
    @templates.each do |t|
      begin
        say "Validating #{t.from}... "
        t.validate!
        say "valid."
      rescue Aws::CloudFormation::Errors::ValidationError
        raise Thor::Error.new("Error validating #{t.from}. Message: #{$!.message}")
      end
    end
  end

  desc :upload, 'Validate & upload templates to the CFN_FLOW_DEV_NAME prefix'
  shared_options
  method_option :release, type: :string, lazy_default: CfnFlow::Git.sha, desc: 'Upload release'
  def upload
    CfnFlow::Git.check_status if options['release']

    validate
    @templates.each do |t|
      say "Uploading #{t.from} to #{t.url}"
      t.upload!
    end

  end
  default_task :upload

  private
  def verbose(msg)
    say msg if options['verbose']
  end

  def prefix
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
