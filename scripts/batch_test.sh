#!/bin/bash
set -eux
THIS_CWD=$(pwd)
cd $THIS_CWD
scripts/test_bootstrap.sh
cd $THIS_CWD
scripts/test_yaml2cluster.sh
cd $THIS_CWD
scripts/test_bats.sh /home/thoth/.kubash
