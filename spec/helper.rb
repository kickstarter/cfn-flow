require "rubygems"
require "bundler/setup"
require "minitest/autorun"
require "minitest/pride"

begin
  require 'pry'
rescue LoadError
  # NBD.
end

require "cfn-flow"

Aws.config[:stub_responses] = true
ENV['AWS_REGION'] = 'us-east-1'
ENV['AWS_ACCESS_KEY_ID'] = 'test-key'
ENV['AWS_SECRET_ACCESS_KEY'] = 'test-secret'
ENV['CFN_FLOW_DEV_NAME'] = 'cfn-flow-specs'

class Minitest::Spec
  # From http://git.io/bcfh
  def capture(stream = :stdout)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval("$#{stream} = #{stream.upcase}")
    end

    result
  end

  # Reset env between tests
  before { @orig_env = ENV.to_hash }
  after  { ENV.clear; ENV.update(@orig_env) }
end
