# cfn-flow
An opinionated command-line workflow for developing [AWS CloudFormation](https://aws.amazon.com/cloudformation/) templates and deploying stacks.

Track template changes in git and publish versioned releases to AWS S3.

Deploy stacks using a standard, reliable process with extensible
configuration in git.

#### Opinions

1. *Optimize for onboarding.* The workflow should be simple to learn & understand.
2. *Optimize for happiness.* The workflow should be easy and enjoyable to use.
3. *Auditable changes.* Know who changed what when. Leverage git change history.
4. *Immutable releases.* The code in a release never changes.

## Installation

Via [rubygems](https://rubygems.org/gems/cfn-flow):
```
gem install cfn-flow
```

The `git` command is also needed.

## Usage

Poke around:
```
cfn-flow help

cfn-flow help COMMAND
# E.g.:
cfn-flow help deploy
```

Launching a CloudFormation stack:
```
cfn-flow deploy production
```

## Configuration

`cfn-flow` looks for `./cfn-flow.yml` for stack and template configuration.
You can override this path by setting the `CFN_FLOW_CONFIG_PATH` environment
variable to another path.

Here's a minimal `cfn-flow.yml` config file:

```yaml
# Required service name
service: MyService

# Minimal configuration for launching the stack.
stack:
  # Stack name uses embedded ruby to support dynamic values
  stack_name: MyService-<%= Time.now.to_i %>
  # Required: *either* template_url or template_body
  template_body: path/to/template.json
  # Alternatively:
  # template_url: https://MyS3Bucket.s3.amazonaws.com/MyPrefix/release/abc123/template.json
```

And here's a maximal config file:

```yaml
---
# Example cfn-flow.yml

service: MyService

# Set the AWS region here to override or avoid setting the AWS_REGION env var
region: us-east-1

##
# Templates
#
# These define where templates will get published.
#   $ cfn-flow publish --release my-cfn-template.json
#   Published url: https://MyS3Bucket.s3.amazonaws.com/My/S3/Prefix/<git sha>/my-cfn-template.json
templates:
  bucket: MyS3Bucket
  s3_prefix: 'My/S3/Prefix'

stack:
  stack_name: MyService-<%= Time.now.to_i %>
    template_body: path/to/template.yml
    template_url: http://...
    parameters:
      # Your parameters, e.g.:
      vpcid: vpc-1234
      ami: ami-abcd
    disable_rollback: true,
    timeout_in_minutes: 1,
    notification_arns: ["NotificationARN"],
    capabilities: ["CAPABILITY_IAM"], # This stack does IAM stuff
    on_failure: "DO_NOTHING", # either DO_NOTHING, ROLLBACK, DELETE
    stack_policy_body: "StackPolicyBody",
    stack_policy_url: "StackPolicyURL",
    tags:
      TagKey: TagValue
      # Who launched this stack
      Deployer: <%= ENV['USER'] %>
      # Tag production and development environments for accounting
      BillingType: <%= ENV['CFN_FLOW_ENVIRONMENT'] == 'production' ?  'production' : 'development' %>
```

#### Dev mode (default)

Dev mode allows you to quickly test template changes.
`cfn-flow` validates all templates and uploads them to your personal prefix, overwriting existing templates.

Dev mode does not verify that your local changes are
committed to git (as opposed to release mode).

You should use dev mode for testing & verifying changes in non-production stacks.

```
# Set a personal name to prefix your templates.
export CFN_FLOW_DEV_NAME=aaron

# Validate and upload all CloudFormation templates in your working directory to
s3://my-bucket/dev/aaron/*
# NB that this overwrites existing templates in your CFN_FLOW_DEV_NAME
namespace.

cfn-flow
```

You can launch or update test stacks using your dev template path to quickly test your
template changes.

#### Release mode

Release mode publishes your templates to a versioned S3 path, and pushes a git
tag of the version.

```
# uploads templates to `s3://my-bucket/release/<git sha>/*`
tag
cfn-flow --release
```

Release mode ensures there are no uncommitted changes in your git working
directory.

Inspecting the differences between releases is possible using `git log` and `git
diff`.

## Configuration

You can configure cfn-flow defaults by creating a `cfn-flow.yml` file in same
directory you run `cfn-flow` (presumably the root of your project).

Settings in the configuration file are overridden by environment variables. And
environment variables are overridden by command line arguments.

```
# cfn-flow.yml in the root of your project
# You can specify an alternative path by setting the CFN_FLOW_CONFIG environment
# variable.
#
# All options in this config can be overridden with command line arguments
---
# S3 bucket where templates are uploaded. No default.
# Override with CFN_FLOW_BUCKET env var
bucket: 'my-s3-bucket'

# S3 path prefix. Default: none
# Override with CFN_FLOW_TO env var
to: my/project/prefix

# Local path in which to recursively search for templates. Default: .
# Override with CFN_FLOW_FROM env var
from: my/local/prefix

# AWS Region
# Override with AWS_REGION env var
region: us-east-1 # AWS region
```

#### AWS credentials

AWS credentials can only be set using the
`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables; or by
using an EC2 instance's IAM role.


## Sweet Features

#### YAML > JSON

`cfn-flow` lets you write templates in either JSON or
[YAML](http://www.yaml.org). YAML is a superset of JSON that allows a terser,
less cluttered syntax, inline comments, and code re-use with variables. YAML
templates are transparently converted to JSON when uploaded to S3 for use in
CloudFormation stacks.

#### Use versions in nested stack template URLs

`cfn-flow` works great with [nested stack
resources](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-stack.html). Use [Fn::Join](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/intrinsic-function-reference-join.html) to construct the `TemplateURL` from a parameter:

```
{
   "Type" : "AWS::CloudFormation::Stack",
   "Properties" : {
      "TemplateURL" : {
        "Fn::Join" : [ ":",
          [ "https://s3.amazonaws.com/my-bucket", {"Ref": "prefix"}, "my-template.json" ]
          ]
      }
   }
}
```

While testing, set the `prefix` parameter to a dev prefix like `dev/aaron`. When you're confident your changes work, release them with cfn-flow and change the `prefix` parameter to `release/<git sha>` for production.

#### Continuous integration

#### Github commit status

#### Minimal AWS credentials

TODO: example IAM policy
