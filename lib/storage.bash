#!/usr/bin/env bash

mount_all_iscsi_targets () {
  squawk 1 "mount all iscsi targets $@"
  while IFS="," read -r $csv_columns
  do
    squawk 185 "ROLE $K8S_role $K8S_user $K8S_ip1 $K8S_sshPort"
    squawk 3 "initializing storage node $@"
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

mount_all_other_targets () {
  squawk 1 "mount all other targets $@"
  while IFS="," read -r $csv_columns
  do
    squawk 185 "ROLE $K8S_role $K8S_user $K8S_ip1 $K8S_sshPort"
    squawk 3 "initializing storage node $@"
    squawk 3 "$K8S_storagePath $K8S_storageType $K8S_storageSize $K8S_storageTarget $K8S_storageMountPath $K8S_storageUUID"
    for storage_iteration in {0..3}
    do
      if [[ "$storage_iteration" == "0" ]]; then
        storage_iterator=''
      else
        storage_iterator=$storage_iteration
      fi
      squawk 3 "${K8S_storagePath${storage_iterator}} ${K8S_storageType${storage_iterator}} ${K8S_storageSize${storage_iterator}} ${K8S_storageTarget${storage_iterator}} ${K8S_storageMountPath${storage_iterator}} ${K8S_storageUUID${storage_iterator}}"
      if [[ ${K8S_storagePath${storage_iterator}} != "null" ]]; then
        squawk 3 "K8S_storagePath=$K8S_storagePath${storage_iterator}"
        if [[ ${K8S_storageMountPath${storage_iterator}} != "null" ]]; then
          if [[ ${K8S_storageTarget${storage_iterator}}  != "null" ]]; then
            if [[ ${K8S_storageTarget${storage_iterator}}  == "vda" || ${K8S_storageTarget${storage_iterator}}  == "sda" || ${K8S_storageTarget${storage_iterator}}  == "hda" ]]; then
              croak 0 "WARNING! Formatting the first device is most likely a bad idea \n Open a support request at https://github.com/kubash/kubash/issues/new"
            fi
            command2run="mkdir -p $K8S_storageMountPath${storage_iterator}"
            sudo_command "$K8S_sshPort" "$K8S_user" "$K8S_ip1" "$command2run"
            if [[ ${K8S_storageUUID${storage_iterator}} != "null" ]]; then
              command2run="fsck.ext4 -p /dev/${K8S_storageTarget${storage_iterator}}"
              K8S_storageMKFS_UUID_OPT="-U ${K8S_storageUUID${storage_iterator}}"
            else
              K8S_storageUUID=$(uuidgen -r)
              command2run="fsck.ext4 -p UUID=${K8S_storageUUID${storage_iterator}}"
              K8S_storageMKFS_UUID_OPT="-U ${K8S_storageUUID${storage_iterator}}"
            fi
            # This might fail in which case we'll format
            set +e
            sudo_command "$K8S_sshPort" "$K8S_user" "$K8S_ip1" "$command2run"
            if [[ $? == 0 ]]; then
              squawk 3 'fsck successful!'
            else
              set -e
              squawk 3 'fsck failed we will attempt to format the device!'
              command2run="mkfs.ext4 $K8S_storageMKFS_UUID_OPT /dev/${K8S_storageTarget${storage_iterator}}"
              sudo_command "$K8S_sshPort" "$K8S_user" "$K8S_ip1" "$command2run"
            fi
            set -e
            fstab_line_to_append="$(printf 'UUID=%s\t%s\text4\trw,relatime\t0 2\n' ${K8S_storageUUID${storage_iterator}} ${K8S_storageMountPath${storage_iterator}})"
            command2run="echo $fstab_line_to_append >> /etc/fstab"
            sudo_command "$K8S_sshPort" "$K8S_user" "$K8S_ip1" "$command2run"
            command2run="mount ${K8S_storageMountPath${storage_iterator}}"
            sudo_command "$K8S_sshPort" "$K8S_user" "$K8S_ip1" "$command2run"
          fi
        fi
      fi
    done
  done <<< "$kubash_hosts_csv_slurped"
}

taint_storage () {
  squawk 1 " taint_storage $@"
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
  squawk 1 " taint_all_storage $@"
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
