#!/usr/bin/env bash
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

  command2run="cd $KUBASH_DIR/pax;if [ ! -e "$KUBASH_DIR/pax/build" ]; then $LN_CMD $KVM_builderDir $KUBASH_DIR/pax/builds; fi"
  sudo_command $KVM_builderPort $KVM_builderUser $KVM_builderHost "$command2run"

  cd $KUBASH_DIR/pax/$target_os
  squawk 2 " Executing packer build..."

  if [[ "$debug" == "true" ]]; then
    debug_flag='-debug -on-error=ask'
    PACKER_LOG=1
  else
    debug_flag=''
    PACKER_LOG=0
  fi
  squawk 2 "TMPDIR=$KVM_builderTMP packer build -only=$build_virt $debug_flag $target_build.json"
  packer_build_cmd="packer build -only=$build_virt $debug_flag $target_build.json"
  command2run="cd $KUBASH_DIR/pax/$target_os; PACKER_LOG=$PACKER_LOG TMPDIR=$KVM_builderTMP $packer_build_cmd"
  do_command $KVM_builderPort $KVM_builderUser $KVM_builderHost "$command2run"

  TARGET_FILE=$KVM_builderDir/packer-$target_build-$build_virt/$target_build
  DESTINATION_FILE=$KVM_builderBasePath/$target_os-$KVM_BASE_IMG
  command2run="$MV_CMD $TARGET_FILE $DESTINATION_FILE"
  sudo_command $KVM_builderPort $KVM_builderUser $KVM_builderHost "$command2run"
  command2run="rm -Rf $KVM_builderDir/packer-$target_build-$build_virt"
  sudo_command $KVM_builderPort $KVM_builderUser $KVM_builderHost "$command2run"
}
