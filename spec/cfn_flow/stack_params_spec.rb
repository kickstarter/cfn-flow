require_relative '../helper'

describe 'CfnFlow::StackParams' do
  subject { CfnFlow::StackParams }

  it 'should be a hash' do
    subject.new.must_be_kind_of Hash
  end

  describe '.expanded' do
    it "returns a StackParams hash" do
      subject.expanded({}).must_be_kind_of subject
    end
  end

  describe '#with_symbolized_keys' do
    it 'works' do
      subject[{'foo' => 1, :bar => true}].with_symbolized_keys.must_equal({foo: 1, bar: true})
    end
  end

  describe '#with_expanded_parameters' do
    it 'reformats parameters hash to array of hashes' do
      hash = {
        parameters: { 'k1' => 'v1', 'k2' => 'v2' }
      }

      expected = {
        parameters: [
          {parameter_key: 'k1', parameter_value: 'v1'},
          {parameter_key: 'k2', parameter_value: 'v2'}
        ]
      }

      subject[hash].with_expanded_parameters.must_equal expected
    end

    describe 'with stack outputs' do
      let(:output_key)   { 'my-output-key' }
      let(:output_value) { 'my-output-value' }

      before do
        Aws.config[:cloudformation]= {
          stub_responses: {
            describe_stacks: { stacks: [ stub_stack_data.merge(outputs: [{ output_key: output_key, output_value: output_value } ]) ] }
          }
        }
      end

      it 'fetches stack outputs with explicit output key' do
        hash = {
          parameters: {
            'my-key' => { 'stack' => 'my-stack', 'output' => output_key}
          }
        }
        expected = {
          parameters: [ {parameter_key: 'my-key', parameter_value: output_value} ]
        }

        subject[hash].with_expanded_parameters.must_equal expected
      end

      it 'fetches stack outputs with implicit output key' do
        hash = {
          parameters: {
            output_key => { 'stack' => 'my-stack'}
          }
        }
        expected = {
          parameters: [ {parameter_key: output_key, parameter_value: output_value} ]
        }

        subject[hash].with_expanded_parameters.must_equal expected
      end
    end
  end

  describe '#with_expanded_tags' do
    it 'expands tags hash to array of hashes' do
      hash = {tags: {'k' => 'v'} }
      expected = {tags: [{key: 'k', value: 'v'}]}
      subject[hash].with_expanded_tags.must_equal expected
    end
  end

  describe '#add_tag' do
    it 'sets an empty tag hash' do
      subject.new.add_tag('k' => 'v').must_equal({tags: [{key: 'k', value: 'v'}]})

    end
    it 'appends to existing tag hash' do
      orig = subject[{tags: [{key: 'k1', value: 'v1'}] }]
      expected = {tags: [{key: 'k1', value: 'v1'}, {key: 'k2', value: 'v2'}] }

      orig.add_tag('k2' => 'v2').must_equal expected

    end
  end

  describe '#with_expanded_template_body' do
    it 'does not expand invalid templates' do
      hash = { template_body: 'spec/data/invalid.yml' }
      subject[hash].with_expanded_template_body.must_equal hash
    end

    it 'expands valid template paths' do
      template_path = 'spec/data/sqs.template'
      result = subject[template_body: template_path].with_expanded_template_body

      result.must_equal({template_body: CfnFlow::Template.new(template_path).to_json})
    end
  end

end
