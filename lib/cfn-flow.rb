require 'thor'
require 'aws-sdk'
require 'multi_json'
require 'yaml'

class CfnFlow < Thor

  require 'cfn-flow/template'

  method_option :bucket, type: :string, desc: 'S3 bucket for templates'
  method_option :to,     type: :string, desc: 'S3 path prefix for templates'
  method_option :from,   type: :string, desc: 'Local source directory for templates'

  method_option :verbose, type: :boolean, desc: 'Verbose output', default: false

  no_commands do
    def load_config
      defaults = {'from' => '.' }
      file_config = begin
        YAML.load_file('./cfn-flow.yml')
      rescue Errno::ENOENT
        {}
      end

      # Config from env vars
      self.options = defaults.merge(file_config).merge(options)

    end

    def load_templates
      load_config
      glob = File.join(options['from'], '**/*.{yml,json,template}')

      @templates = Dir.glob(glob).inject({}) {|hash, path|
        template = CfnFlow::Template.new(path)
        verbose "Checking file #{path}... "
        if template.is_cfn_template?
          hash.merge!(path => CfnFlow::Template.new(path))
          verbose "loaded"
        else
          verbose "skipped."
        end
        hash
      }
    end
  end

  desc :validate, 'Validates templates'
  def validate
    load_templates
    @templates.each do |from, template|
      begin
        verbose "Validating #{from}... "
        cfn.validate_template(template_body: template.to_json)
        verbose "valid."
      rescue Aws::CloudFormation::Errors::ValidationError
        say "Error validating #{from}. Message:"
        say $!.message
      end
    end
  end

  desc :upload, 'Validate & upload templates to the CFN_DEV_FLOW_NAME prefix'
  option :release
  def upload
    puts 'Upload'
  end

  private
  def cfn
    @cfn ||= Aws::CloudFormation::Client.new
  end

  def verbose(msg)
    say msg if options['verbose']
  end
end
