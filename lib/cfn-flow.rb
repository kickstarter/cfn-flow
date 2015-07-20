require 'thor'
require 'aws-sdk'
require 'multi_json'
require 'yaml'
require 'erb'

module CfnFlow
  class << self

    ##
    # Configuration
    def config_path
      ENV['CFN_FLOW_CONFIG_PATH'] || 'cfn-flow.yml'
    end

    def load_config
      @config = YAML.load(
        ERB.new( File.read(config_path) ).result(binding)
      )
      # TODO: Validate config?
    end

    def config_loaded?
      @config.is_a? Hash
    end

    def config
      load_config unless config_loaded?
      @config
    end

    def service
      unless config.key?('service')
        raise Thor::Error.new("No service name in #{config_path}. Add 'service: my_app_name'.")
      end
      config['service']
    end
    ##
    # Aws Clients
    def cfn_client
      @cfn_client ||= Aws::CloudFormation::Client.new
    end

    def cfn_resource
      # NB: increase default retry limit to avoid throttling errors iterating over stacks.
      # See https://github.com/aws/aws-sdk-ruby/issues/705
      @cfn_resource ||= Aws::CloudFormation::Resource.new(retry_limit: 10)
    end

    # Clear aws sdk clients & config (for tests)
    def clear!
      @config = @cfn_client = @cfn_resource = nil
    end

    # Exit with status code = 1 when raising a Thor::Error
    # Override thor default
    def exit_on_failure?
      if instance_variable_defined?(:@exit_on_failure)
       @exit_on_failure
      else
        true
      end
    end

    def exit_on_failure=(value)
      @exit_on_failure = value
    end
  end
end

require 'cfn-flow/template'
require 'cfn-flow/git'
require 'cfn-flow/event_presenter'
require 'cfn-flow/cli'
