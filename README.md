# cfn-flow
`cfn-flow` is a command-line tool for developing [AWS CloudFormation](https://aws.amazon.com/cloudformation/) templates and deploying stacks.

It provides a *simple*, *standard*, and *flexible* process for using CloudFormation, ideal for DevOps-style organizations.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## Table of Contents

- [Opinions](#opinions)
- [Installation](#installation)
- [Key concepts](#key-concepts)
    - [Services](#services)
    - [Environments](#environments)
    - [Deploying](#deploying)
    - [AWS credentials](#aws-credentials)
- [Configuration](#configuration)
- [UX improvements](#ux-improvements)
    - [YAML > JSON](#yaml--json)
    - [Embedded ruby in `cfn-flow.yml`](#embedded-ruby-in-cfn-flowyml)
- [Usage](#usage)
  - [Working with stacks](#working-with-stacks)
    - [Deploy (launch) a stack](#deploy-launch-a-stack)
    - [List stacks for your service or environment](#list-stacks-for-your-service-or-environment)
    - [Inspect a stack](#inspect-a-stack)
    - [Show stack events](#show-stack-events)
    - [Delete a stack](#delete-a-stack)
  - [Common workflows](#common-workflows)
    - [Deploying to production](#deploying-to-production)
  - [Launching a development environment](#launching-a-development-environment)
  - [Working with templates](#working-with-templates)
    - [Validate templates](#validate-templates)
    - [Publish templates to S3](#publish-templates-to-s3)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Opinions

`cfn-flow` introduces a consist, convenient workflow that encourages good template organization
and deploy practices.

1. *Optimize for happiness.* The workflow should be easy & enjoyable to use.
2. *Optimize for onboarding.* The workflow should be simple to learn, understand, & debug.
3. *Auditable changes.* Know who changed what when & why. Leverage git history.
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

## Key concepts

`cfn-flow` works from a directory containing a `cfn-flow.yml` config file, and a CloudFormation template.
Presumably your app code is in the same directory, but it doesn't have to be.

There are two key concepts for `cfn-flow`: **services** and **environments**.

#### Services

A service comprises a set of resources that change together.
Each service has its own `cfn-flow.yml` config file. A service
can be instantiated as several distinct environments.

For example, a `WebApp` service could have a CloudFormation template that
creates an ELB, LaunchConfig, and AutoScalingGroup resources.

All the resources in a service change together. Deploying the `WebApp`
service to an environment will create a new ELB, LaunchConfig, and AutoScalingGroup.

Resources that *do not* change across deploys are not part of the service (from
`cfn-flow`'s perspective).
Say all `WebApp` EC2 servers connect to a long-running RDS database. That
database is not part of the cfn-flow service because it is re-used across
deploys. The database is a *backing resource* the service uses; not part
of the service itself.

#### Environments

An environment is an particular instantiation of a service. For example, you
could deploy your `WebApp` service to both a `development` and `production` environment.

`cfn-flow` is designed to support arbitrary environments like git supports
arbitrary branches.

**Pro tip:** Use the `CFN_FLOW_ENVIRONMENT` environment variable in
`cfn-flow.yml` config to use the environment in your template parameters.
See [Configuration](#configuration) for examples.

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
  # NB: template_body is a local path to the template
  template_body: path/to/template.json
  # Alternatively:
  # template_url: https://MyS3Bucket.s3.amazonaws.com/MyPrefix/release/abc123/template.json
```

And here's a maximal config file:

```yaml
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
  # Use the CFN_FLOW_ENVIRONMENT var & git sha in stack name
  stack_name: MyService-<%= ENV['CFN_FLOW_ENVIRONMENT'] %>-<%= `git rev-parse --short HEAD`.chomp %>
    # NB: template_body is a local path to the template
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

## UX improvements

`cfn-flow` includes a few developer-friendly features:

#### YAML > JSON

`cfn-flow` lets you write templates in either JSON or
[YAML](http://www.yaml.org). YAML is a superset of JSON that allows a terser,
less cluttered syntax, inline comments, and code re-use with anchors (like
variables). YAML templates are transparently converted to JSON when uploaded to
S3 for use in CloudFormation stacks.

Note that you can use JSON snippets inside YAML templates. JSON is always valid
YAML.

#### Embedded ruby in `cfn-flow.yml`

To allow dynamic/programmatic attributes, use
[ERB](https://en.wikipedia.org/wiki/ERuby) in `cfn-flow.yml`. For example:

```yaml
stack:
  name: my-stack-<%= Time.now.to_i %>
  ...
  parameters:
    git_sha: <%= `git rev-parse --verify HEAD`.chomp %>
```

## Usage

Getting help:

```
# Get help
cfn-flow help

cfn-flow help COMMAND
# E.g.:
cfn-flow help deploy
```

Launch a CloudFormation stack:
```
cfn-flow deploy production
```

### Working with stacks

`cfn-flow` automatically sets two tags on any stack it launches:

Name | Example value
--- | ---
CfnFlowService | `myapp`
CfnFlowEnvironment | `production`

These tags let `cfn-flow` associate stacks back to services & environments.

#### Deploy (launch) a stack

```
cfn-flow deploy ENVIRONMENT
```

Launches a stack in ENVIRONMENT. E.g. `cfn-flow deploy production`

Add the `--cleanup` option to be prompted to shut down other stacks in the environment.

#### List stacks for your service or environment

```
cfn-flow list [ENVIRONMENT]
```

Show all stacks running in your service, or just in an ENVIRONMENT.

```
# For example:
$ cfn-flow list production

myapp-production-aaa (CREATE_COMPLETE)
myapp-production-bbb (CREATE_FAILED)
```

#### Inspect a stack

```
cfn-flow show STACK
```

Show the status of STACK.

#### Show stack events

```
cfn-flow events STACK
```

List events for STACK

Use the `--tail` option to poll for new events until the stack status is no
longer `*_IN_PROGRESS`

#### Delete a stack

```
cfn-flow delete STACK
```

Deletes a stack.

```
# For example:
$ cfn-flow delete myapp-production-aaa
```

### Common workflows

#### Deploying to production

```
# Launch a new stack for the current git commit
$ cfn-flow deploy production
Launching stack myapp-production-abc123
# ... wait for it to be ready

# See the other stacks
$ cfn-deploy list production

myapp-production-abc123 CREATE_COMPLETE
myapp-production-xyz987 CREATE_COMPLETE

# Shut down the old stack
$ cfn-flow delete myapp-production-xyz987
```

### Launching a development environment

Launch a new stack for `myenv` environment

```
cfn-flow deploy myenv
```

### Working with templates

#### Validate templates

```
cfn-flow validate TEMPLATE [...]
```

Validates CloudFormation templates; does not persist to S3.

```
# For example:
$ cfn-flow validate path/to/template.yml
```

#### Publish templates to S3

```
cfn-flow publish TEMPLATE [...]
```

Publish templates to S3 with immutable release names, or overwrite "dev names"
for quicker testing.

**Note:** Publishing to S3 is only needed if you want to use [nested stack resources](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-stack.html),
 (that is, stacks that lainclude other stacks).

```
# For example:
$ cfn-flow publish path/to/template.yml
# validates & uploads templates to dev path
# Env var CFN_FLOW_DEV_NAME=aaron
# E.g. https://mybucket.s3.amazonaws.com/myprefix/dev/aaron/mytemplate.yml

$ cfn-flow upload --release
# validates & uploads templates for current git sha
# E.g. https://mybucket.s3.amazonaws.com/myprefix/deadbeef/mytemplate.yml

$ cfn-flow upload --release=v1.0.0
# Upload templates for an arbitrary release name
# E.g. https://mybucket.s3.amazonaws.com/myprefix/v1.0.0/mytemplate.yml
```

## License

Copyright Kickstarter, Inc.

Released under an [MIT License](http://opensource.org/licenses/MIT).
