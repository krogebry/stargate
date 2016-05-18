# Stargate


## Design choices / Notes

Create AWS::CF scripts to create ASG's and everything else.
Use YAML config to define basic things.
Use Rakefile to kick things off.

Looks like the zip file contains web assets.  The ask is to use some kind of virtual
  machine for this, however, in a real world scenario I might be tempted to put this
  into some kind of CDN if I could.  If that isn't available ( in some cases it's not )
  then we use nginx on the frontends.

We're dealing with a war file here, so let's go with tomcat.

I'm going to go with my standard issue layout of using "load balancers for days."

* Frontend ASG with externally facing EIP - DNS to match.
* Backend using ASG with internal DNS

FE points to BE using FQDNs.

Blue green deployments because that's how we roll my hood.

Disks are going to be using standard issue EBS blocks with no additional storage.

Logging will be dumped into CloudWatch::Logs.

Monitoring and alarming using the usual things, but I think I'll also sprinkle in some sensu.

Project name: Maciepoo.  What is a Maciepoo, well it's actually named after my dog who is named
Macie.  We sometimes call her Macie doodle bug.  Asked my wife for a neat code name for
this project.  This is what she came up with, so this is what we're going with.
I think it's cute af.

What's a 'krogebry'?  First off, it's pronounced 'crow-gee-bry' it's the username I use
for the important things in my life.  This is an important thing in my life.

```
 cat /tmp/cf_training-app-0.6.3 |jq '.'|less
```

### Size matters

No seriously, size does matter in this case.  We want to be able to pack as much nonsense
into these stacks as humanly possible, so let's aim at making the stacks as small as possible.

To do this we're going to essentially compress without compressing the json data.  It's a trick
of most JSON parsing systems for most languages.  The idea is that we're going to output the machine
ready format instead of the human readable one.

For example, let's take a look at training-app-0.6.6 ( in the examples folder )

```
-rw-r--r--   1 krogebry  staff  5305 May 14 00:11 cf_training-app-0.6.6
-rw-r--r--   1 krogebry  staff  9373 May 14 00:12 cf_training-app-0.6.6-expanded
```

As you can see, the stack size is about 50% smaller than the exapnded view.  Now there is a caveat
to this in that the expanded view was expanded out with jq, which there is more white space
than there would be if we used the standard method of stack creation.

However, even with that stated what I've observed in the field is that there is still a signficant
savings in this process regarding this size issue.  In the field work has shown that we can 
pile in more cool things into a single stack using this method than traditional methods.

There's a nother benift to this system which is inline and comment blocks are supported in the 
JSON chunks because the ruby JSON parser allows for this.  This is handy for troubleshooting as
well as just keeping things clean and organized.

# Usage and walkthrough

The idea here is that we have groups of stacks.  Each stack is responsible for a grouping
of things.  In this case we have a few groups:

* Infrastructure (inf): VPC, Subnets, NACL's.
* Application (app): Frontend/Backend ELB/ASG, security groups, alarms.
* Monitoring (mon): Sensu, log processing and IDS.

## Configuration

I broke out the config into two core namespace elements:

```
application:
  name: maciepoo
  description: "My dogs name is Macie."
environment:
  aws:
    cloudformation:
```

The two elements are:

* Application stuff
* Cloud stuff

In this way we can add a new namespace for GCP, or OpenStack if we wanted to try to bootstrap
this application with different application processing code.

Granted, GCP::DeploymentManager handles templates in a fundementally different way using
jinja2 and yaml, but the idea is still sound.  Regardless of the provider, we'll still need
a way to configure the high level construct.

```
✔ 23:39 ~/dev/stargate [master|✚ 10…14] $ ls -al etc/cloudformation/
total 16
drwxr-xr-x  4 krogebry  staff  136 May 13 13:53 .
drwxr-xr-x  4 krogebry  staff  136 May 13 17:19 ..
-rw-r--r--  1 krogebry  staff  493 May 12 15:58 production.yaml
-rw-r--r--  1 krogebry  staff  260 May 13 13:34 training.yaml
```

The core configuration pulls in the environment specific yaml data based on the rake call.

## Deployment process
aka: the rake call

```
✔ 23:41 ~/dev/stargate [master|✚ 10…14] $ rake -T
rake chef:lint                                # Lint check the chef bits
rake chef:package[dry_run]                    # Package chef bits
rake cloud:compile[env_name,target,version]   # Compile things
rake cloud:deploy[env_name,target,version]    # Deploy a stack
rake cloud:validate[env_name,target,version]  # Syntax check a template
```

If there is one thing I know for absolute certain it is that software will always change.
We find bugs, we find improvments, and just like in life, things change.

So, let's start with a framework that acklowdegs that as a constant.

We do this by first stating that we're going to separate the infrastruction versioning
from the application versioning.  The versions of the stacks will absolutely not pertain
to the version of the software.  We state this rule so that we can enforce it as a constant
to our customers ( the developers ).

Functionally we're going to pull this off by requiring a version number for anything we build.
We also require a target and an environment name:

* Target: is a stack grouping.  ( using the world 'group' here can get confusing down the road )
* Environment: training or production in this case.
* Version: tripple dotted notation, major.minor.build numerical string representation.

For example, let's create the application stack first:

```
rake cloud:deploy['training, app, 0.1.0']
```

Assuming a fresh, blank slate with no other stacks this should actually fail.  And we predict
it to fail because we haven't setup the infrastructure first.  Essentially there is a loose requirement
that states the application requires a VPC in order to function.  You do not get to run applications
in an environment where there is no VPC.

In this was we could, potentially, enforce higher level rules that state that developers can create and modify
exiting application stacks, but *not* the inf or mon stacks.  ...in theory...

The 'fix' for this is to start by launching the inf stack:

```
rake cloud:deploy['training, inf, 0.1.0']
```

Once this stack is up, we set the 'inf_version' in the config file to '0.1.0' then relaunch the app stack.
This time when the code calls out to AWS, the VPC and subnets will be found and plugged into the template
as needed.

Now we can get to the really fun part which is rapid stack deployment.  As I'm developing this system
I'm cranking out templates a fairly good rate.  In fact, I usually don't bother doing any kind of updates.
Instead I simply create a new version of the stack and delete the old one.

For example, if I found a bug in 0.6.5, I'd luanch 0.6.6 as such:

```
rake cloud:deploy['training, app, 0.6.6']
```

Stack with version 0.6.5 is thrown into the giant bit bucket in the sky.  This process ensures that what
I'm building is being tested from start to finish.  If I'm updating stacks I'm running the risk that not
every part of the operation is being fully tested.  It's like doing real time unit tests on someone elses
service using real api calls.  But more awesome.  And with cats.  And possibly unicorns.




