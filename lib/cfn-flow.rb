require 'thor'
require 'aws-sdk'
require 'multi_json'
require 'yaml'

class CfnFlow < Thor

  require 'cfn-flow/template'
  def self.shared_options

    method_option :bucket,     type: :string, desc: 'S3 bucket for templates'
    method_option :to,         type: :string, desc: 'S3 path prefix for templates'
    method_option :from,       type: :string, desc: 'Local source directory for templates'
    method_option :dev, type: :string, desc: 'Personal development prefix'

    method_option :verbose, type: :boolean, desc: 'Verbose output', default: false
  end

  no_commands do
    def load_config
      defaults = { 'prefix' => '', 'from' => '.', 'dev' => ENV['CFN_FLOW_DEV_NAME'] }
      file_config = begin
        YAML.load_file('./cfn-flow.yml')
      rescue Errno::ENOENT
        {}
      end

      # Config from env vars
      self.options = defaults.merge(file_config).merge(options)

    end

    shared_options
    def load_templates
      load_config
      glob = File.join(options['from'], '**/*.{yml,json,template}')

      @templates = Dir.glob(glob).map { |path|
        CfnFlow::Template.new(from: path, bucket: options['bucket'], prefix: prefix)
      }.select! {|t|
        verbose "Checking file #{t.from}... "
        if t.is_cfn_template?
          verbose "loaded"
          true
        else
          verbose "skipped."
          false
        end
      }
    end
  end

  desc :validate, 'Validates templates'
  shared_options
  def validate
    load_templates
    @templates.each do |t|
      begin
        verbose "Validating #{t.from}... "
        t.validate!
        verbose "valid."
      rescue Aws::CloudFormation::Errors::ValidationError
        say "Error validating #{t.from}. Message:"
        say $!.message
      end
    end
  end

  desc :upload, 'Validate & upload templates to the CFN_DEV_FLOW_NAME prefix'
  shared_options
  method_option :release, type: :string, desc: 'Upload & tag release'
  def upload
    tag_release if options['release']

    validate
    @templates.each do |t|
      verbose "Uploading #{t.from} to #{t.url}"
      t.upload!
    end

    push_release if options['release']

  end

  private
  def verbose(msg)
    say msg if options['verbose']
  end

  def prefix
    # Add the release or dev name to the prefix
    parts = []
    parts << options['prefix'] unless options['prefix'].empty?
    if options['release']
      parts += [ 'release',  options['release'] ]
    else
      parts += [ 'dev', options['dev'] ]
    end
    File.join(*parts)
  end

  def tag_release
    # Check git status
    unless `git status -s`.empty?
      say "Git working directory is not clean.", :red
      say "Please commit or reset changes in order to release.", :red
      exit 1
    end
    unless $?.success?
      say "Error running `git status`", :red
      exit 1
    end

    say "Tagging release #{options['release']}"
    `git tag -a -m #{options['release']}, #{options['release']}`
    unless $?.success?
      say "Error tagging release.", :red
      exit 1
    end
  end

  def push_tag
    `git push origin #{options['release']}`
    unless $?.success?
      say_status "Error pushing tag to origin.", :red
    end
  end
end
