#!/usr/bin/env bash

record_storage_failure () {
  # Appends a node to the list of hosts whose storage setup
  # failed, without duplicates; taint_all_storage reports the
  # list at the end (N-C8). The list is global on purpose: the
  # two mount phases below both contribute to it.
  storage_failed_hosts="${storage_failed_hosts:-}"
  case " $storage_failed_hosts " in
    *" $1 "*) ;;
    *) storage_failed_hosts="$storage_failed_hosts $1" ;;
  esac
}

mount_all_iscsi_targets () {
  squawk 1 "mount all iscsi targets $*"
  local failed_hosts=''
  while IFS="," read -r $csv_columns
  do
    # One host's iscsi failure must not abort the remaining
    # hosts' logins: run each host in its own subshell, record
    # the failure, and continue (N-C8).
    (
      set +e
      squawk 185 "ROLE $K8S_role $K8S_user $K8S_ip1 $K8S_sshPort"
      squawk 3 "initializing iscsi node $*"
      squawk 33 "${K8S_iscsihost} ${K8S_iscsitarget} $K8S_iscsichapusername"
      if [[ "$K8S_iscsitarget" != "null" ]]; then
        squawk 3 "K8S_iscsitarget=$K8S_iscsitarget"
        command2run="iscsiadm --mode discovery --type sendtargets --portal ${K8S_iscsihost}"
        sudo_command $K8S_sshPort $K8S_user $K8S_ip1 "$command2run"
        # CHAP is off unless a username is really configured: the
        # CSVs carry the literal string 'null' for "unset", which
        # the old -z test treated as a username (N-C2).
        if [[ "$K8S_iscsichapusername" != "null" && -n "$K8S_iscsichapusername" ]]; then
          squawk 3 "K8S_iscsichapusername=$K8S_iscsichapusername"
          command2run="iscsiadm --mode node --portal ${K8S_iscsihost} --targetname ${K8S_iscsitarget} --op=update --name node.session.auth.authmethod --value=CHAP"
          command2run="$command2run && iscsiadm --mode node --portal ${K8S_iscsihost} --targetname ${K8S_iscsitarget} --op=update --name node.session.auth.username --value=$K8S_iscsichapusername"
          sudo_command $K8S_sshPort $K8S_user $K8S_ip1 "$command2run"
          if [[ "$K8S_iscsichappassword" != "null" && -n "$K8S_iscsichappassword" ]]; then
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
    ) || { failed_hosts="$failed_hosts $K8S_node"; record_storage_failure "$K8S_node"; }
  done <<< "$kubash_hosts_csv_slurped"
  if [[ -n $failed_hosts ]]; then
    squawk 3 "iscsi setup failed on host(s):$failed_hosts"
    return 1
  fi
  return 0
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
  # Extend only joins a VG that exists: when the base device
  # never created one (absent, or plain-mounted), create it
  # instead of extending a VG that is not there (N-C6). The
  # decision is the VG's existence, not the device's slot.
  if guest_vg_exists "$THIS_sshPort" "$THIS_user" "$THIS_ip1" "${K8S_lvm_vg}"; then
    command2run="vgextend ${K8S_lvm_vg} /dev/${THIS_storageTarget}"
  else
    command2run="vgcreate ${K8S_lvm_vg} /dev/${THIS_storageTarget}"
  fi
  sudo_command "$THIS_sshPort" "$THIS_user" "$THIS_ip1" "$command2run"
}

guest_uuid () {
  # Prints the filesystem UUID of a device on the guest, or
  # nothing when the device has no filesystem. Mirrors
  # sudo_command's host dispatch, but returns stdout: routing
  # this through sudo_command would pollute the capture, since
  # squawk prints to stdout. Arguments: port, user, host, target.
  local command2run="blkid -s UUID -o value /dev/$4"
  if [[ "$3" == "localhost" ]]; then
    $PSEUDO bash -l -c "$command2run" 2>/dev/null
  else
    ssh -n -p $1 $2@$3 "$PSEUDO bash -l -c '$command2run'" 2>/dev/null
  fi
}

guest_vg_exists () {
  # Returns 0 when the named volume group exists on the guest,
  # 1 otherwise. Mirrors guest_uuid's host dispatch, but reports
  # an exit status instead of stdout. Arguments: port, user,
  # host, vg.
  local command2run="vgs $4 >/dev/null 2>&1"
  if [[ "$3" == "localhost" ]]; then
    $PSEUDO bash -l -c "$command2run"
  else
    ssh -n -p $1 $2@$3 "$PSEUDO bash -l -c '$command2run'"
  fi
}

mount_one_storage_target () {
  # Mounts one storage device on the current host:
  # $1 storage path, $2 target device, $3 mount path ('lvm'
  # joins the device to the VG instead), $4 UUID ('null' =
  # generate one), $5 LVM mode: 'create' for the first
  # device, 'extend' for additional ones.
  local storage_target=$2 storage_mount=$3 storage_uuid=$4
  # A 'null' target or mountpoint means "no storage here": bail
  # before the LVM branch, or storageTarget=null with
  # storageMountPath=lvm reaches pvcreate /dev/null (N-C7).
  if [[ $storage_mount == "null" || $storage_target == "null" ]]; then
    return 0
  fi
  if [[ $storage_mount == "lvm" ]]; then
    if [[ $5 == 'create' ]]; then
      lvm_creation_run $storage_target ${K8S_sshPort} ${K8S_user} ${K8S_ip1}
    else
      lvm_extend_run $storage_target ${K8S_sshPort} ${K8S_user} ${K8S_ip1}
    fi
    return 0
  fi
  check_first_device $storage_target
  command2run="mkdir -p $storage_mount"
  sudo_command "$K8S_sshPort" "$K8S_user" "$K8S_ip1" "$command2run"
  # the UUID applies to this device only: the generated value
  # must be the one fsck, mkfs and fstab all use (#68)
  local mkfs_uuid_opt supplied_uuid=0
  if [[ $storage_uuid != "null" ]]; then
    supplied_uuid=1
    command2run="fsck.ext4 -p /dev/${storage_target}"
    mkfs_uuid_opt="-U ${storage_uuid}"
  else
    # A disk reused from an earlier provision may already carry a
    # filesystem: reuse its UUID instead of generating a fresh
    # one, or the fsck below fails and the disk gets reformatted.
    storage_uuid=$(guest_uuid "$K8S_sshPort" "$K8S_user" "$K8S_ip1" "$storage_target")
    if [[ -z $storage_uuid ]]; then
      storage_uuid=$(uuidgen -r)
    fi
    command2run="fsck.ext4 -p UUID=${storage_uuid}"
    mkfs_uuid_opt="-U ${storage_uuid}"
  fi
  # This might fail in which case we'll format
  set +e
  sudo_command "$K8S_sshPort" "$K8S_user" "$K8S_ip1" "$command2run"
  if [[ $? == 0 ]]; then
    squawk 3 'fsck successful!'
    if [[ $supplied_uuid -eq 1 ]]; then
      # fsck against /dev/<target> passes for any filesystem on
      # the device, so a supplied UUID must be checked against
      # the UUID the device actually carries before it is
      # recorded in fstab (N-C4). A UUID blkid cannot read
      # cannot be checked, so it is left to the mount to fail.
      local actual_uuid
      actual_uuid=$(guest_uuid "$K8S_sshPort" "$K8S_user" "$K8S_ip1" "$storage_target")
      if [[ -n $actual_uuid && $actual_uuid != "$storage_uuid" ]]; then
        croak 3 "storage device /dev/${storage_target} has UUID ${actual_uuid}, not the supplied ${storage_uuid}"
      fi
    fi
  else
    set -e
    squawk 3 'fsck failed we will attempt to format the device!'
    command2run="mkfs.ext4 $mkfs_uuid_opt /dev/${storage_target}"
    sudo_command "$K8S_sshPort" "$K8S_user" "$K8S_ip1" "$command2run"
  fi
  set -e
  fstab_line_to_append="$(printf 'UUID=%s\t%s\text4\trw,relatime\t0 2\n' ${storage_uuid} ${storage_mount})"
  # A re-run must not duplicate the fstab entry for this UUID or
  # mountpoint, and a device that is already mounted needs
  # neither a new fstab line nor another mount (N-C3).
  command2run="mountpoint -q ${storage_mount} || { grep -qs \"UUID=${storage_uuid}[[:space:]]\" /etc/fstab || grep -qs \"[[:space:]]${storage_mount}[[:space:]]\" /etc/fstab || echo $fstab_line_to_append >> /etc/fstab; }"
  sudo_command "$K8S_sshPort" "$K8S_user" "$K8S_ip1" "$command2run"
  command2run="mountpoint -q ${storage_mount} || mount ${storage_mount}"
  sudo_command "$K8S_sshPort" "$K8S_user" "$K8S_ip1" "$command2run"
}

mount_all_other_targets () {
  squawk 1 "mount all other targets $*"
  local failed_hosts=''
  while IFS="," read -r $csv_columns
  do
    squawk 185 "ROLE $K8S_role $K8S_user $K8S_ip1 $K8S_sshPort"
    squawk 3 "initializing storage node $*"
    # One host's (or device's) failure must not abort the
    # remaining devices and hosts: each device runs in its own
    # subshell, failures are recorded, and the loop continues
    # (N-C8). The outer subshell carries the per-host failure
    # count out; the inner ones isolate each device.
    (
      set +e
      host_failed=0
      if [[ ${K8S_storagePath} != "null" ]]; then
        ( mount_one_storage_target "$K8S_storagePath" "$K8S_storageTarget" \
          "$K8S_storageMountPath" "$K8S_storageUUID" create ) || host_failed=1
      fi
      if [[ ${K8S_storagePath1} != "null" ]]; then
        ( mount_one_storage_target "$K8S_storagePath1" "$K8S_storageTarget1" \
          "$K8S_storageMountPath1" "$K8S_storageUUID1" extend ) || host_failed=1
      fi
      if [[ ${K8S_storagePath2} != "null" ]]; then
        ( mount_one_storage_target "$K8S_storagePath2" "$K8S_storageTarget2" \
          "$K8S_storageMountPath2" "$K8S_storageUUID2" extend ) || host_failed=1
      fi
      if [[ ${K8S_storagePath3} != "null" ]]; then
        ( mount_one_storage_target "$K8S_storagePath3" "$K8S_storageTarget3" \
          "$K8S_storageMountPath3" "$K8S_storageUUID3" extend ) || host_failed=1
      fi
      exit $host_failed
    ) || { failed_hosts="$failed_hosts $K8S_node"; record_storage_failure "$K8S_node"; }
  done <<< "$kubash_hosts_csv_slurped"
  if [[ -n $failed_hosts ]]; then
    squawk 3 "storage setup failed on host(s):$failed_hosts"
    return 1
  fi
  return 0
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
  # Both storage phases run even when one host fails in the
  # other: the mount functions record failures and return
  # non-zero instead of aborting, so this is the single place
  # the run stops, with the failed-host list (N-C8).
  storage_failed_hosts=''
  set +e
  mount_all_iscsi_targets
  mount_all_other_targets
  set -e
  if [[ -n $storage_failed_hosts ]]; then
    croak 3 "storage setup failed on host(s):$storage_failed_hosts"
  fi
}
