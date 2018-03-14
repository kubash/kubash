#!/usr/bin/env bats
PATH=/home/travis/build/joshuacox/kubash/bin:/home/travis/.kubash/bin:$PATH

@test "addition using bc" {
  result="$(echo 2+2 | bc)"
  [ "$result" -eq 4 ]
}

@test "ct" {
  [ -e "/home/travis/build/joshuacox/kubash/bin/ct" ]
}

@test "yaml2cluster test example" {
  yamlresult="$(kubash yaml2cluster /home/travis/build/joshuacox/kubash/examples/example-cluster.yaml -n example)"
  cp $HOME/.kube/config clusters/example/
  [ -e "/home/travis/build/joshuacox/kubash/clusters/example/provision.csv" ]
}

@test "minikube config" {
  result="$(cp $HOME/.kube/config clusters/example/)"
  [ -e "/home/travis/build/joshuacox/kubash/clusters/example/config" ]
}

@test "yaml2cluster primary_master" {
  result="$(cut -f2 -d, clusters/example/provision.csv|head -n1)"
  [ "$result" = 'primary_master' ]
}

@test "yaml2cluster cpu" {
  result="$(cut -f3 -d, clusters/example/provision.csv|head -n1)"
  [ "$result" -eq 1 ]
}

@test "yaml2cluster memory" {
  result="$(cut -f4 -d, clusters/example/provision.csv|head -n1)"
  [ "$result" -eq 1100 ]
}

@test "yaml2cluster network" {
  result="$(cut -f5 -d, clusters/example/provision.csv|head -n1)"
  [ "$result" = 'network=default' ]
}

@test "yaml2cluster mac" {
  result="$(cut -f6 -d, clusters/example/provision.csv|head -n1)"
  [ "$result" = '52:54:00:e2:8a:11' ]
}

@test "yaml2cluster dhcp" {
  result="$(cut -f7 -d, clusters/example/provision.csv|head -n1)"
  [ "$result" = 'dhcp' ]
}

@test "yaml2cluster localhost" {
  result="$(cut -f8 -d, clusters/example/provision.csv|head -n1)"
  [ "$result" = 'localhost' ]
}

@test "yaml2cluster root" {
  result="$(cut -f9 -d, clusters/example/provision.csv|head -n1)"
  [ "$result" = 'root' ]
}

@test "yaml2cluster 22" {
  result="$(cut -f10 -d, clusters/example/provision.csv|head -n1)"
  [ "$result" -eq 22 ]
}

@test "yaml2cluster libvirt" {
  result="$(cut -f11 -d, clusters/example/provision.csv|head -n1)"
  [ "$result" = '/var/lib/libvirt/images' ]
}

@test "yaml2cluster kubeadm" {
  result="$(cut -f12 -d, clusters/example/provision.csv|head -n1)"
  [ "$result" = 'kubeadm' ]
}

@test "yaml2cluster qemu" {
  result="$(cut -f13 -d, clusters/example/provision.csv|head -n1)"
  [ "$result" = 'qemu' ]
}

@test "checkbashisms kubash" {
  skip "Skpping for now"
  result="$(checkbashisms -xnfp ./bin/kubash)"
  [ -z "$result" ]
}

@test "checkbashisms bootstrap" {
  skip "Skpping for now"
  result="$(checkbashisms -xnfp ./bootstrap)"
  [ -z "$result" ]
}
@test "checkbashisms scripts" {
  skip "Skpping for now"
  result="$(checkbashisms -xnfp ./scripts/*)"
  [ -z "$result" ]
}

@test "checkbashisms w8s" {
  skip "Skpping for now"
  result="$(checkbashisms -xnfp ./w8s/*)"
  [ -z "$result" ]
}
