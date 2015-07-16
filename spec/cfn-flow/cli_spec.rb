require_relative '../helper'

describe 'CfnFlow::CLI' do
  let(:cli) { CfnFlow::CLI }
  let(:template) { 'spec/data/sqs.yml' }

  before do
    ENV.update({
      'CFN_FLOW_BUCKET' => 'test-bucket',
      'CFN_FLOW_FROM' => 'spec/data',
      'CFN_FLOW_TO'   => 'test'
    })
  end

  describe '#validate' do
    it 'succeeds' do
      out, err = capture_io { cli.start [:validate, template] }
      err.must_be :empty?
      out.must_match "Validating #{template}... valid."
    end

    it 'can have multiple templates' do
      out, _ = capture_io { cli.start [:validate, template, 'spec/data/sqs.template'] }
      out.split("\n").size.must_equal 2
    end

    it 'can fail with malformed templates' do
      _, err = capture_io { cli.start [:validate, 'no/such/template'] }
      err.must_match 'Error loading template'
      err.must_match 'Errno::ENOENT'
    end

    it 'can fail with validation error' do
      Aws.config[:cloudformation] = {stub_responses: {validate_template: 'ValidationError'}}
      _, err = capture_io { cli.start [:validate, template] }
      err.must_match "Invalid template"
    end

    it 'fails when no templates are passed' do
      out, err = capture_io { cli.start [:validate] }
      out.must_be :empty?
      err.must_match 'You must specify a template to validate'
    end

  end

end
