#!/usr/bin/env bash

kvm-decommer () {
  squawk 5 "kvm-decommer-remote $@"
  REBASED_NODE=$1
  THRU_USER=$2
  THRU_HOST=$3
  THRU_PORT=$4
  NODE_PATH=$5
  qemunodeimg="$NODE_PATH/$KUBASH_CLUSTER_NAME-k8s-$REBASED_NODE.qcow2"

  command2run="virsh destroy $REBASED_NODE"
  squawk 8 "$command2run"
  sudo_command $THRU_PORT $THRU_USER $THRU_HOST "$command2run"
  command2run="virsh undefine $REBASED_NODE"
  squawk 8 "$command2run"
  sudo_command $THRU_PORT $THRU_USER $THRU_HOST "$command2run"
  command2run="rm $qemunodeimg"
  squawk 8 "$command2run"
  sudo_command $THRU_PORT $THRU_USER $THRU_HOST "$command2run"
}

remove_all_base_images_kvm () {
  # Now remove the cluster base images
  KUBASH_CSV_VER=$(cat $KUBASH_CSV_VER_FILE)
  test_kubash_csv_ver
  copy_image_tmp_para=$(mktemp -d)
  while IFS="," read -r $uniq_hosts_list_columns
  do
    if [[ "$K8S_os" == "coreos" ]]; then
      KVM_BASE_IMG=kubash.img
    fi
    command2run="rm $K8S_provisionerBasePath/$KUBASH_CLUSTER_NAME-k8s-$KVM_BASE_IMG"
    sudo_command $K8S_provisionerPort $K8S_provisionerUser $K8S_provisionerHost "$command2run"
  done <<< "$uniq_hosts"
}

decom_kvm () {
  squawk 1 "decom_kvm starting"
  if [[ -z "$kubash_provision_csv_slurped" ]]; then
    provision_csv_slurp
  fi
  squawk 19 "slurpy -----> $(echo $kubash_provision_csv_slurped)"
  # Write all hosts to inventory for id
  squawk 15 "decom_kvm loop starting"
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    squawk 19 "Loop $K8S_node $K8S_user $K8S_ip1 $K8S_provisionerPort $K8S_role $K8S_provisionerUser $K8S_provisionerHost $K8S_provisionerUser $K8S_provisionerPort"
    set +e
    kvm-decommer $K8S_node $K8S_provisionerUser $K8S_provisionerHost $K8S_provisionerPort $K8S_provisionerBasePath
    set -e
  done <<< "$kubash_provision_csv_slurped"
  squawk 16 'Looped through all hosts to be decommissioned'
  remove_all_base_images_kvm
}
