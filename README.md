# cfn-flow
An opinionated command-line workflow for AWS CloudFormation templates. It lets you track template changes in git and upload versioned releases to AWS S3.

## Installation

Via [rubygems](https://rubygems.org/gems/cfn-flow):
```
gem install cfn-flow
```

## Configuration

## Usage

## Features

`cfn-flow` lets you write templates in either JSON or
[YAML](http://www.yaml.org). YAML is a superset of JSON that allows a terser,
less cluttered syntax, inline comments, and code re-use with variables. YAML
templates are transparently converted to JSON when uploaded to S3 for use in
CloudFormation stacks.

There are two modes for running `cfn-flow`: dev mode, and release mode.

#### Dev mode

Dev mode allows you to quickly test template changes. You configure a personal
dev prefix (by setting the `CFN_FLOW_DEV_NAME` environment variable, or passing the `--dev` command line argument). `cnf-flow` validates all templates and uploads them to your personal prefix, overwriting existing templates.

For example, running
```
cfn-flow --dev aaron
```
would upload templates to `s3://my-bucket/dev/aaron/*`.

You can launch or update test stacks using your dev template path to quickly test your
template changes.

Unlike release mode, dev mode does not verify that your local changes are
committed to git.

You should only use dev mode for testing & verifying changes in non-production stacks.

#### Release mode

Release mode publishes your templates to a versioned S3 path, and pushes a git
tag of the version.

For example, running:
```
cfn-flow --release 1.0.0
```
uploads templates to `s3://my-bucket/release/1.0.0/*`.

It also ensures there are no uncommitted changes in your git working
directory, and pushes a `1.0.0` git tag.

Inspecting the differences between versions is possible using `git log` and `git
diff`.

### Using versions with nested stacks

`cfn-flow` works great with [nested stack
resources](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-stack.html). Use the `Fn::Join` to construct the `TemplateURL` from a parameter:

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

While testing, set the `prefix` parameter to `dev/aaron`. When you're confident your changes work, release them and change the `prefix` parameter to `release/1.0.0` for production.
