#!/usr/bin/env bash

provisioner () {
  squawk 1 " provisioner"
  slurpy="$(grep -v '^#' $KUBASH_PROVISION_CSV)"
  squawk 8 "$slurpy"
  apparmor_fixed='false'
  if [[ -e "$KUBASH_HOSTS_CSV" ]]; then
    horizontal_rule
    rm $KUBASH_HOSTS_CSV
  fi
  touch $KUBASH_HOSTS_CSV
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
      if [[ "$apparmor_fixed" == 'false' && "$K8S_os" == "coreos" ]]; then
        #apparmor_fix_all_provisioning_hosts
        apparmor_fixed='true'
      fi
      if [[ "$K8S_virt" = "qemu" ]]; then
        squawk 9 "qemu-provisioner $K8S_node $K8S_role $K8S_cpuCount $K8S_Memory $K8S_network1 $K8S_mac1 $K8S_ip1 $K8S_provisionerHost $K8S_provisionerUser $K8S_provisionerPort $K8S_provisionerBasePath $K8S_os $K8S_virt $K8S_network2 $K8S_mac2 $K8S_ip2 $K8S_network3 $K8S_mac3 $K8S_ip3"
        qemu-provisioner $K8S_node $K8S_role $K8S_cpuCount $K8S_Memory $K8S_network1 $K8S_mac1 $K8S_ip1 $K8S_provisionerHost $K8S_provisionerUser $K8S_provisionerPort $K8S_provisionerBasePath $K8S_os $K8S_virt $K8S_network2 $K8S_mac2 $K8S_ip2 $K8S_network3 $K8S_mac3 $K8S_ip3
      elif [[ "$K8S_virt" = "vbox" ]]; then
        vbox-provisioner $K8S_node $K8S_role $K8S_cpuCount $K8S_Memory $K8S_network1 $K8S_mac1 $K8S_ip1 $K8S_provisionerHost $K8S_provisionerUser $K8S_provisionerPort $K8S_provisionerBasePath $K8S_os $K8S_virt $K8S_network2 $K8S_mac2 $K8S_ip2 $K8S_network3 $K8S_mac3 $K8S_ip3
      else
  echo "virtualization technology '$K8S_virt' not recognized"
      fi
      squawk 4 "provisioned"
  done <<< "$slurpy"
}

copy_image_to_all_provisioning_hosts () {
  squawk 1 "copy_image_to_all_provisioning_hosts"
  # P-C3: per-row base image name; never mutate the global
  # KVM_BASE_IMG in the loop below (a coreos row would otherwise
  # make every later non-coreos row copy/provision against
  # kubash.img, which was never built for it).
  local copy_base_img

  KUBASH_CSV_VER=$(cat $KUBASH_CSV_VER_FILE)
  test_kubash_csv_ver
  copy_image_tmp_para=$(mktemp -d)
  touch $copy_image_tmp_para/hopper
  while IFS="," read -r $uniq_hosts_list_columns
  do
    squawk 9 " $K8S_provisionerHost $K8S_provisionerUser $K8S_provisionerPort $K8S_provisionerBasePath $K8S_os $K8S_virt"
    if [[ "$K8S_os" == "coreos" ]]; then
      copy_base_img=kubash.img
    else
      copy_base_img=$KVM_BASE_IMG
    fi
    if [[ "$KVM_builderHost" == 'localhost' ]]; then
      if [[ "$K8S_provisionerHost" == 'localhost' ]]; then
        # this command can fail the or should take care of the edge case
        set +e
        echo 'If the first cp fails, ignore the error, we will attempt without the hardlink'
        copyimagecommand2run="$PSEUDO cp -al $KVM_builderBasePath/$K8S_os-$copy_base_img $K8S_provisionerBasePath/$KUBASH_CLUSTER_NAME-k8s-$copy_base_img || $PSEUDO cp --reflink=auto $KVM_builderBasePath/$K8S_os-$copy_base_img $K8S_provisionerBasePath/$KUBASH_CLUSTER_NAME-k8s-$copy_base_img"
        set -e
        squawk 7 "$copyimagecommand2run"
        echo  "$copyimagecommand2run" >> $copy_image_tmp_para/hopper
      else
        # this command can fail the or should take care of the edge case
        set +e
        echo 'If the first cp fails, ignore the error, we will attempt without the hardlink'
        copyimagecommand2run="rsync $KUBASH_RSYNC_OPTS \"ssh -p $K8S_provisionerPort\" $KVM_builderBasePath/$K8S_os-$copy_base_img $K8S_provisionerUser@$K8S_provisionerHost:$K8S_provisionerBasePath/$K8S_os-$copy_base_img;ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost \"cp -al $K8S_provisionerBasePath/$K8S_os-$copy_base_img $K8S_provisionerBasePath/$KUBASH_CLUSTER_NAME-k8s-$copy_base_img || cp --reflink=auto $K8S_provisionerBasePath/$K8S_os-$copy_base_img $K8S_provisionerBasePath/$KUBASH_CLUSTER_NAME-k8s-$copy_base_img\""
        set -e
        squawk 7 "$copyimagecommand2run"
        echo  "$copyimagecommand2run" >> $copy_image_tmp_para/hopper
      fi
    else
      if [[ "$K8S_provisionerHost" == "$KVM_builderHost" ]]; then
        # this command can fail the or should take care of the edge case
        set +e
        echo 'If the first cp fails, ignore the error, we will attempt without the hardlink'
        copyimagecommand2run="$PSEUDO cp -al $KVM_builderBasePath/$K8S_os-$copy_base_img $K8S_provisionerBasePath/$KUBASH_CLUSTER_NAME-k8s-$copy_base_img || $PSEUDO cp --reflink=auto $KVM_builderBasePath/$K8S_os-$copy_base_img $K8S_provisionerBasePath/$KUBASH_CLUSTER_NAME-k8s-$copy_base_img"
        set -e
        squawk 7 "$copyimagecommand2run"
        echo  "$copyimagecommand2run" >> $copy_image_tmp_para/hopper
      else
        # this command can fail the or should take care of the edge case
        set +e
        echo 'If the first cp fails, ignore the error, we will attempt without the hardlink'
        copyimagecommand2run="ssh -n -p $KVM_builderPort $KVM_builderUser@$KVM_builderHost 'rsync $KUBASH_RSYNC_OPTS \"ssh -p $K8S_provisionerPort\" $KVM_builderBasePath/$K8S_os-$copy_base_img $K8S_provisionerUser@$K8S_provisionerHost:$K8S_provisionerBasePath/$K8S_os-$copy_base_img; ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost \"cp -al $K8S_provisionerBasePath/$K8S_os-$copy_base_img $K8S_provisionerBasePath/$KUBASH_CLUSTER_NAME-k8s-$copy_base_img || cp --reflink=auto $K8S_provisionerBasePath/$K8S_os-$copy_base_img $K8S_provisionerBasePath/$KUBASH_CLUSTER_NAME-k8s-$copy_base_img\"'"
        set -e
        squawk 7 "$copyimagecommand2run"
        echo  "$copyimagecommand2run" >> $copy_image_tmp_para/hopper
      fi
    fi
  done <<< "$uniq_hosts"

  if [[ "$VERBOSITY" -gt "9" ]] ; then
    cat $copy_image_tmp_para/hopper
  fi
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    $PARALLEL  -j $PARALLEL_JOBS -- < $copy_image_tmp_para/hopper
    rm -Rf $copy_image_tmp_para
  else
    # P-C6: run the hopper with -e so a failed copy aborts the run
    # instead of being masked by a later line's success (plain bash
    # exits with the LAST line's status only), and keep the hopper
    # on failure as the only record of what was attempted.
    if bash -e $copy_image_tmp_para/hopper; then
      rm -Rf $copy_image_tmp_para
    else
      croak 1 "copy_image_to_all_provisioning_hosts: image copy failed; hopper kept at $copy_image_tmp_para/hopper"
    fi
  fi
}

apparmor_fix_all_provisioning_hosts () {
  squawk 1 "apparmor_fix_all_provisioning_hosts"
  KUBASH_CSV_VER=$(cat $KUBASH_CSV_VER_FILE)
  test_kubash_csv_ver
  apparmor_tmp_para=$(mktemp -d)
  touch $apparmor_tmp_para/hopper
  #CURLY="bash $(curl -Ls https://raw.githubusercontent.com/kubash/kubash/master/scripts/libvirtarmor)"
  CURLY="curl -Ls https://raw.githubusercontent.com/kubash/kubash/master/scripts/libvirtarmor|bash"
  #"K8S_provisionerHost K8S_provisionerUser K8S_provisionerPort K8S_provisionerBasePath K8S_os K8S_virt"
  while IFS="," read -r $uniq_hosts_list_columns
  do
    if [[ "$K8S_provisionerHost" = 'localhost' ]]; then
      echo "$CURLY" >> $apparmor_tmp_para/hopper
    else
      squawk 9 "ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost \"$CURLY\""
      echo "ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost \"$CURLY\"" \
        >> $apparmor_tmp_para/hopper
    fi
  done <<< "$uniq_hosts"

  if [[ "$VERBOSITY" -gt "9" ]] ; then
    cat $apparmor_tmp_para/hopper
  fi
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    $PARALLEL  -j $PARALLEL_JOBS -- < $apparmor_tmp_para/hopper
  else
    bash $apparmor_tmp_para/hopper
  fi
  rm -Rf $apparmor_tmp_para
}
