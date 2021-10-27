#!/usr/bin/env bash
: ${KUBASH_LIB:=$KUBASH_DIR/lib}
. $KUBASH_LIB/kvars.bash

net_set () {
  # Set networking defaults
  if [[ -e "$KUBASH_CLUSTER_DIR/net_set" ]]; then
    K8S_NET=$(cat $KUBASH_CLUSTER_DIR/net_set)
  fi
  if [[ "$K8S_NET" == "calico" ]]; then
    my_KUBE_CIDR="192.168.0.0/16"
  elif [[ "$K8S_NET" == "flannel" ]]; then
    my_KUBE_CIDR="10.244.0.0/16"
  else
    horizontal_rule
    croak 3 'unknown pod network'
  fi
}

net_set

export KUBECONFIG=$KUBASH_CLUSTER_CONFIG
# Rasion d etre
RAISON=false

# global vars
ANSWER_YES=no
print_help=no


# includes
. $KUBASH_LIB/parse_opts.bash
. $KUBASH_LIB/utils.bash
. $KUBASH_LIB/squawk.bash
. $KUBASH_LIB/build.bash
. $KUBASH_LIB/croak.bash
. $KUBASH_LIB/usage.bash
. $KUBASH_LIB/kcsv.bash
. $KUBASH_LIB/storage.bash
. $KUBASH_LIB/ping.bash
. $KUBASH_LIB/w8.bash
. $KUBASH_LIB/kvm.bash
. $KUBASH_LIB/ingress.bash
. $KUBASH_LIB/net.bash
. $KUBASH_LIB/nomad.bash
. $KUBASH_LIB/packer.bash
. $KUBASH_LIB/kinit.bash
. $KUBASH_LIB/yaml.bash
. $KUBASH_LIB/vbox.bash
. $KUBASH_LIB/gke.bash
. $KUBASH_LIB/qemu.bash
. $KUBASH_LIB/kattic.bash
. $KUBASH_LIB/provision.bash
. $KUBASH_LIB/interactive.bash
. $KUBASH_LIB/kubeadm2ha.bash
. $KUBASH_LIB/openshift.bash
. $KUBASH_LIB/kubespray.bash
. $KUBASH_LIB/ansible.bash
. $KUBASH_LIB/istio.bash
