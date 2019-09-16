#!/usr/bin/env bats
PATH=/home/travis/build/joshuacox/kubash/bin:/home/travis/.kubash/bin:$PATH
setup () {
  #MY_TMP=$(mktemp --suffix=cluster -d -p clusters exampleXXX )
  MY_TMP=exampleOWFjMGQ4ZjMtest
}

@test "yaml2cluster test" {
  rm -Rf clusters/$MY_TMP
  yamlresult="$(kubash yaml2cluster examples/example-cluster.yaml -n $MY_TMP)"
#  cp $HOME/.kube/config clusters/$MY_TMP/
  [ -e "clusters/$MY_TMP/provision.csv" ]
}

@test "minikube config" {
  result="$(cp $HOME/.kube/config clusters/$MY_TMP/)"
  [ -e "clusters/$MY_TMP/config" ]
}

# 2  K8S_role 
@test "yaml2cluster primary_master" {
  result="$(cut -f2 -d, clusters/$MY_TMP/provision.csv|head -n1)"
  [ "$result" = 'primary_master' ]
}
# from here on out we will use tail instead of head and look at the last host
@test "yaml2cluster storage" {
  result="$(cut -f2 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = 'storage' ]
}

# 3  K8S_cpuCount 
@test "yaml2cluster cpu" {
  result="$(cut -f3 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" -eq 2 ]
}

# 4  K8S_Memory
@test "yaml2cluster memory" {
  result="$(cut -f4 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" -eq 2048 ]
}

# 5  K8S_sshPort
@test "yaml2cluster sshPort" {
  result="$(cut -f5 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" -eq 22 ]
}

# 6  K8S_network1
@test "yaml2cluster network1" {
  result="$(cut -f6 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = 'bridge=br0' ]
}

# 7  K8S_mac1
@test "yaml2cluster mac1" {
  result="$(cut -f7 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '52:54:00:e2:8a:20' ]
}

# 8  K8S_ip1
@test "yaml2cluster ip" {
  result="$(cut -f8 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '10.0.0.34' ]
}

# 9  K8S_routingprefix1
@test "yaml2cluster routingprefix1" {
  result="$(cut -f9 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '10.0.0.0' ]
}

# 10 K8S_subnetmask1
@test "yaml2cluster subnetmask1" {
  result="$(cut -f10 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '255.255.255.0' ]
}

# 11 K8S_broadcast1
@test "yaml2cluster broadcast1" {
  result="$(cut -f11 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '10.0.0.255' ]
}

# 12 K8S_gateway1
@test "yaml2cluster gateway1" {
  result="$(cut -f12 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '10.0.0.1' ]
}

# 13 K8S_provisionerHost
@test "yaml2cluster localhost" {
  result="$(cut -f13 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = 'localhost' ]
}

# 14 K8S_provisionerUser
@test "yaml2cluster root" {
  result="$(cut -f14 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = 'root' ]
}

# 15 K8S_provisionerPort
@test "yaml2cluster 22" {
  result="$(cut -f15 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" -eq 22 ]
}

# 16 K8S_provisionerBasePath
@test "yaml2cluster libvirt" {
  result="$(cut -f16 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '/var/lib/libvirt/images' ]
}

# 17 K8S_os
@test "yaml2cluster os" {
  result="$(cut -f17 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = 'coreos' ]
}

# 18 K8S_kvm_os_variant
@test "yaml2cluster os_variant" {
  result="$(cut -f18 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = 'virtio26' ]
}

# 19 K8S_virt
@test "yaml2cluster virt" {
  result="$(cut -f19 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = 'qemu' ]
}

# 20 K8S_network2
@test "yaml2cluster network2" {
  result="$(cut -f20 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = 'network=default' ]
}

# 21 K8S_mac2
@test "yaml2cluster mac2" {
  result="$(cut -f21 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '52:54:00:e2:8a:21' ]
}


# 22 K8S_ip2
@test "yaml2cluster ip2" {
  result="$(cut -f22 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '10.2.2.35' ]
}

# 23 K8S_routingprefix2
@test "yaml2cluster routingprefix2" {
  result="$(cut -f23 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '10.2.2.0' ]
}

# 24 K8S_subnetmask2
@test "yaml2cluster subnetmask1" {
  result="$(cut -f24 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '255.255.0.0' ]
}

# 25 K8S_broadcast2
@test "yaml2cluster broadcast2" {
  result="$(cut -f25 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '10.2.2.255' ]
}

# 26 K8S_gateway2
@test "yaml2cluster gateway2" {
  result="$(cut -f26 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '10.2.2.1' ]
}

# 27 K8S_network3
@test "yaml3cluster network3" {
  result="$(cut -f27 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = 'network=default' ]
}

# 28 K8S_mac3
@test "yaml2cluster mac3" {
  result="$(cut -f28 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '52:54:00:e2:8a:22' ]
}

# 29 K8S_ip3
@test "yaml2cluster ip3" {
  result="$(cut -f29 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '10.3.3.36' ]
}

# 30 K8S_routingprefix3
@test "yaml2cluster routingprefix3" {
  result="$(cut -f30 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '10.3.3.0' ]
}

# 31 K8S_subnetmask3
@test "yaml2cluster subnetmask3" {
  result="$(cut -f31 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '255.0.0.0' ]
}

# 32 K8S_broadcast3
@test "yaml2cluster broadcast2" {
  result="$(cut -f32 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '10.3.3.255' ]
}

# 33 K8S_gateway3
@test "yaml2cluster gateway3" {
  result="$(cut -f33 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '10.3.3.1' ]
}

# 34 K8S_iscsitarget
@test "yaml2cluster iscsi target" {
  result="$(cut -f34 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = 'iqn.2005-10.org.freenas.ctl:exampletarg01' ]
}

# 35 K8S_iscsichapusername
@test "yaml2cluster iscsi chapusername" {
  result="$(cut -f35 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = 'chap_user' ]
}

# 36 K8S_iscsichappassword
@test "yaml2cluster iscsi chappassword" {
  result="$(cut -f36 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = 'chap_password' ]
}

# 37 K8S_iscsihost
@test "yaml2cluster iscsi host" {
  result="$(cut -f37 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '10.0.0.103:3260' ]
}

# These tests will use the second to last host (tail -n2|head -n1)

# 38 K8S_storagePath
@test "yaml2cluster storagePath" {
  result="$(cut -f38 -d, clusters/$MY_TMP/provision.csv|tail -n2|head -n1)"
  [ "$result" = '/var/lib/rook' ]
}
# 39 K8S_storageType
@test "yaml2cluster storageType" {
  result="$(cut -f39 -d, clusters/$MY_TMP/provision.csv|tail -n2|head -n1)"
  [ "$result" = 'raw' ]
}
# 40 K8S_storageSize
@test "yaml2cluster storageSize" {
  result="$(cut -f40 -d, clusters/$MY_TMP/provision.csv|tail -n2|head -n1)"
  [ "$result" = '11G' ]
}
# 41 K8S_storageTarget
@test "yaml2cluster storageTarget" {
  result="$(cut -f41 -d, clusters/$MY_TMP/provision.csv|tail -n2|head -n1)"
  [ "$result" = 'vdb' ]
}
# K8S_storageMountPath
@test "yaml2cluster storageMountPath" {
  result="$(cut -f42 -d, clusters/$MY_TMP/provision.csv|tail -n2|head -n1)"
  [ "$result" = '/var/lib/rook' ]
}
# K8S_storageUUID
@test "yaml2cluster storageUUID" {
  result="$(cut -f43 -d, clusters/$MY_TMP/provision.csv|tail -n2|head -n1)"
  [ "$result" = '05617ec5-96e9-48b6-ab4e-e70fa1339cdd' ]
}

@test "rm cluster test dir" {
  run rm -Rf clusters/$MY_TMP
  [ "$status" -eq 0 ]
}
