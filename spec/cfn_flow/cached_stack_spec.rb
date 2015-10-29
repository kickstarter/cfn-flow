require_relative '../helper'

describe 'CfnFlow::CachedStack' do
  subject { CfnFlow::CachedStack }

  describe '.stack_cache' do
    it 'defaults to a hash' do
      subject.stack_cache.must_equal({})
    end
  end

  describe '.get_output' do
    let(:output_value) { 'myvalue' }

    before do
      Aws.config[:cloudformation]= {
        stub_responses: {
          describe_stacks: { stacks: [ stub_stack_data.merge(outputs: [{ output_key: "myoutput", output_value: output_value } ]) ] }
        }
      }
    end

    it 'returns the output' do
      subject.get_output(stack: 'mystack', output: 'myoutput').must_equal output_value
    end

    it 'has required kwargs' do
      -> { subject.get_output }.must_raise(ArgumentError)
    end
  end

  describe 'an instance' do
    subject { CfnFlow::CachedStack.new('mystack') }
    let(:output_value) { 'myvalue' }

    before do
      Aws.config[:cloudformation]= {
        stub_responses: {
          describe_stacks: { stacks: [ stub_stack_data.merge(outputs: [{ output_key: "myoutput", output_value: output_value } ]) ] }
        }
      }
    end

    it "should return the output value" do
      subject.output('myoutput').must_equal output_value
    end

    describe "with a missing output" do
      it "should raise an error" do
        -> { subject.output("no-such-output") }.must_raise(CfnFlow::CachedStack::MissingOutput)
      end
    end

    describe "with a missing stack" do

      subject { CfnFlow::CachedStack.new('no-such-stack') }
      before do
        Aws.config[:cloudformation]= {
          stub_responses: {
            describe_stacks: 'ValidationError'
          }
        }
      end

      it "should raise an error" do
        -> { subject.output('blah') }.must_raise(Aws::CloudFormation::Errors::ValidationError)
      end
    end
  end

end
