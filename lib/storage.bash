#!/usr/bin/env bash

mount_all_iscsi_targets () {
  squawk 1 "mount all iscsi targets $*"
  while IFS="," read -r $csv_columns
  do
    squawk 185 "ROLE $K8S_role $K8S_user $K8S_ip1 $K8S_sshPort"
    squawk 3 "initializing iscsi node $*"
    squawk 33 "${K8S_iscsihost} ${K8S_iscsitarget} $K8S_iscsichapusername"
    if [[ "$K8S_iscsitarget" != "null" ]]; then
      squawk 3 "K8S_iscsitarget=$K8S_iscsitarget"
      command2run="iscsiadm --mode discovery --type sendtargets --portal ${K8S_iscsihost}"
      sudo_command $K8S_sshPort $K8S_user $K8S_ip1 "$command2run"
      if [[ ! -z "$K8S_iscsichapusername" ]]; then
        squawk 3 "K8S_iscsichapusername=$K8S_iscsichapusername"
        command2run="iscsiadm --mode node --portal ${K8S_iscsihost} --targetname ${K8S_iscsitarget} --op=update --name node.session.auth.authmethod --value=CHAP"
        command2run="$command2run && iscsiadm --mode node --portal ${K8S_iscsihost} --targetname ${K8S_iscsitarget} --op=update --name node.session.auth.username --value=$K8S_iscsichapusername"
        sudo_command $K8S_sshPort $K8S_user $K8S_ip1 "$command2run"
        if [[ ! -z "$K8S_iscsichappassword" ]]; then
          squawk 3 "K8S_iscsichappassword=$K8S_iscsichappassword"
          squawk 33 'iscichappassword'
          command2run="iscsiadm --mode node --portal ${K8S_iscsihost} --targetname ${K8S_iscsitarget} --op=update --name node.session.auth.password --value=$K8S_iscsichappassword"
          sudo_command $K8S_sshPort $K8S_user $K8S_ip1 "$command2run"
        else
          croak 3 'chapusername supplied without a chappassword!!!'
        fi
      fi
      command2run="iscsiadm --mode node --portal ${K8S_iscsihost} --targetname ${K8S_iscsitarget} --login"
      sudo_command $K8S_sshPort $K8S_user $K8S_ip1 "$command2run"
    fi
  done <<< "$kubash_hosts_csv_slurped"
}

check_first_device () {
  if [[ $1  == "vda" || $1  == "sda" || $1  == "hda" ]]; then
    croak 0 "WARNING! Formatting the first device is most likely a bad idea \n Open a support request at https://github.com/kubash/kubash/issues/new"
  fi
}

lvm_creation_run () {
  THIS_storageTarget=$1
  THIS_sshPort=$2
  THIS_user=$3
  THIS_ip1=$4
  check_first_device $THIS_storageTarget
  #command2run="blkid /dev/${THIS_storageTarget} && pvcreate /dev/${THIS_storageTarget} && vgcreate /dev/${THIS_storageTarget}"
  #sudo_command "$THIS_sshPort" "$THIS_user" "$THIS_ip1" "$command2run"
  command2run="pvcreate /dev/${THIS_storageTarget}"
  sudo_command "$THIS_sshPort" "$THIS_user" "$THIS_ip1" "$command2run"
  command2run="vgcreate ${K8S_lvm_vg} /dev/${THIS_storageTarget}"
  sudo_command "$THIS_sshPort" "$THIS_user" "$THIS_ip1" "$command2run"
}

lvm_extend_run () {
  THIS_storageTarget=$1
  THIS_sshPort=$2
  THIS_user=$3
  THIS_ip1=$4
  check_first_device $THIS_storageTarget
  command2run="pvcreate /dev/${THIS_storageTarget}"
  sudo_command "$THIS_sshPort" "$THIS_user" "$THIS_ip1" "$command2run"
  command2run="vgextend ${K8S_lvm_vg} /dev/${THIS_storageTarget}"
  sudo_command "$THIS_sshPort" "$THIS_user" "$THIS_ip1" "$command2run"
}

mount_one_storage_target () {
  # Mounts one storage device on the current host:
  # $1 storage path, $2 target device, $3 mount path ('lvm'
  # joins the device to the VG instead), $4 UUID ('null' =
  # generate one), $5 LVM mode: 'create' for the first
  # device, 'extend' for additional ones.
  local storage_target=$2 storage_mount=$3 storage_uuid=$4
  if [[ $storage_mount == "lvm" ]]; then
    if [[ $5 == 'create' ]]; then
      lvm_creation_run $storage_target ${K8S_sshPort} ${K8S_user} ${K8S_ip1}
    else
      lvm_extend_run $storage_target ${K8S_sshPort} ${K8S_user} ${K8S_ip1}
    fi
    return 0
  fi
  if [[ $storage_mount == "null" || $storage_target == "null" ]]; then
    return 0
  fi
  check_first_device $storage_target
  command2run="mkdir -p $storage_mount"
  sudo_command "$K8S_sshPort" "$K8S_user" "$K8S_ip1" "$command2run"
  # the UUID applies to this device only: the generated value
  # must be the one fsck, mkfs and fstab all use (#68)
  local mkfs_uuid_opt
  if [[ $storage_uuid != "null" ]]; then
    command2run="fsck.ext4 -p /dev/${storage_target}"
    mkfs_uuid_opt="-U ${storage_uuid}"
  else
    storage_uuid=$(uuidgen -r)
    command2run="fsck.ext4 -p UUID=${storage_uuid}"
    mkfs_uuid_opt="-U ${storage_uuid}"
  fi
  # This might fail in which case we'll format
  set +e
  sudo_command "$K8S_sshPort" "$K8S_user" "$K8S_ip1" "$command2run"
  if [[ $? == 0 ]]; then
    squawk 3 'fsck successful!'
  else
    set -e
    squawk 3 'fsck failed we will attempt to format the device!'
    command2run="mkfs.ext4 $mkfs_uuid_opt /dev/${storage_target}"
    sudo_command "$K8S_sshPort" "$K8S_user" "$K8S_ip1" "$command2run"
  fi
  set -e
  fstab_line_to_append="$(printf 'UUID=%s\t%s\text4\trw,relatime\t0 2\n' ${storage_uuid} ${storage_mount})"
  command2run="echo $fstab_line_to_append >> /etc/fstab"
  sudo_command "$K8S_sshPort" "$K8S_user" "$K8S_ip1" "$command2run"
  command2run="mount ${storage_mount}"
  sudo_command "$K8S_sshPort" "$K8S_user" "$K8S_ip1" "$command2run"
}

mount_all_other_targets () {
  squawk 1 "mount all other targets $*"
  while IFS="," read -r $csv_columns
  do
    squawk 185 "ROLE $K8S_role $K8S_user $K8S_ip1 $K8S_sshPort"
    squawk 3 "initializing storage node $*"
    if [[ ${K8S_storagePath} != "null" ]]; then
      mount_one_storage_target "$K8S_storagePath" "$K8S_storageTarget" \
        "$K8S_storageMountPath" "$K8S_storageUUID" create
    fi
    if [[ ${K8S_storagePath1} != "null" ]]; then
      mount_one_storage_target "$K8S_storagePath1" "$K8S_storageTarget1" \
        "$K8S_storageMountPath1" "$K8S_storageUUID1" extend
    fi
    if [[ ${K8S_storagePath2} != "null" ]]; then
      mount_one_storage_target "$K8S_storagePath2" "$K8S_storageTarget2" \
        "$K8S_storageMountPath2" "$K8S_storageUUID2" extend
    fi
    if [[ ${K8S_storagePath3} != "null" ]]; then
      mount_one_storage_target "$K8S_storagePath3" "$K8S_storageTarget3" \
        "$K8S_storageMountPath3" "$K8S_storageUUID3" extend
    fi
  done <<< "$kubash_hosts_csv_slurped"
}

taint_storage () {
  squawk 1 " taint_storage $*"
  count_storage=0
  for storage_node in "$@"
  do
    squawk 5 "kubectl --kubeconfig=$KUBECONFIG taint --overwrite node $storage_node storageOnly=true:PreferNoSchedule"
    kubectl --kubeconfig=$KUBECONFIG taint --overwrite node $storage_node storageOnly=true:PreferNoSchedule
    squawk 5 "kubectl --kubeconfig=$KUBECONFIG label --overwrite node $storage_node storage=true"
    kubectl --kubeconfig=$KUBECONFIG label --overwrite node $storage_node storage=true
    ((++count_storage))
  done
  if [[ $count_storage -eq 0 ]]; then
    squawk 3 'No storage nodes found, moving on without them'
  fi
}

taint_all_storage () {
  squawk 1 " taint_all_storage $*"
  count_all_storage=0
  nodes_to_taint=' '
  while IFS="," read -r $csv_columns
  do
    squawk 185 "ROLE $K8S_role $K8S_user $K8S_ip1 $K8S_sshPort"
    if [[ "$K8S_role" = "storage" ]]; then
      squawk 5 "ROLE $K8S_role $K8S_user $K8S_ip1 $K8S_sshPort"
      squawk 121 "nodes_to_taint $K8S_node $nodes_to_taint"
      new_nodes_to_taint="$K8S_node $nodes_to_taint"
      nodes_to_taint="$new_nodes_to_taint"
      ((++count_all_storage))
    fi
  done <<< "$kubash_hosts_csv_slurped"
  echo "count_all_storage $count_all_storage"
  if [[ $count_all_storage -eq 0 ]]; then
    squawk 150 "slurpy -----> $(echo $kubash_hosts_csv_slurped)"
    squawk 3 'No storage nodes found, moving on without them'
  else
    squawk 185 "ROLE $K8S_role $K8S_user $K8S_ip1 $K8S_sshPort"
    squawk 101 "taint these nodes_to_taint=$K8S_node $nodes_to_taint"
    taint_storage $nodes_to_taint
  fi
  mount_all_iscsi_targets
  mount_all_other_targets
}
