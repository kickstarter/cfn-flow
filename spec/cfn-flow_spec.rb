require_relative 'helper'

describe 'CfnFlow' do
  subject { CfnFlow }

  it '.cfn_client' do
    subject.cfn_client.must_be_kind_of Aws::CloudFormation::Client
  end

  it '.cfn_resource' do
    subject.cfn_resource.must_be_kind_of Aws::CloudFormation::Resource
  end
end
