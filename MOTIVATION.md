# Overview of commands:

## Working with templates:

### `cfn-flow upload`
```
$ cfn-flow upload
# validates & uploads templates to dev path
# E.g. https://mybucket.s3.amazonaws.com/myprefix/dev/aaron/mytemplate.yml

$ cfn-flow upload --release
# validates & uploads templates for current git sha
# E.g. https://mybucket.s3.amazonaws.com/myprefix/deadbeef/mytemplate.yml

$ cfn-flow upload --release=v1.0.0
# Upload templates for an arbitrary release name
# E.g. https://mybucket.s3.amazonaws.com/myprefix/v1.0.0/mytemplate.yml
(We wouldn't use this...just exists for others' workflows.)
```

### `cfn-flow validate`

```
# Runs validate-template on all templates.
# returns an error on any failure.
# does not persiste to S3

$ cfn-flow validate
```

## Working with stacks

An app like `myapp` may have several environments such as `production`,
`staging`, and `dev`.

Environments do not share backing resources databases or S3 buckets.

`cfn-flow` is opinionated to use red/black deploys. That is, to make a change,
you launch a whole new stack, then shut down the old one (as opposed to updating a
long-running stack).

That means there may be more than one stack for an environment. E.g., to deploy
git sha `aaa`, you'd launch a stack named `myapp-production-aaa`.

Then you make some changes and commit sha `bbb`. You'd launch stack
`myapp-production-bbb`, and delete `myapp-production-aaa` once you've verified
the new stack is working.

While a stack name is unique across running stacks, `cfn-flow` uses the `Name`
tag to identify stacks in the same environment. Both stacks
`myapp-production-aaa` and `myapp-production-bbb` would have a tag `Name:
myapp-production`.

### Tag conventions

`cfn-flow` automatically sets two tags on your stack:

1. `cfn-flow-service` (e.g. myapp)
2. `cfn-flow-environment` (e.g. production)

### `cfn-flow deploy ENVIRONMENT`

Launches a stack in ENVIRONMENT. E.g. `cfn-flow deploy production`

### `cfn-flow list ENVIRONMENT`

Show running stacks for ENVIRONMENT.

```
$ cfn-flow list production

myapp-production-aaa (CREATE_COMPLETE)
myapp-production-bbb (CREATE_FAILED)
```

### `cfn-flow delete STACK`

Deletes a stack.

```
$ cfn-flow delete myapp-production-aaa
```

### `cfn-flow show STACK`

Show the status of STACK.

### `cfn-flow events STACK`

List events for STACK

# Common workflows:

### Deploying to production

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

### Launching a development environment

Launch a new stack for `myenv` environment

```
cfn-flow deploy myenv
```

#### Developing a new template

When developing new templates:

1. Edit the template
2. Upload a dev version with `cfn-flow upload`
3. Change `cfn-flow.yml` to use your dev template URL
4. Launch your test environment: `cfn-flow deploy myenv`

### Deploying a new template version to production:

1. Release the new template with `cfn-flow upload --release`. This ensures other
   devs can always audit the template.
2. Edit the template URL in `cfn-flow.yml` to use the newly released version.
3. Deploy a new production stack: `cfn-flow deploy production`
