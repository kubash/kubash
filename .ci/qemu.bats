#!/usr/bin/env bats
# Tests for the storage disk attach in qemu-provisioner
# (lib/qemu.bash), issue #68: at the end of provisioning,
# each storage device set in the host's row is created and
# attached (virsh_disk_attach on a remote provisioner,
# virsh_disk_attach_localhost on localhost). 'null' rows
# must stay inert. $PSEUDO and ssh are logging stubs, so
# these pin the exact command stream.
#
# Also pins the Tier 2 provisioning fixes (bug hunt 2026-11-04):
# P-C2 (remote-builder copy used undefined $K8S_builderUser/
# $K8S_builderHost and typo $K8S_provsionerPort), P-C3 (a coreos
# row mutated the global KVM_BASE_IMG for later rows/calls),
# P-C5 (no dominfo guard, no failure rollback), P-C6 (with
# PARALLEL_JOBS=1 a failed hopper line was masked by a later
# line's success). The copy/build helpers live in
# lib/provision.bash / lib/build.bash and are sourced here too.

setup() {
  KUBASH_ROOT="${KUBASH_ROOT:-$HOME/.kubash}"
  STREAM="$BATS_TEST_TMPDIR/stream.log"
  : > "$STREAM"
  STUBBIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUBBIN"
  cat > "$STUBBIN/logstub" <<EOF
#!/bin/bash
echo "PSEUDO: \$*" >> "$STREAM"
case "\$*" in
  *'virsh dominfo'*) [ -n "\$DOMINFO_EXISTS" ] || exit 1 ;;
esac
exit 0
EOF
  cat > "$STUBBIN/ssh" <<EOF
#!/bin/bash
echo "SSH: \$*" >> "$STREAM"
case "\$*" in
  *'test -f'*) [ -n "\$SSH_TESTF_FAIL" ] && exit 1 ;;
  *'virsh dominfo'*) [ -n "\$SSH_DOMINFO_EXISTS" ] || exit 1 ;;
esac
exit 0
EOF
  chmod +x "$STUBBIN/logstub" "$STUBBIN/ssh"
  export PATH="$STUBBIN:$PATH"
  # shellcheck disable=SC1091
  source "$KUBASH_ROOT/lib/qemu.bash"
  # shellcheck disable=SC1091
  source "$KUBASH_ROOT/lib/provision.bash"
  # shellcheck disable=SC1091
  source "$KUBASH_ROOT/lib/kcsv.bash"
  # shellcheck disable=SC1091
  source "$KUBASH_ROOT/lib/build.bash"
  # shellcheck disable=SC1091
  source "$KUBASH_ROOT/lib/croak.bash"
  eval "$(sed -n '/^horizontal_rule ()/,/^}/p' "$KUBASH_ROOT/lib/utils.bash")"
  squawk() { :; }
  export PSEUDO=logstub
  export VERBOSITY=0 COLUMNS=80
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

# As provision_node, but in a child bash with errexit on, so a
# failing step aborts the run the way bin/kubash (set -e) aborts
# it. A plain ( set -e; provision_node ) does NOT work here:
# bats' `run` invokes its command in a tested context, which
# disables errexit for the whole invocation, including an explicit
# set -e inside it. The child bash is a fresh process, so its
# errexit state is its own; the functions it needs are exported.
provision_node_strict() {
  export -f provision_node qemu-provisioner qemu_provision_cleanup \
    squawk croak horizontal_rule \
    virsh_disk_attach virsh_disk_attach_localhost image_creator
  bash -e -c 'provision_node'
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

# One v6 provision.csv row. Fields 13-19 are what
# test_kubash_csv_ver cuts for the uniq-hosts list:
# provisionerHost,provisionerUser,provisionerPort,
# provisionerBasePath,os,kvm_os_variant,virt.
provision_row() {
  local node=$1 os=$2 host=$3 port=$4
  printf '%s,node,2,2048,22,network=default,52:54:00:00:00:01,10.0.1.21,24,255.255.255.0,10.0.1.255,10.0.1.1,%s,vagrant,%s,/img,%s,generic,qemu,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null\n' "$node" "$host" "$port" "$os"
}

# Shared env for the copy_image_to_all_provisioning_hosts tests.
# The provision.csv itself is written per test (rows vary).
setup_copy_test() {
  export KUBASH_CSV_VER_FILE="$BATS_TEST_TMPDIR/csv_version"
  echo '6.0.0' > "$KUBASH_CSV_VER_FILE"
  export KUBASH_PROVISION_CSV="$BATS_TEST_TMPDIR/provision.csv"
  export uniq_hosts_list_columns_6_0_0="K8S_provisionerHost K8S_provisionerUser K8S_provisionerPort K8S_provisionerBasePath K8S_os K8S_kvm_os_variant K8S_virt"
  export KUBASH_RSYNC_OPTS='-L -H -aze' KVM_builderBasePath=/builder
  export KVM_builderPort=22 KVM_builderUser=coopadmin PARALLEL_JOBS=1
  mkdir -p "$BATS_TEST_TMPDIR/tmpdir"
}

# Run copy_image_to_all_provisioning_hosts with mktemp pointed at
# a per-test dir, so the test can tell whether the hopper was kept
# (failure) or removed (success). Runs inside `run`'s subshell,
# so the TMPDIR change does not leak into the test process.
copy_with_tmpdir() {
  export TMPDIR="$BATS_TEST_TMPDIR/tmpdir"
  copy_image_to_all_provisioning_hosts
}

build_with_tmpdir() {
  export TMPDIR="$BATS_TEST_TMPDIR/tmpdir"
  build_all_in_parallel
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

@test "qemu: remote qcow2 attach reuses an existing disk, never recreates it" {
  export K8S_provisionerHost=hypervisor1
  with_storage
  run provision_node
  [ "$status" -eq 0 ]
  # test -f succeeds (the stub's default): no create, just attach
  run grep -q 'qemu-img create -f qcow2 /img/probe-k8s-node1-vdc.qcow2' "$STREAM"
  [ "$status" -ne 0 ]
  grep -q 'SSH: .*virsh attach-disk --domain node1 /img/probe-k8s-node1-vdc.qcow2 --target vdc' "$STREAM"
}

@test "qemu: remote qcow2 attach creates a missing disk exactly once" {
  export K8S_provisionerHost=hypervisor1
  export SSH_TESTF_FAIL=1
  with_storage
  run provision_node
  [ "$status" -eq 0 ]
  [ "$(grep -c 'qemu-img create -f qcow2 /img/probe-k8s-node1-vdc.qcow2' "$STREAM")" -eq 1 ]
  grep -q 'SSH: .*virsh attach-disk --domain node1 /img/probe-k8s-node1-vdc.qcow2 --target vdc' "$STREAM"
}

@test "qemu: a host without storage attaches nothing (#68)" {
  export K8S_provisionerHost=localhost
  without_storage
  run provision_node
  [ "$status" -eq 0 ]
  run grep -q 'attach-disk' "$STREAM"
  [ "$status" -ne 0 ]
}

@test "qemu: provisioning refuses when the domain already exists, localhost (P-C5)" {
  export K8S_provisionerHost=localhost DOMINFO_EXISTS=1
  without_storage
  run provision_node
  [ "$status" -ne 0 ]
  grep -q 'PSEUDO: virsh dominfo node1' "$STREAM"
  # refused before any image was created
  run grep -q 'qemu-img create' "$STREAM"
  [ "$status" -ne 0 ]
}

@test "qemu: provisioning refuses when the domain already exists, remote (P-C5)" {
  export K8S_provisionerHost=hypervisor1 SSH_DOMINFO_EXISTS=1
  without_storage
  run provision_node
  [ "$status" -ne 0 ]
  grep -q 'SSH: .*virsh dominfo node1' "$STREAM"
  # refused before any image was created
  run grep -q 'qemu-img create' "$STREAM"
  [ "$status" -ne 0 ]
}

@test "qemu: a failed virt-install rolls back the domain and node image, localhost (P-C5)" {
  export K8S_provisionerHost=localhost
  without_storage
  cat > "$STUBBIN/logstub" <<EOF
#!/bin/bash
echo "PSEUDO: \$*" >> "$STREAM"
case "\$*" in
  *'virsh dominfo'*) [ -n "\$DOMINFO_EXISTS" ] || exit 1 ;;
  *'virt-install'*) exit 1 ;;
esac
exit 0
EOF
  chmod +x "$STUBBIN/logstub"
  run provision_node_strict
  [ "$status" -ne 0 ]
  grep -q 'PSEUDO: virsh destroy node1' "$STREAM"
  grep -q 'PSEUDO: virsh undefine node1' "$STREAM"
  grep -q 'PSEUDO: rm -f /var/lib/libvirt/images/probe-k8s-node1.qcow2' "$STREAM"
}

@test "qemu: a failed virt-install rolls back the domain and node image, remote (P-C5)" {
  export K8S_provisionerHost=hypervisor1
  without_storage
  cat > "$STUBBIN/ssh" <<EOF
#!/bin/bash
echo "SSH: \$*" >> "$STREAM"
case "\$*" in
  *'test -f'*) [ -n "\$SSH_TESTF_FAIL" ] && exit 1 ;;
  *'virsh dominfo'*) [ -n "\$SSH_DOMINFO_EXISTS" ] || exit 1 ;;
  *'virt-install'*) exit 1 ;;
esac
exit 0
EOF
  chmod +x "$STUBBIN/ssh"
  run provision_node_strict
  [ "$status" -ne 0 ]
  grep -q 'SSH: .*virsh destroy node1' "$STREAM"
  grep -q 'SSH: .*virsh undefine node1' "$STREAM"
  grep -q 'SSH: .*rm -f /var/lib/libvirt/images/probe-k8s-node1.qcow2' "$STREAM"
}

@test "qemu: a coreos node does not change the base image for the next node (P-C3)" {
  export K8S_provisionerHost=localhost
  export KUBASH_DIR="$KUBASH_ROOT"
  export KUBASH_CLUSTERS_DIR="$BATS_TEST_TMPDIR/clusters"
  mkdir -p "$KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/core1" "$KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/node1"
  cat > "$STUBBIN/ct" <<'EOF'
#!/bin/bash
cat
EOF
  chmod +x "$STUBBIN/ct"
  chkdir() { mkdir -p "$1"; }
  provision_coreos_then_debian() {
    qemu-provisioner core1 node 2 2048 \
      "$K8S_network1" "$K8S_mac1" "$K8S_ip1" localhost \
      "$K8S_provisionerUser" "$K8S_provisionerPort" "$K8S_provisionerBasePath" \
      coreos qemu "$K8S_network2" "$K8S_mac2" "$K8S_ip2" \
      "$K8S_network3" "$K8S_mac3" "$K8S_ip3"
    export K8S_node=node1 K8S_os='debian-gnu'
    provision_node
  }
  run provision_coreos_then_debian
  [ "$status" -eq 0 ]
  grep -q 'qemu-img create -f qcow2 -F qcow2 -b /var/lib/libvirt/images/probe-k8s-kubash.img /var/lib/libvirt/images/probe-k8s-core1.qcow2' "$STREAM"
  grep -q 'qemu-img create -f qcow2 -F qcow2 -b /var/lib/libvirt/images/probe-k8s-base.qcow2 /var/lib/libvirt/images/probe-k8s-node1.qcow2' "$STREAM"
}

@test "provision: remote builder copy uses the builder user/host and provisioner port (P-C2)" {
  setup_copy_test
  export KVM_builderHost=builderhost
  provision_row nodeA debian-gnu provhost 2222 > "$KUBASH_PROVISION_CSV"
  run copy_with_tmpdir
  [ "$status" -eq 0 ]
  grep -q 'coopadmin@builderhost' "$STREAM"
  grep -q 'ssh -p 2222' "$STREAM"
}

@test "provision: a coreos row does not change the base image for later rows (P-C3)" {
  setup_copy_test
  export KVM_builderHost=localhost
  {
    provision_row nodeA coreos localhost 22
    provision_row nodeB debian-gnu localhost 22
  } > "$KUBASH_PROVISION_CSV"
  run copy_with_tmpdir
  [ "$status" -eq 0 ]
  grep -q 'coreos-kubash.img' "$STREAM"
  grep -q 'debian-gnu-base.qcow2' "$STREAM"
}

@test "provision: with PARALLEL_JOBS=1 a failed copy aborts the run and the hopper is kept (P-C6)" {
  setup_copy_test
  export KVM_builderHost=localhost
  cat > "$STUBBIN/logstub" <<EOF
#!/bin/bash
echo "PSEUDO: \$*" >> "$STREAM"
case "\$*" in
  *failos*) exit 1 ;;
esac
exit 0
EOF
  chmod +x "$STUBBIN/logstub"
  {
    provision_row nodeA failos localhost 22
    provision_row nodeB debian-gnu localhost 22
  } > "$KUBASH_PROVISION_CSV"
  run copy_with_tmpdir
  [ "$status" -ne 0 ]
  [ -n "$(find "$BATS_TEST_TMPDIR/tmpdir" -name hopper -print -quit)" ]
}

@test "build: with PARALLEL_JOBS=1 a failed build aborts the run and the hopper is kept (P-C6)" {
  export KVM_builderTMP="$BATS_TEST_TMPDIR/buildertmp" KVM_builderDir="$BATS_TEST_TMPDIR/builderdir"
  export PARALLEL_JOBS=1
  mkdir -p "$BATS_TEST_TMPDIR/tmpdir"
  cat > "$STUBBIN/kubash" <<EOF
#!/bin/bash
echo "KUBASH: \$*" >> "$STREAM"
case "\$*" in
  *centos*) exit 1 ;;
esac
exit 0
EOF
  chmod +x "$STUBBIN/kubash"
  run build_with_tmpdir
  [ "$status" -ne 0 ]
  [ -n "$(find "$BATS_TEST_TMPDIR/tmpdir" -name hopper -print -quit)" ]
}
