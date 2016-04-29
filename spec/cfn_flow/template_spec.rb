require_relative '../helper'

describe 'CfnFlow::Template' do

  let(:template) {
    CfnFlow::Template.new('spec/data/sqs.template')
  }

  let(:yml_template) {
    CfnFlow::Template.new('spec/data/sqs.yml')
  }

  let(:not_a_template) {
    CfnFlow::Template.new('spec/data/cfn-flow.yml')
  }

  let(:release) { 'deadbeef' }

  describe '#initialize' do
    subject { CfnFlow::Template }

    it('succeeds') do
      subject.new('f').must_be_kind_of CfnFlow::Template
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

  describe '#bucket' do
    it 'uses CfnFlow.template_s3_bucket' do
      template.bucket.must_equal CfnFlow.template_s3_bucket
    end
     it 'has the correct value' do
      template.bucket.must_equal 'test-bucket'
    end
  end

  describe '#s3_prefix' do
    it 'uses CfnFlow.template_s3_prefix' do
      template.s3_prefix.must_equal CfnFlow.template_s3_prefix
    end
     it 'has the correct value' do
      template.s3_prefix.must_equal 'test-prefix'
    end
  end

  describe '#key' do
    it 'has the correct value' do
      expected = File.join(template.s3_prefix, release, template.local_path)
      template.key(release).must_equal expected
    end

    it "removes leading './'" do
      CfnFlow::Template.new('./foo').key(release).must_equal "test-prefix/#{release}/foo"
    end

    it "can have a empty s3_prefix" do
      CfnFlow.instance_variable_set(:@config, {'templates' => {'s3_bucket' => 'foo'}})
      expected = File.join(release, template.local_path)
      template.key(release).must_equal expected
    end
  end

  describe '#s3_object' do
    it 'is an S3::Object' do
      subject = template.s3_object(release)
      subject.must_be_kind_of Aws::S3::Object
      subject.bucket.name.must_equal template.bucket
      subject.key.must_equal template.key(release)
    end
  end

  describe '#url' do
    it 'is the correct S3 url' do
      uri = URI.parse(template.url(release))
      uri.scheme.must_equal 'https'
      uri.host.must_match(/\A#{template.bucket}\.s3\..+\.amazonaws\.com\z/)
      uri.path.must_equal('/' + template.key(release))
    end
  end

  describe '#upload' do
    it 'succeeds' do
      template.upload(release)
    end
  end

  describe '#local_data' do
    it 'should read valid data' do
      template.local_data.must_be_kind_of Hash
      template.local_data.must_be_kind_of Hash
    end

    it 'should parse ERB' do
      CfnFlow::Template.new('spec/data/erb-test.yml').local_data.must_equal({'foo' => 3})
    end

    it 'should raise an error on invalid json data' do
      -> { CfnFlow::Template.new('spec/data/invalid.json').local_data }.must_raise CfnFlow::Template::Error
    end

    it 'should raise an error on invalid YAML data' do
      -> { CfnFlow::Template.new('spec/data/invalid.yml').local_data }.must_raise CfnFlow::Template::Error
    end
    it 'should raise an on a missing file' do
      -> { CfnFlow::Template.new('no/such/file').local_data }.must_raise CfnFlow::Template::Error
    end
  end

  describe '#to_json' do
    it 'should work' do
      template.to_json.must_equal MultiJson.dump(template.local_data, pretty: true)
    end
  end

  describe '#validate!' do
    it 'succeeds' do
      template.validate!
    end
    it 'can raise an error' do
      Aws.config[:cloudformation] = {stub_responses: {validate_template: 'ValidationError'}}
      -> { template.validate! }.must_raise Aws::CloudFormation::Errors::ValidationError
    end
  end
end
