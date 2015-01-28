require 'thor'
require 'aws-sdk'
require 'multi_json'
require 'yaml'

class CfnFlow < Thor

  class GitError < StandardError; end

  def self.shared_options

    method_option :bucket,     type: :string, desc: 'S3 bucket for templates'
    method_option :to,         type: :string, desc: 'S3 path prefix for templates'
    method_option :from,       type: :string, desc: 'Local source directory for templates'
    method_option 'dev-name',  type: :string, desc: 'Personal development prefix'
    method_option :region,     type: :string, desc: 'AWS Region'

    method_option :verbose, type: :boolean, desc: 'Verbose output', default: false
  end

  no_commands do
    def load_config
      defaults = { 'from' => '.' }
      file_config = begin
        YAML.load_file(ENV['CFN_FLOW_CONFIG'] || './cfn-flow.yml')
      rescue Errno::ENOENT
        {}
      end
      env_config = {
        'bucket'      => ENV['CFN_FLOW_BUCKET'],
        'to'          => ENV['CFN_FLOW_TO'],
        'from'        => ENV['CFN_FLOW_FROM'],
        'dev-name'    => ENV['CFN_FLOW_DEV_NAME'],
        'region'      => ENV['AWS_REGION']
      }.delete_if {|_,v| v.nil?}

      # Env vars override config file. Command args override env vars.
      self.options = defaults.merge(file_config).merge(env_config).merge(options)

      # Ensure region env var is set for AWS client
      ENV['AWS_REGION'] = options['region']

      # TODO: validate required options are present
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
  default_task :upload

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
      parts += [ 'dev', options['dev-name'] ]
    end
    File.join(*parts)
  end

  def tag_release
    # Check git status
    unless `git status -s`.empty?
      git_error "Git working directory is not clean. Please commit or reset changes in order to release."
    end
    unless $?.success?
      git_error "Error running `git status`"
    end

    say "Tagging release #{options['release']}"
    `git tag -a -m #{options['release']}, #{options['release']}`
    unless $?.success?
      git_error "Error tagging release."
    end
  end

  def push_release
    `git push origin #{options['release']}`
    unless $?.success?
      git_error "Error pushing tag to origin."
    end
  end

  def git_error(message)
    say message, :red
    raise GitError.new(message)
  end
end

require 'cfn-flow/template'
