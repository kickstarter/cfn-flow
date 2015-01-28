# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'cfn-flow'

Gem::Specification.new do |s|
  s.name = 'cfn-flow'
  s.version = CfnFlow::VERSION
  s.license = 'MIT'

  s.authors = ["Aaron Suggs"]
  s.description = "An opinionated worflow for AWS CloudFormation"
  s.email = "aaron@ktheory.com"

  s.files = Dir.glob("{bin,lib}/**/*") + %w(Rakefile README.md)
  s.executables = ['cfn-flow']
  s.homepage = 'http://github.com/kickstarter/cfn-flow'
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.summary = "A CLI for CloudFormation templates"
  s.test_files = Dir.glob("spec/**/*")

  s.required_ruby_version = '>= 2.0.0'

  s.add_dependency 'aws-sdk', '~> 2.0.20.pre'
  s.add_dependency 'thor', '~> 0.18'
  s.add_dependency 'multi_json', '~> 1.0' # Same as aws-sdk

  s.add_development_dependency 'minitest'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'appraisal'
end
