require_relative 'helper'

describe 'CfnFlow' do
  subject { CfnFlow }

  it '.cfn_client' do
    subject.cfn_client.must_be_kind_of Aws::CloudFormation::Client
  end

  it '.cfn_resource' do
    subject.cfn_resource.must_be_kind_of Aws::CloudFormation::Resource
  end

  describe 'exit_on_failure?' do
    it 'is true by default' do
      CfnFlow.remove_instance_variable(:@exit_on_failure) if CfnFlow.instance_variable_defined?(:@exit_on_failure)
      CfnFlow.exit_on_failure?.must_equal true
    end

    it 'can be set' do
      CfnFlow.exit_on_failure = false
      CfnFlow.exit_on_failure?.must_equal false
    end
  end
end
