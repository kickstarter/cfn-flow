class CfnFlow::Template
  attr_reader :from
  def initialize(from)
    @from = from
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

  def to
    from.sub(/\.yml\Z/, '.json')
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
end
