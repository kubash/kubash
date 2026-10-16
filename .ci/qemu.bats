#!/usr/bin/env bats
# Tests for the storage disk attach in qemu-provisioner
# (lib/qemu.bash), issue #68: at the end of provisioning,
# each storage device set in the host's row is created and
# attached (virsh_disk_attach on a remote provisioner,
# virsh_disk_attach_localhost on localhost). 'null' rows
# must stay inert. $PSEUDO and ssh are logging stubs, so
# these pin the exact command stream.

setup() {
  KUBASH_ROOT="${KUBASH_ROOT:-$HOME/.kubash}"
  STREAM="$BATS_TEST_TMPDIR/stream.log"
  : > "$STREAM"
  STUBBIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUBBIN"
  cat > "$STUBBIN/logstub" <<EOF
#!/bin/bash
echo "PSEUDO: \$*" >> "$STREAM"
exit 0
EOF
  cat > "$STUBBIN/ssh" <<EOF
#!/bin/bash
echo "SSH: \$*" >> "$STREAM"
exit 0
EOF
  chmod +x "$STUBBIN/logstub" "$STUBBIN/ssh"
  export PATH="$STUBBIN:$PATH"
  # shellcheck disable=SC1091
  source "$KUBASH_ROOT/lib/qemu.bash"
  squawk() { :; }
  export PSEUDO=logstub
  export KUBASH_CLUSTER_NAME=probe KVM_BASE_IMG=base.qcow2
  export QEMU_PREALLOCATION=off K8S_kvm_os_variant=generic
  # one provisioner() row (CSV v6), storage fields included
  export K8S_node=node1 K8S_role=storage K8S_cpuCount=2 K8S_Memory=2048
  export K8S_network1='network=default' K8S_mac1='52:54:00:00:00:01' K8S_ip1='10.0.1.21'
  export K8S_provisionerUser=vagrant K8S_provisionerPort=22
  export K8S_provisionerBasePath=/var/lib/libvirt/images
  export K8S_os='debian-gnu' K8S_virt=qemu
  export K8S_network2=null K8S_mac2=null K8S_ip2=null
  export K8S_network3=null K8S_mac3=null K8S_ip3=null
}

provision_node() {
  qemu-provisioner "$K8S_node" "$K8S_role" "$K8S_cpuCount" "$K8S_Memory" \
    "$K8S_network1" "$K8S_mac1" "$K8S_ip1" "$K8S_provisionerHost" \
    "$K8S_provisionerUser" "$K8S_provisionerPort" "$K8S_provisionerBasePath" \
    "$K8S_os" "$K8S_virt" "$K8S_network2" "$K8S_mac2" "$K8S_ip2" \
    "$K8S_network3" "$K8S_mac3" "$K8S_ip3"
}

with_storage() {
  export K8S_storageType=raw K8S_storagePath=/img K8S_storageTarget=vdb K8S_storageSize=23G
  export K8S_storageType1=qcow2 K8S_storagePath1=/img K8S_storageTarget1=vdc K8S_storageSize1=10G
  export K8S_storageType2=null K8S_storagePath2=null K8S_storageTarget2=null K8S_storageSize2=null
  export K8S_storageType3=null K8S_storagePath3=null K8S_storageTarget3=null K8S_storageSize3=null
}

without_storage() {
  export K8S_storageType=null K8S_storagePath=null K8S_storageTarget=null K8S_storageSize=null
  export K8S_storageType1=null K8S_storagePath1=null K8S_storageTarget1=null K8S_storageSize1=null
  export K8S_storageType2=null K8S_storagePath2=null K8S_storageTarget2=null K8S_storageSize2=null
  export K8S_storageType3=null K8S_storagePath3=null K8S_storageTarget3=null K8S_storageSize3=null
}

@test "qemu: localhost provisioning creates and attaches each storage disk (#68)" {
  export K8S_provisionerHost=localhost
  with_storage
  run provision_node
  [ "$status" -eq 0 ]
  grep -q 'PSEUDO: qemu-img create -f raw /img/probe-k8s-node1-vdb.raw 23G' "$STREAM"
  grep -q 'PSEUDO: virsh attach-disk --domain node1 /img/probe-k8s-node1-vdb.raw --target vdb --persistent --config --live' "$STREAM"
  grep -q 'PSEUDO: qemu-img create -f qcow2 /img/probe-k8s-node1-vdc.qcow2 10G' "$STREAM"
  grep -q 'PSEUDO: virsh attach-disk --domain node1 /img/probe-k8s-node1-vdc.qcow2 --target vdc --persistent --config --live' "$STREAM"
  [ "$(grep -c 'attach-disk' "$STREAM")" -eq 2 ]
}

@test "qemu: remote provisioning attaches each storage disk over ssh (#68)" {
  export K8S_provisionerHost=hypervisor1
  with_storage
  run provision_node
  [ "$status" -eq 0 ]
  grep -q 'SSH: .*virsh attach-disk --domain node1 /img/probe-k8s-node1-vdb.raw --target vdb' "$STREAM"
  grep -q 'SSH: .*virsh attach-disk --domain node1 /img/probe-k8s-node1-vdc.qcow2 --target vdc' "$STREAM"
  [ "$(grep -c 'attach-disk' "$STREAM")" -eq 2 ]
}

@test "qemu: a host without storage attaches nothing (#68)" {
  export K8S_provisionerHost=localhost
  without_storage
  run provision_node
  [ "$status" -eq 0 ]
  run grep -q 'attach-disk' "$STREAM"
  [ "$status" -ne 0 ]
}
