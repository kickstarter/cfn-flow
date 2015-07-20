require_relative 'helper'

describe 'CfnFlow' do
  subject { CfnFlow }

  describe '.config_path' do
    it 'should be ./cfn-flow.yml by default' do
      ENV.delete('CFN_FLOW_CONFIG_PATH')
      subject.config_path.must_equal 'cfn-flow.yml'
    end

    it 'can be overridden with ENV[CFN_FLOW_CONFIG_PATH]' do
      ENV['CFN_FLOW_CONFIG_PATH'] = 'foo/bar'
      subject.config_path.must_equal 'foo/bar'
    end
  end

  describe '.config_loaded?' do
    it 'should be false by default' do
      subject.config_loaded?.must_equal false
    end

    it 'should be true after loading' do
      subject.load_config
      subject.config_loaded?.must_equal true
    end
  end

  describe '.config' do
    it('should be a hash') { subject.config.must_be_kind_of(Hash) }
  end

  describe '.service' do
    it('raises an error when missing') do
      subject.instance_variable_set(:@config, {})
      error = -> { subject.service }.must_raise(Thor::Error)
      error.message.must_match 'No service name'
    end

    it('returns the service') do
      subject.instance_variable_set(:@config, {'service' => 'RoflScaler'})
      subject.service.must_equal 'RoflScaler'
    end
  end

  it '.cfn_client' do
    subject.cfn_client.must_be_kind_of Aws::CloudFormation::Client
  end

  it '.cfn_resource' do
    subject.cfn_resource.must_be_kind_of Aws::CloudFormation::Resource
    subject.cfn_resource.client.config.retry_limit.must_equal 10
  end

  describe '.exit_on_failure?' do
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
