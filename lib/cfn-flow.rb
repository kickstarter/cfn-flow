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
