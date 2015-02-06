require_relative 'helper'

describe 'CfnFlow::CLI' do
  let(:cli) { CfnFlow::CLI }

  before do
    ENV.update({
      'CFN_FLOW_BUCKET' => 'test-bucket',
      'CFN_FLOW_FROM' => 'spec/data',
      'CFN_FLOW_TO'   => 'test'
    })
  end

  describe '#validate' do
    it('succeeds') {
      capture { cli.start %w[validate] }
    }

    it('can fail') {
      (Thread.current[:aws_cfn_client] = Aws::CloudFormation::Client.new).
      stub_responses(:validate_template, 'ValidationError')

      out = capture(:stderr) { cli.start %w(validate) }

      Thread.current[:aws_cfn_client] = nil
      out.include?("Error validating").must_equal true
    }
  end

end
