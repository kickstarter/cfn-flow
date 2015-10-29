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

      # Dup & symbolize keys
      params = config['stack'].map{|k,v| [k.to_sym, v]}.to_h

      # Expand params
      if params[:parameters].is_a? Hash
        expanded_params = params[:parameters].map do |key,value|
          { parameter_key: key, parameter_value: value }
        end
        params[:parameters] = expanded_params
      end

      # Expand tags
      if params[:tags].is_a? Hash
        tags = params[:tags].map do |key, value|
          {key: key, value: value}
        end

        params[:tags] = tags
      end

      # Append CfnFlow tags
      params[:tags] ||= []
      params[:tags] << { key: 'CfnFlowService', value: service }
      params[:tags] << { key: 'CfnFlowEnvironment', value: environment }

      # Expand template body
      if params[:template_body].is_a? String
        begin
          body = CfnFlow::Template.new(params[:template_body]).to_json
          params[:template_body] = body
        rescue CfnFlow::Template::Error
          # Do nothing
        end
      end

      params
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
require 'cfn_flow/template'
require 'cfn_flow/git'
require 'cfn_flow/event_presenter'
require 'cfn_flow/cli'
require 'cfn_flow/version'
