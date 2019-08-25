#!/bin/bash -l
pwd
ls -alh .ci/header
. .ci/header
. ~/.bashrc
echo ex.sh
whoami
set -eux
printenv
#which kubash
