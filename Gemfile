source 'https://rubygems.org'

gemspec

group :development do
  gem 'pry'
  gem 'guard' # NB: this is necessary in newer versions
  gem 'guard-minitest'
end

# Use my fork for https://github.com/aws/aws-sdk-ruby/pull/873
gem 'aws-sdk', ref: 'd1ab862', git: 'https://github.com/ktheory/aws-sdk-ruby.git'
