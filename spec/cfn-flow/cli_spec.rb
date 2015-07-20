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
      # TODO
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
            describe_stacks: { stacks: [ stub_stack_data ] }
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
      stack_data = stub_stack_data
      stack_data[:tags][0][:value] = 'none-such-service'
      Aws.config[:cloudformation]= {
        stub_responses: {
          describe_stacks: { stacks: [ stack_data ] }
        }
      }
      out, err = capture_io { cli.start [:show, 'none-such-stack'] }
      out.must_equal ''
      err.must_match "not tagged for service #{CfnFlow.service}"
    end
  end

  describe '#events' do
    before do
      Aws.config[:cloudformation] = {
        stub_responses: {
          describe_stack_events: { stack_events: [ stub_event_data ] },
          describe_stacks: { stacks: [ stub_stack_data ] }
        }
      }
    end

    it 'should show the header by default' do
      out, _ = capture_io { cli.start [:events, 'mystack'] }
      out.must_match CfnFlow::EventPresenter.header
    end

    it 'can omit header' do
      out, _ = capture_io { cli.start [:events, '--no-headers', 'mystack'] }
      out.wont_match CfnFlow::EventPresenter.header
    end

    it 'should show an event' do
      out, err = capture_io { cli.start [:events, 'mystack'] }

      out.must_match CfnFlow::EventPresenter.new(stub_event).to_s
      err.must_equal ''
    end

    describe 'with polling' do
      before do
        Aws.config[:cloudformation] = {
          stub_responses: {
            describe_stack_events: [
              { stack_events: [ stub_event_data(resource_status: 'CREATE_IN_PROGRESS') ] },
              { stack_events: [ stub_event_data(resource_status: 'CREATE_COMPLETE') ] }
            ],
            describe_stacks: [
              { stacks: [ stub_stack_data(stack_status: 'CREATE_IN_PROGRESS') ] },
              { stacks: [ stub_stack_data(stack_status: 'CREATE_COMPLETE') ] },
            ]
          }
        }
      end

      it 'should not poll by default' do
        out, _ = capture_io { cli.start [:events, '--no-header', 'mystack'] }
        out.must_match 'CREATE_IN_PROGRESS'
        out.wont_match 'CREATE_COMPLETE'
      end

      it 'will poll until complete' do
        out, _ = capture_io {
          cli.start [:events, '--no-header', '--tail', 'mystack']
        }
        out.must_match 'CREATE_IN_PROGRESS'
        out.must_match 'CREATE_COMPLETE'
      end
    end

  end

  describe '#delete' do
    describe 'with a stack' do
      before do
        Aws.config[:cloudformation] = {
          stub_responses: { describe_stacks: { stacks: [ stub_stack_data ] } }
        }
      end

      it 'deletes the stack' do
        Thor::LineEditor.stub :readline, "yes" do
          out, err = capture_io { cli.start [:delete, 'mystack'] }
          out.must_equal "Deleted stack mystack\n"
          err.must_equal ''
        end
      end

      it 'does not delete the stack if you say no' do
        Thor::LineEditor.stub :readline, "no" do
          out, err = capture_io { cli.start [:delete, 'mystack'] }
          out.must_equal ''
          err.must_equal ''
        end
      end

      it 'does not ask when --force is set' do
          out, err = capture_io { cli.start [:delete, '--force', 'mystack'] }
          out.must_equal "Deleted stack mystack\n"
          err.must_equal ''
      end
    end

    it 'returns an error for a stack in another service' do
      Aws.config[:cloudformation] = {
        stub_responses: { describe_stacks: { stacks: [ stub_stack_data(tags: []) ] } }
      }
    out, err = capture_io { cli.start [:delete, 'wrong-stack'] }
      out.must_equal ''
      err.must_match 'Stack wrong-stack is not tagged for service'
    end
  end

end
