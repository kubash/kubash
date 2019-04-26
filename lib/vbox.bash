#!/usr/bin/env bash

vbox-provisioner () {
  squawk 1 "vbox-provisioner $@"

  K8S_node=$1
  K8S_role=$2
  K8S_cpuCount=$3
  K8S_Memory=$4
  K8S_network1=$5
  K8S_sshPort=${10}
  K8S_mac1=$6
  K8S_ip1=$7
  K8S_provisionerHost=$8
  K8S_provisionerUser=$9
  K8S_provisionerPort=${10}
  K8S_provisionerBasePath=${11}
  K8S_os=${12}
  K8S_virt=${13}
  K8S_network2=${14}
  K8S_mac2=${15}
  K8S_ip2=${16}
  K8S_network3=${17}
  K8S_mac3=${18}
  K8S_ip3=${19}

  squawk 7 "K8S_node=$1
  K8S_role=$2
  K8S_cpuCount=$3
  K8S_Memory=$4
  K8S_sshPort=${10}
  K8S_network1=$5
  K8S_mac1=$6
  K8S_ip1=$7
  K8S_provisionerHost=$8
  K8S_provisionerUser=$9
  K8S_provisionerPort=${10}
  K8S_provisionerBasePath=${11}
  K8S_os=${12}
  K8S_virt=${13}
  K8S_network2=${14}
  K8S_mac2=${15}
  K8S_ip2=${16}
  K8S_network3=${17}
  K8S_mac3=${18}
  K8S_ip3=${19}
  "

  croak 3  'Vbox provisioner not implemented yet'
}
