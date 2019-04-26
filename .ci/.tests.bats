#!/usr/bin/env bats
PATH=/home/travis/build/joshuacox/kubash/bin:/home/travis/.kubash/bin:$PATH
setup () {
  #MY_TMP=$(mktemp --suffix=cluster -d -p clusters exampleXXX )
  MY_TMP=exampleOWFjMGQ4ZjMtest
}

@test "yaml2cluster test" {
  rm -Rf clusters/$MY_TMP
  yamlresult="$(kubash yaml2cluster examples/example-cluster.yaml -n $MY_TMP)"
  cp $HOME/.kube/config clusters/$MY_TMP/
  [ -e "clusters/$MY_TMP/provision.csv" ]
}

@test "minikube config" {
  result="$(cp $HOME/.kube/config clusters/$MY_TMP/)"
  [ -e "clusters/$MY_TMP/config" ]
}

@test "yaml2cluster primary_master" {
  result="$(cut -f2 -d, clusters/$MY_TMP/provision.csv|head -n1)"
  [ "$result" = 'primary_master' ]
}

@test "yaml2cluster cpu" {
  result="$(cut -f3 -d, clusters/$MY_TMP/provision.csv|head -n1)"
  [ "$result" -eq 1 ]
}

@test "yaml2cluster memory" {
  result="$(cut -f4 -d, clusters/$MY_TMP/provision.csv|head -n1)"
  [ "$result" -eq 1100 ]
}

@test "yaml2cluster sshPort" {
  result="$(cut -f5 -d, clusters/$MY_TMP/provision.csv|head -n1)"
  [ "$result" -eq 22 ]
}

@test "yaml2cluster network" {
  result="$(cut -f6 -d, clusters/$MY_TMP/provision.csv|head -n1)"
  [ "$result" = 'network=default' ]
}

@test "yaml2cluster mac" {
  result="$(cut -f7 -d, clusters/$MY_TMP/provision.csv|head -n1)"
  [ "$result" = '52:54:00:e2:8a:11' ]
}

@test "yaml2cluster dhcp" {
  result="$(cut -f8 -d, clusters/$MY_TMP/provision.csv|head -n1)"
  [ "$result" = 'dhcp' ]
}

@test "yaml2cluster localhost" {
  result="$(cut -f13 -d, clusters/$MY_TMP/provision.csv|head -n1)"
  [ "$result" = 'localhost' ]
}

@test "yaml2cluster root" {
  result="$(cut -f14 -d, clusters/$MY_TMP/provision.csv|head -n1)"
  [ "$result" = 'root' ]
}

@test "yaml2cluster 22" {
  result="$(cut -f15 -d, clusters/$MY_TMP/provision.csv|head -n1)"
  [ "$result" -eq 22 ]
}

@test "yaml2cluster libvirt" {
  result="$(cut -f16 -d, clusters/$MY_TMP/provision.csv|head -n1)"
  [ "$result" = '/var/lib/libvirt/images' ]
}

@test "yaml2cluster kubeadm" {
  result="$(cut -f17 -d, clusters/$MY_TMP/provision.csv|head -n1)"
  [ "$result" = 'kubeadm' ]
}

@test "yaml2cluster qemu" {
  result="$(cut -f18 -d, clusters/$MY_TMP/provision.csv|head -n1)"
  [ "$result" = 'qemu' ]
}

@test "yaml2cluster iscsi target" {
  result="$(cut -f33 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = 'iqn.2005-10.org.freenas.ctl:exampletarg01' ]
}

@test "yaml2cluster iscsi chapusername" {
  result="$(cut -f34 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = 'chap_user' ]
}

@test "yaml2cluster iscsi chappassword" {
  result="$(cut -f35 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = 'chap_password' ]
}

@test "yaml2cluster iscsi host" {
  result="$(cut -f36 -d, clusters/$MY_TMP/provision.csv|tail -n1)"
  [ "$result" = '10.0.0.103:3260' ]
}

@test "rm cluster test dir" {
  run rm -Rf clusters/$MY_TMP
  [ "$status" -eq 0 ]
}
