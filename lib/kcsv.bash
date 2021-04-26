#!/usr/bin/env bash
user_csv_columns="user_email user_role"
uniq_hosts_list_columns="K8S_provisionerHost K8S_provisionerUser K8S_provisionerPort K8S_provisionerBasePath K8S_os K8S_kvm_os_variant K8S_virt"

test_kubash_csv_ver () {
  if [ "$KUBASH_CSV_VER" = '1.0.0' ]; then
    croak 1 "CSV version = $CSV_VER no longer supported"
    uniq_hosts_list_columns=$uniq_hosts_list_columns_1_0_0
    uniq_hosts="$(grep -v '^#' $KUBASH_PROVISION_CSV|cut -d,  -f9,10,11,12,13,14|sort|uniq)"
  elif [ "$KUBASH_CSV_VER" = '2.0.0' ]; then
    croak 1 "CSV version = $CSV_VER no longer supported"
    uniq_hosts_list_columns=$uniq_hosts_list_columns_1_0_0
    uniq_hosts="$(grep -v '^#' $KUBASH_PROVISION_CSV|cut -d, -f13,14,15,16,17,18|sort|uniq)"
  elif [ "$KUBASH_CSV_VER" = '3.0.0' ]; then
    croak 1 "CSV version = $CSV_VER no longer supported"
    uniq_hosts_list_columns=$uniq_hosts_list_columns_1_0_0
    uniq_hosts="$(grep -v '^#' $KUBASH_PROVISION_CSV|cut -d, -f13,14,15,16,17,18|sort|uniq)"
  elif [ "$KUBASH_CSV_VER" = '4.0.0' ]; then
    croak 1 "CSV version = $CSV_VER no longer supported"
    uniq_hosts_list_columns=$uniq_hosts_list_columns_1_0_0
    uniq_hosts="$(grep -v '^#' $KUBASH_PROVISION_CSV|cut -d, -f13,14,15,16,17,18|sort|uniq)"
  elif [ "$KUBASH_CSV_VER" = '5.0.0' ]; then
    uniq_hosts_list_columns=$uniq_hosts_list_columns_5_0_0
    uniq_hosts="$(grep -v '^#' $KUBASH_PROVISION_CSV|cut -d, -f13,14,15,16,17,18,19|sort|uniq)"
  else
    croak 3  "CSV columns cannot be set, csv_ver=$CSV_VER not recognized"
  fi
  squawk 9 "$uniq_hosts_list_columns"
  squawk 8 "$uniq_hosts"
}

set_csv_columns () {
  squawk 125 "prep the columns strings for csv input"
  if [ ! -z "$1" ]; then
    KUBASH_CSV_VER=$1
  else
    KUBASH_CSV_VER=$(cat $KUBASH_CSV_VER_FILE)
  fi
  if [ "$KUBASH_CSV_VER" = '1.0.0' ]; then
    csv_columns="$CSV_COLUMNS_1_0_0"
  elif [ "$KUBASH_CSV_VER" = '2.0.0' ]; then
    csv_columns="$CSV_COLUMNS_2_0_0"
  elif [ "$KUBASH_CSV_VER" = '3.0.0' ]; then
    csv_columns="$CSV_COLUMNS_3_0_0"
  elif [ "$KUBASH_CSV_VER" = '4.0.0' ]; then
    csv_columns="$CSV_COLUMNS_4_0_0"
  elif [ "$KUBASH_CSV_VER" = '5.0.0' ]; then
    csv_columns="$CSV_COLUMNS_5_0_0"
  elif [ "$KUBASH_CSV_VER" = '6.0.0' ]; then
    csv_columns="$CSV_COLUMNS_6_0_0"
  else
    croak 3  "CSV columns cannot be set, csv_ver=$CSV_VER not recognized"
  fi
  squawk 95 "csv_columns = $csv_columns"
}

hosts_csv_slurp () {
  squawk 19 "slurp hosts.csv"
  # Get rid of commented lines, and sort on the second and third mac address fields
  # This ensures hosts with more net interfaces are set after hosts with less interfaces
  kubash_hosts_csv_slurped="$(grep -v '^#' $KUBASH_HOSTS_CSV|sort -t , -k 19,19n  -k 16,16n)"
}

provision_csv_slurp () {
  squawk 19 "slurp provision.csv"
  # Get rid of commented lines, and sort on the second and third mac address fields
  # This ensures hosts with more net interfaces are set after hosts with less interfaces
  kubash_provision_csv_slurped="$(grep -v '^#' $KUBASH_PROVISION_CSV|sort -t , -k 19,19n  -k 16,16n)"
}

read_csv () {
  squawk 1 " read_csv"
  read_master_count=0

  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    squawk 5 "$K8S_node $K8S_user $K8S_ip1 $K8S_sshPort $K8S_role $K8S_provisionerUser $K8S_provisionerHost $K8S_provisionerUser $K8S_provisionerPort"
    if [[ "$K8S_role" == "master" ]]; then
      if [[ "$read_master_count" -lt "1" ]]; then
        echo "master_init_join $K8S_node $K8S_ip1 $K8S_provisionerUser $K8S_sshPort"
      else
        echo "master_join $K8S_node $K8S_ip1 $K8S_provisionerUser $K8S_sshPort"
      fi
      ((++read_master_count))
    fi
  done < $KUBASH_HOSTS_CSV

  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "node" || "$K8S_role" == "ingress" ]]; then
      echo "node_join $K8S_node $K8S_ip1 $K8S_provisionerUser $K8S_sshPort"
    fi
  done < $KUBASH_HOSTS_CSV
}


read_provision_csv () {
  squawk 1 " read_provision_csv"
  read_master_count=0

  set_csv_columns
  squawk 1 "$CSV_COLUMNS_5_0_0"
  while IFS="," read -r $csv_columns
  do
    squawk 5 "$K8S_node,$K8S_role,$K8S_cpuCount,$K8S_Memory,$K8S_sshPort,$K8S_network1,$K8S_mac1,$K8S_ip1,$K8S_routingprefix1,$K8S_subnetmask1,$K8S_broadcast1,$K8S_gateway1,$K8S_provisionerHost,$K8S_provisionerUser,$K8S_provisionerPort,$K8S_provisionerBasePath,$K8S_os,$K8S_kvm_os_variant,$K8S_virt,$K8S_network2,$K8S_mac2,$K8S_ip2,$K8S_routingprefix2,$K8S_subnetmask2,$K8S_broadcast2,$K8S_gateway2,$K8S_network3,$K8S_mac3,$K8S_ip3,$K8S_routingprefix3,$K8S_subnetmask3,$K8S_broadcast3,$K8S_gateway3,$K8S_iscsitarget,$K8S_iscsichapusername,$K8S_iscsichappassword,$K8S_iscsihost,$K8S_storagePath,$K8S_storageType,$K8S_storageSize,$K8S_storageTarget,$K8S_storageMountPath,$K8S_storageUUID"
  done < $KUBASH_PROVISION_CSV
}

check_csv () {
  squawk 4 " check_csv"
  if [[ ! -e $KUBASH_HOSTS_CSV ]]; then
    horizontal_rule
    echo "$KUBASH_HOSTS_CSV file not found!"
    croak 3  "You must provision a cluster first, and specify a valid cluster with the --clustername option and place your hosts.csv file in its directory!"
  fi
}
