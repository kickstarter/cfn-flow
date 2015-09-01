# cfn-flow
`cfn-flow` is an opinionated command-line workflow for developing [AWS CloudFormation](https://aws.amazon.com/cloudformation/) templates and deploying stacks.

It provides a *simple*, *standard*, and *flexible* process for using CloudFormation, ideal for DevOps-style organizations.

#### Opinions

`cfn-flow` introduces a consist, convenient workflow that encourages good template organization
and deploy practices.

1. *Optimize for happiness.* The workflow should be easy and enjoyable to use.
2. *Optimize for onboarding.* The workflow should be simple to learn & understand.
3. *Auditable changes.* Know who changed what when. Leverage git history.
4. *Immutable releases.* The code in a release never changes. To make a change,
   launch a new stack.

The features & implementation of `cfn-flow` itself must also be simple. This follows the Unix philosophy of "[worse is
better](http://www.jwz.org/doc/worse-is-better.html)". `cfn-flow` values a simple design and implementation, and being composable with other workflows over handling every edge case out of the box.

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

## How it works

`cfn-flow` works from a directory containing a `cfn-flow.yml` config file, and a CloudFormation template.
Presumably your app code is in the same directory, but it doesn't have to be.

There are two key concepts for `cfn-flow`: **services** and **environments**.

#### Services

A service is a name for your project and comprises a set of resources that
change together. Each service has it's own `cfn-flow.yml` config file. A service
can be instantiated as several distinct environments.

For example, a `WebApp` service could have a CloudFormation template that
creates an ELB, LaunchConfig, and AutoScalingGroup resources.

All the resources in a service change together. Deploying the `WebApp`
service to an environment will create a new ELB, LaunchConfig, and AutoScalingGroup.

Resources that *do not* change across deploys are not part of the service (from
`cfn-flow`'s perspective).
Say all `WebApp` EC2 servers connect to a long-running RDS database. That
database is not part of the cfn-flow service because it should re-used across
deploys. The database is a *backing resource* the service uses; not part
of the service itself.

#### Environments

An environment is an particular instantiation of a service. For example, you
could deploy your `WebApp` service to both a `development` and `production` environment.

`cfn-flow` is designed to support arbitrary environments like git supports
arbitrary branches.

Then `CFN_FLOW_ENVIRONMENT` environment variable can be used in
`cfn-flow.yml` to use the environment in your template parameters.

#### Deploying

Deployments consist of launching a *new stack* in a particular environment, then
shutting down the old stack. For example:

```
cfn-flow deploy ENVIRONMENT --cleanup
```

This follows the [red/black](http://techblog.netflix.com/2013/08/deploying-netflix-api.html)
or [blue/green](http://martinfowler.com/bliki/BlueGreenDeployment.html)
deployment pattern.

After verifying the new stack is working correctly, the deployer is expected to
delete the old stack.

To roll back a bad deploy, simply delete the *new* stack, while the *old*
stack is running.

Although CloudFormation supports updating existing stacks, `cfn-flow` prefers
launching immutable stacks. Stack updates are more difficult to test than new stacks; and there's less chance of a deployment error disrupting or breaking important resources.

#### AWS credentials

Set your AWS credentials so they can be found by the AWS SDK for Ruby ([details here](http://docs.aws.amazon.com/AWSSdkDocsRuby/latest/DeveloperGuide/set-up-creds.html)), e.g. using the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.

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

##
# Stacks
#
# These are the arguments passed when launching a new stack.
# It's nearly identical to the create_stack args in the ruby sdk, except
# parameters and tags are hashes. See http://amzn.to/1M0nBuq

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
      # Whatever you want.
      # Note that `cfn-flow` automatically adds two tags: `CfnFlowService` and `CfnFlowEnvironment`
      TagKey: TagValue
      # Who launched this stack
      Deployer: <%= ENV['USER'] %>
      # Tag production and development environments for accounting
      BillingType: <%= ENV['CFN_FLOW_ENVIRONMENT'] == 'production' ?  'production' : 'development' %>
```

### UX improvements:

- YAML (comments, debugging)
- ERB interpolation
- Terse param/tag syntax
- Read templates from local path


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
