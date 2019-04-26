#!/usr/bin/env bash

coreos_build  () {
  build_virt=$1
  target_os=$2
  CHANNEL=$3
  chkdir $KVM_builderDir
  chkdir $KVM_builderTMP

  rsync $KUBASH_RSYNC_OPTS "ssh -p$KVM_builderPort" $KUBASH_DIR/pax/CoreOS_Image_Signing_Key.asc $KVM_builderUser@$KVM_builderHost:/tmp/
  command2run="gpg --import --keyid-format LONG /tmp/CoreOS_Image_Signing_Key.asc"
  sudo_command $KVM_builderPort $KVM_builderUser $KVM_builderHost "$command2run"
  command2run="cd $KVM_builderTMP; wget -c https://$CHANNEL.release.core-os.net/amd64-usr/current/coreos_production_qemu_image.img.bz2{,.sig}"
  sudo_command $KVM_builderPort $KVM_builderUser $KVM_builderHost "$command2run"
  command2run="cd $KVM_builderTMP;gpg --verify coreos_production_qemu_image.img.bz2.sig"
  sudo_command $KVM_builderPort $KVM_builderUser $KVM_builderHost "$command2run"
  command2run="cd $KVM_builderTMP;rm coreos_production_qemu_image.img.bz2.sig"
  sudo_command $KVM_builderPort $KVM_builderUser $KVM_builderHost "$command2run"
  command2run="cd $KVM_builderTMP;bunzip2 coreos_production_qemu_image.img.bz2"
  sudo_command $KVM_builderPort $KVM_builderUser $KVM_builderHost "$command2run"

  TARGET_FILE="$KVM_builderTMP/coreos_production_qemu_image.img"
  DESTINATION_FILE="$KVM_builderBasePath/$target_os-$KVM_BASE_IMG"
  command2run="$MV_CMD $TARGET_FILE $DESTINATION_FILE"
  sudo_command $KVM_builderPort $KVM_builderUser $KVM_builderHost "$command2run"
}

build_all_in_parallel () {
  squawk 1 'Building all targets in parallel'
  $PSEUDO rm -Rf $KVM_builderTMP
  $PSEUDO rm -Rf $KVM_builderDir
  build_all_tmp_para=$(mktemp -d --suffix='.para.tmp')
  touch $build_all_tmp_para/hopper
  OS_LIST=(centos kubeadm kubeadm2ha kubespray openshift ubuntu debian coreos)
  build_count=0
  while [ "x${OS_LIST[build_count]}" != "x" ]
  do
    command2run="kubash build --target-os=${OS_LIST[build_count]} -y"
    squawk 5 "$command2run"
    echo "$command2run" >> $build_all_tmp_para/hopper
    ((++build_count))
  done

  if [[ "$VERBOSITY" -gt "9" ]] ; then
    cat $build_all_tmp_para/hopper
  fi
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    $PARALLEL  -j $PARALLEL_JOBS -- < $build_all_tmp_para/hopper
  else
    bash $build_all_tmp_para/hopper
  fi
  rm -Rf $build_all_tmp_para
  squawk 1 'Done Building all targets'
}
