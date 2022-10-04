#!/usr/bin/env bash

packer_create_pax_dir () {
  pax_target_os=$1
  target_version=$2
  if [[ -d "$KUBASH_DIR/pax/${pax_target_os}${target_version}" ]]; then
    squawk 5 "$pax_target_os directory exists leaving untouched"
  else
    cd $KUBASH_DIR
    export KUBASH_DIR=$KUBASH_DIR
    ./scripts/$pax_target_os $target_version
  fi
}

packer_build () {
  build_virt=$1
  target_os=$2
  target_build=$3
  build_num=$4
  chkdir $KVM_builderDir
  chkdir $KVM_builderTMP

  if [[ $VERBOSITY -gt '1' ]]; then
    LN_CMD='ln -fsv'
  else
    LN_CMD='ln -fs'
  fi

  set +e
  echo 'If the first cp fails, ignore the error, we will attempt without the hardlink'
  command2run="cd $KUBASH_DIR/pax;if [ ! -e "$KUBASH_DIR/pax/build" ]; then $LN_CMD $KVM_builderDir $KUBASH_DIR/pax/builds || cp --reflink=auto $KVM_builderDir $KUBASH_DIR/pax/builds; fi"
  sudo_command $KVM_builderPort $KVM_builderUser $KVM_builderHost "$command2run"
  set -e

  cd $KUBASH_DIR/pax/$target_os
  squawk 2 " Executing packer build... "

  if [[ "$debug" == "true" ]]; then
    debug_flag='-debug -on-error=ask'
    PACKER_LOG=1
  else
    debug_flag=''
    PACKER_LOG=0
  fi
  squawk 33 "$PSEUDO rsync $KUBASH_RSYNC_OPTS 'ssh -p $KVM_builderPort' $KUBASH_BIN/packer $KVM_builderUser@$KVM_builderHost:/usr/local/bin/packer"
  $PSEUDO rsync $KUBASH_RSYNC_OPTS "ssh -p $KVM_builderPort" $KUBASH_BIN/packer $KVM_builderUser@$KVM_builderHost:/usr/local/bin/packer
  squawk 2 "TMPDIR=$KVM_builderTMP packer build -only=$build_virt $debug_flag $target_build.json"
  squawk 10 "packer variable docs: https://www.packer.io/guides/hcl/variables"
  packer_build_env="KEYS_TO_ADD='$KEYS_TO_ADD' KEYS_URL='$KEYS_URL' PACKER_LOG=$PACKER_LOG TMPDIR=$KVM_builderTMP $(printenv |grep -i KUBASH|tr '\n' ' ') $(printenv |grep -i K8S|tr '\n' ' ') $(printenv |grep -i PACKER|tr '\n' ' ') $(printenv |grep -i PKR_VAR|tr '\n' ' ')"
  squawk 90 "packer build env : $packer_build_env"
  packer_build_cmd="packer build -only=$build_virt $debug_flag $target_build.json"
  squawk 95 "packer build cmd : $packer_build_cmd"
  command2run="cd $KUBASH_DIR/pax/$target_os; $packer_build_env $packer_build_cmd"
  sudo_command $KVM_builderPort $KVM_builderUser $KVM_builderHost "$command2run"

  TARGET_FILE=$KVM_builderDir/packer-$target_build-$build_virt/$target_build
  DESTINATION_FILE=$KVM_builderBasePath/$target_os-$KVM_BASE_IMG
  command2run="$MV_CMD $TARGET_FILE $DESTINATION_FILE"
  sudo_command $KVM_builderPort $KVM_builderUser $KVM_builderHost "$command2run"
  command2run="rm -Rf $KVM_builderDir/packer-$target_build-$build_virt"
  sudo_command $KVM_builderPort $KVM_builderUser $KVM_builderHost "$command2run"
}
