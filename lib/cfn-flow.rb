require 'thor'
require 'aws-sdk'
require 'multi_json'
require 'yaml'

module CfnFlow
  def self.cfn_client
    @cfn_client ||= Aws::CloudFormation::Client.new
  end

  def self.cfn_resource
    @cfn_resource ||= Aws::CloudFormation::Resource.new
  end
end

require 'cfn-flow/template'
require 'cfn-flow/git'
require 'cfn-flow/cli'
