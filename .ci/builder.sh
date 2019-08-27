#!/bin/bash -l
. .ci/header
. ~/.bashrc
echo builder.sh
set -eux

main () {
  kubash build -y --target-os coreos --builder coreos 
}

time main $@
