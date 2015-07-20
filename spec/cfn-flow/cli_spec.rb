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
      out.must_equal ''
      err.must_match 'You must specify a template to validate'
    end
  end

  describe '#publish' do
    it 'debug' do
      #cli.start [:publish, template, '--release']
    end
  end

  describe '#list' do
    it 'has no output with no stacks' do
      out, err = capture_io { cli.start [:list] }
      out.must_equal ''
      err.must_equal ''
    end

    describe 'with one stack' do
      before do
        Aws.config[:cloudformation]= {
          stub_responses: {
            describe_stacks: {
              stacks: [
                { stack_name: "mystack",
                  stack_status: 'CREATE_COMPLETE',
                  creation_time: Time.now,
                  tags: [
                    {key: 'CfnFlowService', value: CfnFlow.service},
                    {key: 'CfnFlowEnvironment', value: 'production'}
                  ]
                }
              ]
            }
          }
        }
      end
      it 'should print the stack' do
        out, err = capture_io { cli.start [:list] }
        out.must_match(/mystack\s+production\s+CREATE_COMPLETE/)
        err.must_equal ''
      end

      it 'should print the header' do
        out, _ = capture_io { cli.start [:list] }
        out.must_match(/NAME\s+ENVIRONMENT\s+STATUS/)
      end

      it 'should not print the header with option[no-header]' do
        out, _ = capture_io { cli.start [:list, '--no-header'] }
        out.wont_match(/NAME\s+ENVIRONMENT\s+STATUS/)
      end
    end

    describe 'with stacks in a different service' do
      before do
        Aws.config[:cloudformation]= {
          stub_responses: {
            describe_stacks: {
              stacks: [
                { stack_name: "mystack",
                  stack_status: 'CREATE_COMPLETE',
                  creation_time: Time.now,
                  tags: [
                    {key: 'CfnFlowService', value: 'none-such-service'},
                    {key: 'CfnFlowEnvironment', value: 'production'}
                  ]
                }
              ]
            }
          }
        }
      end

      it 'has no output' do
        out, _ = capture_io { cli.start [:list] }
        out.must_equal ''
      end
    end
  end

  describe '#show' do
    describe 'with a stack' do
      before do
        Aws.config[:cloudformation]= {
          stub_responses: {
            describe_stacks: {
              stacks: [
                { stack_name: "mystack",
                  stack_status: 'CREATE_COMPLETE',
                  creation_time: Time.now,
                  tags: [
                    {key: 'CfnFlowService', value: CfnFlow.service},
                    {key: 'CfnFlowEnvironment', value: 'production'}
                  ]
                }
              ]
            }
          }
        }
      end

      it 'should print in yaml' do
        out, err = capture_io { cli.start [:show, 'mystack'] }
        expected = CfnFlow.cfn_resource.stack('mystack').data.to_hash.to_yaml
        out.must_equal expected
        err.must_equal ''
      end

      it 'handles --json option' do
        out, _ = capture_io { cli.start [:show, 'mystack', '--json'] }
        expected = MultiJson.dump(CfnFlow.cfn_resource.stack('mystack').data.to_hash, pretty: true) + "\n"
        out.must_equal expected
      end
    end

    it 'returns an error with missing stacks' do
      Aws.config[:cloudformation]= {
        stub_responses: { describe_stacks: 'ValidationError' }
      }
      out, err = capture_io { cli.start [:show, 'none-such-stack'] }
      out.must_equal ''
      err.must_match 'error'
    end

    it 'returns an error when stack is not in service' do
      Aws.config[:cloudformation]= {
        stub_responses: {
          describe_stacks: {
            stacks: [
              { stack_name: "mystack",
                stack_status: 'CREATE_COMPLETE',
                creation_time: Time.now,
                tags: [
                  {key: 'CfnFlowService', value: 'none-such-service'},
                  {key: 'CfnFlowEnvironment', value: 'production'}
                ]
              }
            ]
          }
        }
      }
      out, err = capture_io { cli.start [:show, 'none-such-stack'] }
      out.must_equal ''
      err.must_match "not tagged for service #{CfnFlow.service}"
    end
  end

end
