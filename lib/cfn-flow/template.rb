module CfnFlow
  class Template

    # Tag for JSON/YAML loading errors
    module Error; end

    attr_reader :local_path
    def initialize(local_path)
      @local_path = local_path
    end

    def yaml?
      local_path.end_with?('.yml')
    end

    def json?
      ! yaml?
    end

    # Determine if this file is a CFN template
    def is_cfn_template?
      local_data.is_a?(Hash) && local_data.key?('Resources')
    end

    # Returns a response object if valid, or raises an
    # Aws::CloudFormation::Errors::ValidationError with an error message
    def validate!
      cfn.validate_template(template_body: to_json)
    end

    ##
    # S3 methods
    def key(release)
      # Replace leading './' in local_path
      File.join(s3_prefix, release, local_path.sub(/\A\.\//, ''))
    end

    def s3_object(release)
      Aws::S3::Object.new(bucket, key(release))
    end

    def url(release)
      s3_object(release).public_url
    end

    def upload(release)
      s3_object(release).put(body: to_json)
    end

    def local_data
      # We *could* load JSON as YAML, but that would generate confusing errors
      # in the case of a JSON syntax error.
      @local_data ||= yaml? ? YAML.load_file(local_path) : MultiJson.load(File.read(local_path))
    rescue Exception => error
      # Tag & re-raise any error
      error.extend(CfnFlow::Template::Error)
      raise error
    end

    def to_json
      @to_json ||= MultiJson.dump(local_data, pretty: true)
    end

    def bucket
      CfnFlow.config['templates']['bucket']
    end

    def s3_prefix
      CfnFlow.config['templates']['s3_prefix']
    end

    private
    def cfn
      CfnFlow.cfn_client
    end
  end
end
