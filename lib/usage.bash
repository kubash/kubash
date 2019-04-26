#!/usr/bin/env bash

usage () {
  horizontal_rule
  # Print usage
  echo 'kubash, by Josh Cox 2018.01.31
usage: kubash COMMAND
This script automates the setup and maintenance of a kubernetes cluster
e.g.

kubash init
'
  horizontal_rule
echo '
commands:
  build         - build a base image
  provision     - provision individual nodes
  init          - initialize the cluster
  reset         - reset the cluster with `kubeadm reset` on all hosts
  decommission  - tear down the cluster and decommission nodes
  show          - show the analyzed input of the hosts file
  ping          - Perform ansible ping to all hosts
  auto          - Full auto will provision and initialize all hosts
  masters       - Perform initialization of masters
  nodes         - Perform initialization of nodes
  dotfiles      - Perform dotfiles auto configuration
  grab          - Grab the .kube/config from the master
  hosts         - Write ansible hosts file
  copy          - copy the built images to the provisioning hosts
  kubash *     - any unrecognized commands will attempt to be passed to kubectl
'
  horizontal_rule
echo '
options:
 -h --help      - Print usage
 -c --csv FILE  - Set the csv file to be parsed
 --parallel X   - set the number of parallel jobs for tasks that support it
 -v --verbose   - Increase the verbosity (can set multiple times to incrementally increase e.g. `-vvvv`
 --verbosity X  - or you can set the verbosity directly
 --debug        - adds the debug flag
 -n             - use a particular cluster by name
'
}

interactive_usage () {
horizontal_rule
echo -n 'commands:
  help          - show this help
  kh|khelp      - show the kubectl help
  build         - build a base image
  provision     - provision individual nodes
  init          - initialize the cluster
  reset         - reset the cluster with `kubeadm reset` on all hosts
  decommission  - tear down the cluster and decommission nodes
  show          - show the analyzed input of the hosts file
  ping          - Perform ansible ping to all hosts
  auto          - Full auto will provision and initialize all hosts
  masters       - Perform initialization of masters
  nodes         - Perform initialization of nodes
  dotfiles      - Perform dotfiles auto configuration
  grab          - Grab the .kube/config from the master
  hosts         - Write ansible hosts file
  copy          - copy the built images to the provisioning hosts
  k *           - k commands will attempt to be passed to kubectl
  h *           - h commands will attempt to be passed to helm
  i.e.
  get pods
  get nodes
  etc'
}

kubectl_interactive_usage () {
horizontal_rule
echo -n 'kubectl shorthand commands:
  # Show all the nodes and their status
  kgn="kubectl get nodes"
  # Drop into an interactive terminal on a container
  keti="kubectl exec -ti"
  # Pod management.
  kgp="kubectl get pods| grep -v '^pvc-' "
  kgpa="kubectl get pods --all-namespaces| grep -v '^pvc-' "
  kgpvc="kubectl get pods | grep '^pvc-' "
  klp="kubectl logs pods"
  kep="kubectl edit pods"
  kdp="kubectl describe pods"
  kdelp="kubectl delete pods"
  # Service management.
  kgs="kubectl get svc"
  kes="kubectl edit svc"
  kds="kubectl describe svc"
  kdels="kubectl delete svc"
  # Secret management
  kgsec="kubectl get secret"
  kdsec="kubectl describe secret"
  kdelsec="kubectl delete secret"
  # Deployment management.
  kgd="kubectl get deployment"
  ked="kubectl edit deployment"
  kdd="kubectl describe deployment"
  kdeld="kubectl delete deployment"
  ksd="kubectl scale deployment"
  krsd="kubectl rollout status deployment"
  # voyager management.
  kei="kubectl edit ingress.voyager.appscode.com "
  # Rollout management.
  kgrs="kubectl get rs"
  krh="kubectl rollout history"
  kru="kubectl rollout undo"'
}

node_usage () {
  horizontal_rule
  # Print usage
  echo '--
usage: kubash node_join
build - build a base image

This command joins a node to the cluster
e.g.

kubash node_join

options:

 -h --help - Print usage
 --node-join-name - set node name
 --node-join-user - set node user
 --node-join-ip   - set node ip
 --node-join-port - set node port
 --node-join-role - set node role
 -n --clustername - use a particular cluster by name
'
}

build_usage () {
  horizontal_rule
  # Print usage
  echo '--
usage: kubash build
build - build a base image

This script automates the setup and maintenance of a kubernetes cluster
e.g.

kubash build

options:

 -h --help - Print usage
 --builder - choose builder (packer,coreos)
 --target-os - choose target-os (debian,ubuntu,centos,fedora,coreos)
 --target-build - choose target-build
'
}

init_usage () {
  horizontal_rule
  # Print usage
  echo '--
usage: kubash init

This initializes the cluster

options:

 -h --help - Print usage
 --initializer - Choose the initialization method (kubeadm,kubespray,openshift)
 -n --clustername - use a particular cluster by name
'
}

provision_usage () {
  horizontal_rule
  # Print usage
  echo '--
usage: kubash provision
provision - provision a base image

This provisions the base VMs

options:

 -h --help - Print usage
 -n --clustername - use a particular cluster by name
'
}

decom_usage () {
  horizontal_rule
  # Print usage
  echo '--
usage: kubash decom
decommission - decommission a cluster and destroy all VMs

This script automates the setup and maintenance of a kubernetes cluster
e.g.

kubash decommission

options:

 -h --help - Print usage
 -n --clustername - use a particular cluster by name
'
}
