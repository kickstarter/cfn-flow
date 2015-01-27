# cfn-flow
An opinionated command-line workflow for developing AWS CloudFormation templates. Track template changes in git and upload versioned releases to AWS S3.

#### Opinions

1. *Optimize for onboarding.* The workflow should be simple to learn & understand.
2. *Optimize for happiness.* The workflow should be easy and enjoyable to use.
3. *Auditable history.* Know who changed what when. Leverage git for auditing.
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

cfn-init
```

You can launch or update test stacks using your dev template path to quickly test your
template changes.

#### Release mode

Release mode publishes your templates to a versioned S3 path, and pushes a git
tag of the version.

```
# uploads templates to `s3://my-bucket/release/1.0.0/*` and pushes a 1.0.0 git
tag
cfn-flow --release 1.0.0
```

Release mode ensures there are no uncommitted changes in your git working
directory, and pushes a `1.0.0` git tag.

Inspecting the differences between releases is possible using `git log` and `git
diff`.

## Configuration

You can configure cfn-flow defaults by creating a `cfn-flow.yml` file in same
directory you run `cfn-flow` (presumably the root of your project).

Settings in the configuration file are overridden by environment variables. And
environment variables are overridden by command line arguments.

```
# cfn-flow.yml in the root of your project
# All options in this config can be overridden with command line arguments
---
# S3 bucket where templates are uploaded. No default.
# Override with CFN_FLOW_BUCKET
bucket: 'my-s3-bucket'

# S3 path prefix. Default: none
# Override with CFN_FLOW_TO
to: my/project/prefix

# Local path in which to recursively search for templates. Default: .
# Override with CFN_FLOW_FROM
from: my/local/prefix

# AWS Region
# Override with AWS_REGION
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
        "Fn::Join" : [ ":",r
          [ "https://s3.amazonaws.com/my-bucket", {"Ref": "prefix"}, "my-template.json" ]
          ]
      }
   }
}
```

While testing, set the `prefix` parameter to dev prefix like `dev/aaron`. When you're confident your changes work, release them with cfn-flow and change the `prefix` parameter to `release/1.0.0` for production.
