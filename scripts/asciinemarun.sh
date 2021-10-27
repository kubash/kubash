#!/bin/bash
set -eux
TARGET_OS=bionic
TARGET_VERSION=1.21.2
CLUSTER_NAME=kubash_test123
TMP=$(mktemp -d --suffix=.dir /tmp/AsciinemaRun.XXXXX)

runner () {
  COMMAND_2_RUN=$1
  FILE_2_SAVE=$2
  TITLE_4_CAST=$3
  asciinema \
    rec \
    --quiet \
    --title "$TITLE_4_CAST" \
    --idle-time-limit "2.5" \
    --command "$COMMAND_2_RUN" \
    "$FILE_2_SAVE"
}

runner "kubash build -y --target-os ${TARGET_OS}${TARGET_VERSION}" $TMP/build.json "Kubash build run"
runner "kubash yaml2cluster -n $CLUSTER_NAME" $TMP/yaml2cluster.json "Kubash yaml2cluster run"
runner "kubash provision -n $CLUSTER_NAME" $TMP/provision.json "Kubash provision run"
find $TMP -iname '*.json' 
