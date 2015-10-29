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

    def stack_params(environment)
      unless config['stack'].is_a? Hash
        raise Thor::Error.new("No stack defined in #{config_path}. Add 'stack: ...'.")
      end
      params = StackParams.expand(config['stack'])

      params.
        add_tag('CfnFlowService' => service).
        add_tag('CfnFlowEnvironment' => environment)
    end

    def template_s3_bucket
      unless config['templates'].is_a?(Hash) &&  config['templates']['s3_bucket']
        raise Thor::Error.new("No s3_bucket defined for templates in #{config_path}. Add 'templates: { s3_bucket: ... }'.")
      end

      config['templates']['s3_bucket']
    end

    def template_s3_prefix
      unless config['templates'].is_a?(Hash)
        raise Thor::Error.new("No templates defined in #{config_path}. Add 'templates: ... '.")
      end

      # Ok for this to be ''
      config['templates']['s3_prefix']
    end

    ##
    # Aws Clients
    def cfn_client
      @cfn_client ||= Aws::CloudFormation::Client.new(region: config['region'] || ENV['AWS_REGION'])
    end

    def cfn_resource
      # NB: increase default retry limit to avoid throttling errors iterating over stacks.
      # See https://github.com/aws/aws-sdk-ruby/issues/705
      @cfn_resource ||= Aws::CloudFormation::Resource.new(
        region: config['region'] || ENV['AWS_REGION'],
        retry_limit: 10
      )
    end

    # Clear aws sdk clients & config (for tests)
    def clear!
      @config = @cfn_client = @cfn_resource = nil
      CachedStack.stack_cache.clear
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

require 'cfn_flow/cached_stack'
require 'cfn_flow/stack_params'
require 'cfn_flow/template'
require 'cfn_flow/git'
require 'cfn_flow/event_presenter'
require 'cfn_flow/cli'
require 'cfn_flow/version'
