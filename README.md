# Kubash

Build, provision, initialize, add common components, and tear down a cluster PDQ.

[![Build Status](https://travis-ci.org/kubash/kubash.svg?branch=master)](https://travis-ci.org/kubash/kubash)
[![Waffle.io - Columns and their card count](https://badge.waffle.io/joshuacox/kubash.svg?columns=all)](https://waffle.io/joshuacox/kubash)

Dev [![Build Status](https://travis-ci.org/joshuacox/kubash.svg?branch=master)](https://travis-ci.org/joshuacox/kubash)

Build production ready clusters using a variety of technologies along the way.

By default, this will build an image using packer, then rebase that image for your nodes.
Then initialize them using kubeadm, and install charts using helm.

### Oneliner installation

Install with one easy line

```
curl -L git.io/kubash|bash
```

Get started by making the example cluster from the example-cluster.yaml

```
cd ~/.kubash
kubash -n example yaml2cluster examples/example-cluster.yaml
ls -lh clusters/example
```

Now build the image `kubash build --target-os kubeadm`

[![asciicast](https://asciinema.org/a/164070.png)](https://asciinema.org/a/164070)

Then `kubash provision -n example`

[![asciicast](https://asciinema.org/a/164071.png)](https://asciinema.org/a/164071)

And finally `kubash -n example init`

[![asciicast](https://asciinema.org/a/164079.png)](https://asciinema.org/a/164079)

By default kubash is quiet unless an error is hit (though some of the
programs called by kubash might not be very quiet).  If you like
watching noisy output crank up the verbosity by adding a few v flags
(i.e. `-vvvv`) or secify the verbosity `--verbosity 100` or export it as
a environment variable e.g.

```
export VERBOSITY=100
```

kubash output will be denoted by appending `#`s in front of various
verbosity levels e.g.

```
############# Kubash, by Josh Cox
```

### Alternative pipelines

There are also alternative methods available for the steps,
for coreos there is an alternative builder that merely downloads the official images.
And for initializing the default is to directly initialize with kubeadm,
or can be alternatively done through ansible with the 
[openshift](http://openebs.readthedocs.io/en/latest/install/openshift.html)
or [kubespray](https://kubespray.io/)
or [kubeadm2ha](https://github.com/mbert/kubeadm2ha)
methods.

Other provisioning beyond KVM/qemu is also being looked at, suggestions welcome in the issues.
Keep in mind this started life as a ten line script of me just trying to duplicate the
[official instructions](https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/)
after both the kubespray and openshift playbooks
went sideways on me and I determined I needed to 
refamiliarize myself with spinning up a cluster with another method.
Somewhere along the way I came across this
[google doc](https://docs.google.com/document/d/1rEMFuHo3rBJfFapKBInjCqm2d7xGkXzh0FpFO0cRuqg/edit#)

And I decided to combine all of the above into a unified forkable pipeline that automates the entire proces
of building the images using a similar method to the one I used for [CoreOS](https://github.com/joshuacox/mkCoreOS),
using one of the initialization methods in a very repeatable way.
And throw some of the additional common components I tend to add to every cluster.

### Provisioners

KVM/qemu is used first and foremost because it is standard and built into Linux itself.
I intend to add virtualbox, vmware, etc builders and provisioners in the future.

### Builders

Right now you can build these OSs as your base image:

1. Ubuntu
1. Debian
1. Centos
1. CoreOS

Packer will build ubuntu, debian, and centos. And
there is also a basic downloader for the CoreOS images.

### Initializers

Although this script can just utilize ssh to run the kubeadm commands directly on the VMs,
you can optionally use kubespray or openshift's ansible playbooks instead,
I have had various issues with both and that's why i wrote this script so I can choose amongst a 
few different methods in my regular daily builds 
(I'm the sort of guy who likes to spin up clusters while sipping my morning coffee).

### Configs

By default there is now a `.kubash` folder in your home directory.  Inside this directory is a folder called `clusters`, `make example` in the `.kubash` directory will build the default example cluster.

### Usage

This script automates the setup and maintenance of a kubernetes cluster

```
kubash -n clustername COMMAND
```

### Commands:

[yaml2cluster](./docs/yaml2cluster.md) - Build a cluster directory from a yaml cluster file

[json2cluster](./docs/yaml2cluster.md) - Build a cluster directory from a json cluster file

[build](./docs/build.md) - Build a base image

[build-all](./docs/build.md) - Build all the base images in parallel

[provision](./docs/provision.md) - Provision individual nodes

[init](./docs/init.md) - Initialize the cluster

[reset](./docs/reset.md) - Reset the cluster by running `kubeadm reset` on all the hosts

[decommission](./docs/decommission.md) - Tear down the cluster and decommission nodes

[copy](./docs/copy.md) - copy the built images to the provisioning hosts

[ping](./docs/ping.md) - Perform ansible ping to all hosts

[auto](./docs/auto.md) - Full auto will provision and initialize all hosts

hostnamer - Will rehostname all the hosts

refresh - will search for all the hosts using the appropriate method and recreate hosts.csv

### Options

These options are parsed using GNU getopt

```
options:

 -h --help - Print usage

 -n --clustername - work with a named cluster (or by default it will use a cluster name of 'default')

 -c --csv FILE - Set the csv file to be parsed

 --parallel NUMBER_OF_THREADS - set the number of parallel jobs for tasks that support it

 -v --verbose - Increase the verbosity (can set multiple times to incrementally increase e.g. `-vvvv`

 --verbosity NUMBER - or you can set the verbosity directly

 --debug - adds the debug flag

 --oidc - enable the oidc auths
```

There is an example csv file in this repo which shows how to compose this file

### Debugging

First start by adding a few -vvv to the command to bump up the verbosity e.g.

```
kubash -vvvvv init
```

or

```
kubash --verbosity 22 init
```

Alternatively there is an environment variable `VERBOSITY`

```
export VERBOSITY=25
kubash init
```

And you can also add a debug flag:

```
kubash --debug --verbosity 100 init
```


try `kubash COMMAND --help`

### [GNU Parallel](https://www.gnu.org/software/parallel/)

This project takes advantage of [GNU Parallel](https://www.gnu.org/software/parallel/) gnu parallel and so should you, for more info see:

```
  O. Tange (2011): GNU Parallel - The Command-Line Power Tool,                                                                                                                                                     
  ;login: The USENIX Magazine, February 2011:42-47.                                                                                                                                                                
                                                       
```
