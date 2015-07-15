require_relative 'helper'

describe 'CfnFlow::Template' do

  let(:template) {
    CfnFlow::Template.new(from: 'spec/data/sqs.template', prefix: 'p', bucket: 'b')
  }

  let(:yml_template) {
    CfnFlow::Template.new(from: 'spec/data/sqs.yml', prefix: 'p', bucket: 'b')
  }

  let(:not_a_template) {
    CfnFlow::Template.new(from: 'spec/data/cfn-flow.yml', prefix: 'p', bucket: 'b')
  }

  describe '#initialize' do
    subject { CfnFlow::Template }

    it('succeeds') do
      subject.new(from: 'f', prefix: 'p', bucket: 'b').must_be_kind_of CfnFlow::Template
    end

    it('requires args') do
      -> { subject.new }.must_raise(ArgumentError)
    end
  end

  describe '#yaml?' do
    it 'works' do
      yml_template.yaml?.must_equal true
      yml_template.json?.must_equal false
      template.yaml?.must_equal false
      template.json?.must_equal true
    end
  end

  describe '#is_cfn_template?' do
    it 'works' do
      yml_template.is_cfn_template?.must_equal true
      template.is_cfn_template?.must_equal true
      not_a_template.is_cfn_template?.must_equal false
    end
  end

  describe '#validate!' do
    it 'can succeed' do
      template.validate!
    end
    it 'can raise an error' do
      Aws.config[:cloudformation] = {stub_responses: {validate_template: 'ValidationError'}}
      -> { template.validate! }.must_raise Aws::CloudFormation::Errors::ValidationError
    end
  end
end
