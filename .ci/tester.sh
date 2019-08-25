#!/bin/bash -l
. .ci/header
. ~/.bashrc
echo builder.sh

cleanup () {
  kubash -n coreos1 decommission -y 
  rm -Rf ~/.kubash/clusters/coreos1
}

main () {
  set -eux
  kubash -n coreos1 yaml2cluster ~/.kubash/examples/coreos1-stacked.yaml
  kubash -n coreos1 provision
  kubash -n coreos1 init
  cp ~/.kubash/clusters/coreos1/config ~/.kube/config
  cd ~/.kubash
  bats .ci/.tests.bats
  cleanup
}

cleanup
time main $@
