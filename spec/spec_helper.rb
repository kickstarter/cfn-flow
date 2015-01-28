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
