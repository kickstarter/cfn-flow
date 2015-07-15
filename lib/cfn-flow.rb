require 'thor'
require 'aws-sdk'
require 'multi_json'
require 'yaml'

module CfnFlow
  class << self
    def cfn_client
      @cfn_client ||= Aws::CloudFormation::Client.new
    end

    def cfn_resource
      @cfn_resource ||= Aws::CloudFormation::Resource.new
    end

    # Clear aws sdk clients (for tests)
    def clear!
      @cfn_client = @cfn_resource = nil
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
require 'cfn-flow/cli'
