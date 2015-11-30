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
    it 'succeeds' do
      out, err = capture_io { cli.start [:publish, template] }
      err.must_equal ''
      out.must_match "Validating #{template}... valid."
      out.must_match "Publishing #{template}"
    end

    it 'can have multiple templates' do
      out, _ = capture_io { cli.start [:publish, template, 'spec/data/sqs.template'] }
      # 2 lines for validating, 2 for publishing
      out.split("\n").size.must_equal 4
    end

    it 'uses the dev-name' do
      out, _ = capture_io { cli.start [:publish, template] }
      out.must_match("dev/#{ENV['CFN_FLOW_DEV_NAME']}")
    end

    it 'can take a dev-name argument' do
      name = 'a-new-dev-name'
      out, _ = capture_io { cli.start [:publish, template, '--dev-name', name] }
      out.must_match("dev/#{name}")
    end

    describe 'with --release' do
      it 'defaults to git sha' do
        sha = CfnFlow::Git.sha
        out, _ = capture_io { cli.start [:publish, template, '--release'] }
        out.must_match CfnFlow::Template.new(template).url("release/#{sha}")
      end

      it 'can take a value' do
        release = 'v2.0'
        out, _ = capture_io { cli.start [:publish, template, '--release', release] }
        out.must_match CfnFlow::Template.new(template).url("release/#{release}")
      end
    end

    it 'can fail with malformed templates' do
      _, err = capture_io { cli.start [:publish, 'no/such/template'] }
      err.must_match 'Error loading template'
      err.must_match 'Errno::ENOENT'
    end

    it 'can fail with validation error' do
      Aws.config[:cloudformation] = {stub_responses: {validate_template: 'ValidationError'}}
      _, err = capture_io { cli.start [:publish, template] }
      err.must_match "Invalid template"
    end

    it 'fails when no templates are passed' do
      out, err = capture_io { cli.start [:publish] }
      out.must_equal ''
      err.must_match 'You must specify a template to publish'
    end

    it 'fails with no release' do
      ENV.delete('CFN_FLOW_DEV_NAME')
      _, err = capture_io { cli.start [:publish, template] }
      err.must_match 'Must specify --release or --dev-name'
    end
  end

  describe '#deploy' do

    it 'succeeds' do
      Aws.config[:cloudformation]= {
        stub_responses: {
          describe_stacks: { stacks: [ stub_stack_data(stack_name: 'cfn-flow-spec-stack') ] },
          describe_stack_events: { stack_events: [ stub_event_data ] },
        }
      }
      out, err = capture_io { cli.start [:deploy, 'test-env'] }

      out.must_match "Launching stack #{CfnFlow.config['stack']['stack_name']}"
      out.must_match "Polling for events..."
      out.must_match "CREATE_COMPLETE"
      out.wont_match 'Finding stacks to cleanup'
      err.must_equal ''
    end

    it 'exposes the environmont as an env var' do
       Aws.config[:cloudformation]= {
        stub_responses: {
          describe_stacks: { stacks: [ stub_stack_data(stack_name: 'cfn-flow-spec-stack') ] },
          describe_stack_events: { stack_events: [ stub_event_data ] },
        }
      }
      _ = capture_io { cli.start [:deploy, 'test-env'] }
      ENV['CFN_FLOW_ENVIRONMENT'].must_equal 'test-env'
    end

    it 'can fail with a validation error' do
      Aws.config[:cloudformation]= {
        stub_responses: { create_stack: 'ValidationError' }
      }

      out, err = capture_io { cli.start [:deploy, 'test-env'] }
      out.must_equal ''
      err.must_match 'error'

    end

    it 'can cleanup' do

      # Stubbing hacks alert!
      # The first two times we call :describe_stacks, return the stack we launch.
      # The third time, we're loading 'another-stack' to clean it up
      stack_stubs = [
        { stacks: [ stub_stack_data(stack_name: 'cfn-flow-spec-stack') ] },
        { stacks: [ stub_stack_data(stack_name: 'cfn-flow-spec-stack') ] },
        { stacks: [ stub_stack_data(stack_name: 'another-stack') ] }
      ]
      Aws.config[:cloudformation]= {
        stub_responses: {
          describe_stacks: stack_stubs,
          describe_stack_events: { stack_events: [ stub_event_data ] },
        }
      }

      Thor::LineEditor.stub :readline, "yes" do
        out, err = capture_io { cli.start [:deploy, 'production', '--cleanup'] }
        out.must_match 'Finding stacks to clean up'
        out.must_match 'Deleted stack another-stack'
        err.must_equal ''
      end
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
            describe_stacks: { stacks: [ stub_stack_data ] }
          }
        }
      end
      it 'should print the stack' do
        out, err = capture_io { cli.start [:list] }
        out.must_match(/mystack\s+production\s+CREATE_COMPLETE\s+#{memo_now.utc}/)
        err.must_equal ''
      end

      it 'should print the header' do
        out, _ = capture_io { cli.start [:list] }
        out.must_match(/NAME\s+ENVIRONMENT\s+STATUS\s+CREATED/)
      end

      it 'should print stacks when passed an environment' do
        out, _ = capture_io { cli.start [:list, 'production'] }
        out.must_match 'mystack'

        out, _ = capture_io { cli.start [:list, 'none-such-env'] }
        out.must_equal ''
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
                  creation_time: memo_now,
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

      it 'handles json format' do
        out, _ = capture_io { cli.start [:show, 'mystack', '--format=json'] }
        expected = MultiJson.dump(CfnFlow.cfn_resource.stack('mystack').data.to_hash, pretty: true) + "\n"
        out.must_equal expected
      end

      it 'handles outputs-table format' do
        out, _ = capture_io { cli.start [:show, 'mystack', '--format=outputs-table'] }
        out.must_match(/KEY\s+VALUE\s+DESCRIPTION/)
        out.must_match(/mykey\s+myvalue\s+My Output/)
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
          cli.start [:events, '--no-header', '--poll', 'mystack']
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

  describe '#version' do
    let(:version) { CfnFlow::VERSION + "\n" }
    it 'prints the version' do
      out, _ = capture_io { cli.start [:version] }
      out.must_equal version
    end

    it 'handles -v argument' do
      out, _ = capture_io { cli.start ['-v'] }
      out.must_equal version
    end

    it 'handles --version argument' do
      out, _ = capture_io { cli.start ['--version'] }
      out.must_equal version
    end

  end
end
