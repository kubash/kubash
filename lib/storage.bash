#!/usr/bin/env bash

mount_all_iscsi_targets () {
  squawk 1 "mount all iscsi targets $@"
  while IFS="," read -r $csv_columns
  do
    squawk 185 "ROLE $K8S_role $K8S_user $K8S_ip1 $K8S_sshPort"
    if [[ "$K8S_role" = "storage" ]]; then
      squawk 3 "initializing storage node $@"
      squawk 33 "${K8S_iscsihost} ${K8S_iscsitarget} $K8S_iscsichapusername"
      if [[ ! -z "$K8S_iscsitarget" ]]; then
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
    fi
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
    croak 3  'No storage nodes found!'
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
    croak 3 'No storage nodes found!!!'
  else
    squawk 185 "ROLE $K8S_role $K8S_user $K8S_ip1 $K8S_sshPort"
    squawk 101 "taint these nodes_to_taint=$K8S_node $nodes_to_taint"
    taint_storage $nodes_to_taint
  fi
  mount_all_iscsi_targets
}
