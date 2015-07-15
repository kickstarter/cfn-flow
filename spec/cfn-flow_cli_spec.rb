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
      Aws.config[:cloudformation] = {stub_responses: {validate_template: 'ValidationError'}}
      _, err = capture_io { cli.start %w(validate) }
      err.must_match "Error validating"
    }

  end

end
