class CfnFlow::Template
  attr_reader :from, :prefix, :bucket
  def initialize(opts={})
    unless [:from, :prefix, :bucket].all? {|arg| opts.key?(arg) }
      raise ArgumentError.new("Must pass :from, :prefix, and :bucket")
    end
    @from, @prefix, @bucket = opts[:from], opts[:prefix], opts[:bucket]
  end

  def yaml?
    from.end_with?('.yml')
  end

  def json?
    ! yaml?
  end

  # Determine if this file is a CFN template
  def is_cfn_template?
    from_data.is_a?(Hash) && from_data.key?('Resources')
  end

  # Returns a response object if valid, or raises an
  # Aws::CloudFormation::Errors::ValidationError with an error message
  def validate!
    cfn.validate_template(template_body: to_json)
  end

  def key
    # Replace leading './' in from
    File.join(prefix, from.sub(/\A\.\//, ''))
  end

  def upload!
    s3_object.put(body: to_json)
  end

  def url
    s3_object.public_url
  end

  def from_data
    # We *could* load JSON as YAML, but that would generate confusing errors
    # in the case of a JSON syntax error.
    @from_data ||= yaml? ? YAML.load_file(from) : MultiJson.load(File.read(from))
  rescue
    puts "Error loading #{from}"
    raise $!
  end

  def to_json
    @to_json ||= MultiJson.dump(from_data, pretty: true)
  end

  private
  def cfn
    Thread.current[:aws_cfn_client] ||= Aws::CloudFormation::Client.new
  end

  def s3_object
    Thread.current[:aws_s3_object] ||= Aws::S3::Object.new(bucket, key)
  end

end
