#!/usr/bin/env bash

yaml2cluster () {
  squawk 15 "yaml2cluster"
  yaml2cluster_tmp=$(mktemp -d)
  if [[ -z "$1" ]]; then
    croak 3  'yaml2cluster requires an argument'
  fi
  this_yaml=$1
  this_json=$yaml2cluster_tmp/this.json
  yaml2json $this_yaml > $this_json
  json2cluster $this_json
  rm $this_json
  rm -Rf $yaml2cluster_tmp
}

json2cluster () {
  squawk 15 "json2cluster"
  json2cluster_tmp=$(mktemp -d)
  if [[ -z "$1" ]]; then
    croak 3  'json2cluster requires an argument'
  fi
  this_json=$1

  if [[ -e $KUBASH_DIR/clusters/$KUBASH_CLUSTER_NAME ]]; then
    horizontal_rule
    echo "The cluster directory already exists! $KUBASH_DIR/clusters/$KUBASH_CLUSTER_NAME"
    horizontal_rule
    exit 1
  fi

  # csv_version
  # should be a string not an int!
  jq -r '.csv_version | "\(.)" ' \
    $this_json > $json2cluster_tmp/csv_version
  # kubernetes_version
  # should be a string not an int!
  jq -r '.kubernetes_version | "\(.)" ' \
    $this_json > $json2cluster_tmp/kubernetes_version

  KUBASH_CSV_VER=$(cat $json2cluster_tmp/csv_version)
  squawk 11 "CSV_VER=$KUBASH_CSV_VER"
  if   [[ "$KUBASH_CSV_VER" == '1.0.0' ]]; then
    JQ_INTERPRETER="$JQ_INTERPRETER_1_0_0"
  elif [[ "$KUBASH_CSV_VER" == '2.0.0' ]]; then
    JQ_INTERPRETER="$JQ_INTERPRETER_2_0_0"
  elif [[ "$KUBASH_CSV_VER" == '3.0.0' ]]; then
    JQ_INTERPRETER="$JQ_INTERPRETER_3_0_0"
  elif [[ "$KUBASH_CSV_VER" == '4.0.0' ]]; then
    JQ_INTERPRETER="$JQ_INTERPRETER_4_0_0"
  elif [[ "$KUBASH_CSV_VER" == '5.0.0' ]]; then
    JQ_INTERPRETER="$JQ_INTERPRETER_5_0_0"
  else
    croak 3  "CSV columns cannot be set, csv_ver=$CSV_VER not recognized"
  fi
  jq -r \
    "$JQ_INTERPRETER" \
    "$this_json" >  $json2cluster_tmp/tmp.csv

  set_csv_columns $KUBASH_CSV_VER
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_mac1" == 'null' ]]; then
      K8S_mac1=$(VERBOSITY=0 kubash --verbosity=1 genmac)
    fi
    if [[ "$K8S_network2" != 'null' ]]; then
      if [[ "$K8S_mac2" == 'null' ]]; then
        K8S_mac2=$(VERBOSITY=0 kubash --verbosity=1 genmac)
      fi
    fi
    if [[ "$K8S_network3" != 'null' ]]; then
      if [[ "$K8S_mac3" == 'null' ]]; then
        K8S_mac3=$(VERBOSITY=0 kubash --verbosity=1 genmac)
      fi
    fi
    if   [[ "$KUBASH_CSV_VER" == '1.0.0' ]]; then
      CSV_BUILDER="$K8S_node,$K8S_role,$K8S_cpuCount,$K8S_Memory,$K8S_sshPort,$K8S_network1,$K8S_mac1,$K8S_ip1,$K8S_provisionerHost,$K8S_provisionerUser,$K8S_provisionerPort,$K8S_provisionerBasePath,$K8S_os,$K8S_virt,$K8S_network2,$K8S_mac2,$K8S_ip2,$K8S_network3,$K8S_mac3,$K8S_ip3"
    elif [[ "$KUBASH_CSV_VER" == '2.0.0' ]]; then
      CSV_BUILDER="$K8S_node,$K8S_role,$K8S_cpuCount,$K8S_Memory,$K8S_sshPort,$K8S_network1,$K8S_mac1,$K8S_ip1,$K8S_routingprefix1,$K8S_subnetmask1,$K8S_broadcast1,$K8S_gateway1,$K8S_provisionerHost,$K8S_provisionerUser,$K8S_provisionerPort,$K8S_provisionerBasePath,$K8S_os,$K8S_virt,$K8S_network2,$K8S_mac2,$K8S_ip2,$K8S_routingprefix2,$K8S_subnetmask2,$K8S_broadcast2,$K8S_gateway2,$K8S_network3,$K8S_mac3,$K8S_ip3,$K8S_routingprefix3,$K8S_subnetmask3,$K8S_broadcast3,$K8S_gateway3"
    elif [[ "$KUBASH_CSV_VER" == '3.0.0' ]]; then
      CSV_BUILDER="$K8S_node,$K8S_role,$K8S_cpuCount,$K8S_Memory,$K8S_sshPort,$K8S_network1,$K8S_mac1,$K8S_ip1,$K8S_routingprefix1,$K8S_subnetmask1,$K8S_broadcast1,$K8S_gateway1,$K8S_provisionerHost,$K8S_provisionerUser,$K8S_provisionerPort,$K8S_provisionerBasePath,$K8S_os,$K8S_virt,$K8S_network2,$K8S_mac2,$K8S_ip2,$K8S_routingprefix2,$K8S_subnetmask2,$K8S_broadcast2,$K8S_gateway2,$K8S_network3,$K8S_mac3,$K8S_ip3,$K8S_routingprefix3,$K8S_subnetmask3,$K8S_broadcast3,$K8S_gateway3,$K8S_iscsitarget,$K8S_iscsichapusername,$K8S_iscsichappassword,$K8S_iscsihost"
    elif [[ "$KUBASH_CSV_VER" == '4.0.0' ]]; then
      CSV_BUILDER="$K8S_node,$K8S_role,$K8S_cpuCount,$K8S_Memory,$K8S_sshPort,$K8S_network1,$K8S_mac1,$K8S_ip1,$K8S_routingprefix1,$K8S_subnetmask1,$K8S_broadcast1,$K8S_gateway1,$K8S_provisionerHost,$K8S_provisionerUser,$K8S_provisionerPort,$K8S_provisionerBasePath,$K8S_os,$K8S_virt,$K8S_network2,$K8S_mac2,$K8S_ip2,$K8S_routingprefix2,$K8S_subnetmask2,$K8S_broadcast2,$K8S_gateway2,$K8S_network3,$K8S_mac3,$K8S_ip3,$K8S_routingprefix3,$K8S_subnetmask3,$K8S_broadcast3,$K8S_gateway3,$K8S_iscsitarget,$K8S_iscsichapusername,$K8S_iscsichappassword,$K8S_iscsihost,$K8S_storagePath,$K8S_storageType,$K8S_storageSize"
    elif [[ "$KUBASH_CSV_VER" == '5.0.0' ]]; then
      CSV_BUILDER="$K8S_node,$K8S_role,$K8S_cpuCount,$K8S_Memory,$K8S_sshPort,$K8S_network1,$K8S_mac1,$K8S_ip1,$K8S_routingprefix1,$K8S_subnetmask1,$K8S_broadcast1,$K8S_gateway1,$K8S_provisionerHost,$K8S_provisionerUser,$K8S_provisionerPort,$K8S_provisionerBasePath,$K8S_os,$K8S_kvm_os_variant,$K8S_virt,$K8S_network2,$K8S_mac2,$K8S_ip2,$K8S_routingprefix2,$K8S_subnetmask2,$K8S_broadcast2,$K8S_gateway2,$K8S_network3,$K8S_mac3,$K8S_ip3,$K8S_routingprefix3,$K8S_subnetmask3,$K8S_broadcast3,$K8S_gateway3,$K8S_iscsitarget,$K8S_iscsichapusername,$K8S_iscsichappassword,$K8S_iscsihost,$K8S_storagePath,$K8S_storageType,$K8S_storageSize,$K8S_storageTarget,$K8S_storageMountPath,$K8S_storageUUID"
    else
      croak 3  "CSV columns cannot be set, csv_ver=$CSV_VER not recognized"
    fi
    squawk 6 $CSV_BUILDER
    echo $CSV_BUILDER \
      >>  $json2cluster_tmp/provision.csv
  done < "$json2cluster_tmp/tmp.csv"

  rm $json2cluster_tmp/tmp.csv
  squawk 5 "$(cat $json2cluster_tmp/provision.csv)"

  # ca-data.yaml
#### BEGIN --> Indentation break warning <-- BEGIN
  jq -r \
    '.ca[] | "CERT_COMMON_NAME: \(.CERT_COMMON_NAME)
CERT_COUNTRY: \(.CERT_COUNTRY)
CERT_LOCALITY: \(.CERT_LOCALITY)
CERT_ORGANISATION: \(.CERT_ORGANISATION)
CERT_STATE: \(.CERT_STATE)
CERT_ORG_UNIT: \(.CERT_ORG_UNIT)"' \
    $this_json >  $json2cluster_tmp/ca-data.yaml
#### END --> Indentation break warning <-- END
  squawk 5 "$(cat $json2cluster_tmp/ca-data.yaml)"

  # net_set
  jq -r '.net_set | "\(.)" ' \
    $this_json >  $json2cluster_tmp/net_set
  squawk 7 "$(cat $json2cluster_tmp/net_set)"

  # users.csv
  jq -r '.users | to_entries[] | "\(.key),\(.value.role)"' \
    $this_json >  $json2cluster_tmp/users.csv


  $CP_CMD $KUBASH_DIR/templates/ca-csr.json $json2cluster_tmp/
  $CP_CMD $KUBASH_DIR/templates/ca-config.json $json2cluster_tmp/
  $CP_CMD $KUBASH_DIR/templates/client.json $json2cluster_tmp/

  $MV_CMD $json2cluster_tmp $KUBASH_DIR/clusters/$KUBASH_CLUSTER_NAME
}

write_kubeadmcfg_yaml () {
  squawk 3 " write kubeadmcfg.yaml files"
  do_etcd_tmp_para=$(mktemp -d --suffix='.para.tmp' 2>/dev/null || mktemp -d -t '.para.tmp')
  touch $do_etcd_tmp_para/hopper
  if [[ -z "$kubash_hosts_csv_slurped" ]]; then
    hosts_csv_slurp
  fi

  countprimarymaster=0
  countprimaryetcd=0
  countmaster=1
  countetcd=1
  set_csv_columns
  set_ip_files
  my_master_ip=$( cat $KUBASH_CLUSTER_DIR/kube_primary)
  my_master_user=$( cat $KUBASH_CLUSTER_DIR/kube_primary_user)
  my_master_port=$( cat $KUBASH_CLUSTER_DIR/kube_primary_port)
  # create  config files

  # create tmpdirs for configs
  while IFS="," read -r $csv_columns
  do
        if [[ -e $KUBASH_CLUSTER_DIR/kube_primary_etcd ]]; then
          my_primary_etcd_port=$(cat $KUBASH_CLUSTER_DIR/kube_primary_etcd_port)
          my_primary_etcd_user=$(cat  $KUBASH_CLUSTER_DIR/kube_primary_etcd_user)
          my_primary_etcd_ip=$(cat $KUBASH_CLUSTER_DIR/kube_primary_etcd)
          command2run="mkdir -p /tmp/${K8S_ip1}"
          sudo_command $my_primary_etcd_port $my_primary_etcd_user $my_primary_etcd_ip "$command2run"
        elif [[ -e $KUBASH_CLUSTER_DIR/kube_primary ]]; then
          command2run="mkdir -p /tmp/${K8S_ip1}"
          sudo_command $my_master_port $my_master_user $my_master_ip "$command2run"
        else
          croak 3  'no master found'
        fi
  done <<< "$kubash_hosts_csv_slurped"
  countzero=0
  touch $do_etcd_tmp_para/endpoints.line
  touch $do_etcd_tmp_para/etcd.line
  #echo 'etcd:' > $do_etcd_tmp_para/etcd.line

  # servercertSANS
  echo "${TAB_2}serverCertSANS:" >> $do_etcd_tmp_para/servercertsans.line
  echo "${TAB_2}- '127.0.0.1'" >> $do_etcd_tmp_para/servercertsans.line
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' ]]; then
      echo "${TAB_2}- '$K8S_ip1'" >> $do_etcd_tmp_para/servercertsans.line
    fi
  done <<< "$kubash_hosts_csv_slurped"
  # peercertSANS
  echo "${TAB_2}peerCertSANS:" >> $do_etcd_tmp_para/peercertsans.line
  echo "${TAB_2}- '127.0.0.1'" >> $do_etcd_tmp_para/peercertsans.line
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' ]]; then
      echo "${TAB_2}- '$K8S_ip1'" >> $do_etcd_tmp_para/peercertsans.line
    fi
  done <<< "$kubash_hosts_csv_slurped"

  echo "${TAB_2}extraArgs:" > $do_etcd_tmp_para/extraargs.head
  echo -n "${TAB_3}initial-cluster: " > $do_etcd_tmp_para/initial-cluster.head
  count_etcd=0
  countetcdnodes=0
  while IFS="," read -r $csv_columns
  do
    if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' ]]; then
        if [[ $countetcdnodes -gt 0 ]]; then
          printf ',' >> $do_etcd_tmp_para/initial-cluster.line
        fi
        printf "${K8S_node}=https://${K8S_ip1}:2380" >> $do_etcd_tmp_para/initial-cluster.line
        ((++countetcdnodes))
      fi
    else
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'primary_etcd' ]]; then
        if [[ $countetcdnodes -gt 0 ]]; then
          printf ',' >> $do_etcd_tmp_para/initial-cluster.line
        fi
        printf "${K8S_node}=https://${K8S_ip1}:2380" >> $do_etcd_tmp_para/initial-cluster.line
        ((++countetcdnodes))
      fi
    fi
    ((++count_etcd))
  done <<< "$kubash_hosts_csv_slurped"
  printf " \n" >> $do_etcd_tmp_para/initial-cluster.line
  echo "${TAB_1}external:" >> $do_etcd_tmp_para/external-endpoints.line
  echo "${TAB_2}endpoints:" >> $do_etcd_tmp_para/external-endpoints.line
  while IFS="," read -r $csv_columns
  do
    if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' ]]; then
        echo "${TAB_2}- https://${K8S_ip1}:2379" >> $do_etcd_tmp_para/external-endpoints.line
      fi
    else
      if [[ "$K8S_role" == 'etcd' ]]; then
        echo "${TAB_2}- https://${K8S_ip1}:2379" >> $do_etcd_tmp_para/external-endpoints.line
      fi
    fi
  done <<< "$kubash_hosts_csv_slurped"
  echo "${TAB_2}caFile: /etc/kubernetes/pki/etcd/ca.crt"                 >> $do_etcd_tmp_para/external-endpoints.line
  echo "${TAB_2}certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt" >> $do_etcd_tmp_para/external-endpoints.line
  echo "${TAB_2}keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key"  >> $do_etcd_tmp_para/external-endpoints.line

  while IFS="," read -r $csv_columns
  do
    if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' ]]; then
        echo "${TAB_1}local:" > $do_etcd_tmp_para/${K8S_node}etcd.line
        #echo "${TAB_2}serverCertSANS:" >> $do_etcd_tmp_para/${K8S_node}etcd.line
        #echo "${TAB_2}- '$K8S_ip1'"    >> $do_etcd_tmp_para/${K8S_node}etcd.line
        #echo "${TAB_2}peerCertSANS:"   >> $do_etcd_tmp_para/${K8S_node}etcd.line
        #echo "${TAB_2}- '$K8S_ip1'"    >> $do_etcd_tmp_para/${K8S_node}etcd.line
        #printf " \n" >> $do_etcd_tmp_para/${K8S_node}extraargs.line
        echo "${TAB_3}initial-cluster-state: new" >> $do_etcd_tmp_para/${K8S_node}extraargs.line
        echo "${TAB_3}name: $K8S_node"            >> $do_etcd_tmp_para/${K8S_node}extraargs.line
        echo "${TAB_3}listen-peer-urls: https://${K8S_ip1}:2380"    >> $do_etcd_tmp_para/${K8S_node}extraargs.line
      fi
    else
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'primary_etcd' ]]; then
        echo "${TAB_1}local:" > $do_etcd_tmp_para/${K8S_node}etcd.line
        #echo "${TAB_2}serverCertSANS:" >> $do_etcd_tmp_para/${K8S_node}etcd.line
        #echo "${TAB_2}- '$K8S_ip1'"    >> $do_etcd_tmp_para/${K8S_node}etcd.line
        #echo "${TAB_2}peerCertSANS:"   >> $do_etcd_tmp_para/${K8S_node}etcd.line
        #echo "${TAB_2}- '$K8S_ip1'"    >> $do_etcd_tmp_para/${K8S_node}etcd.line
        #printf " \n" >> $do_etcd_tmp_para/${K8S_node}extraargs.line
        echo "${TAB_3}initial-cluster-state: new" >> $do_etcd_tmp_para/${K8S_node}extraargs.line
        echo "${TAB_3}name: $K8S_node"       >> $do_etcd_tmp_para/${K8S_node}extraargs.line
        echo "${TAB_3}listen-peer-urls: https://${K8S_ip1}:2380"    >> $do_etcd_tmp_para/${K8S_node}extraargs.line
      fi
    fi
  done <<< "$kubash_hosts_csv_slurped"

  while IFS="," read -r $csv_columns
  do
    if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' ]]; then
        echo -n "${TAB_3}listen-client-urls: " >> $do_etcd_tmp_para/${K8S_node}extraargs.line
        echo "https://${K8S_ip1}:2379"     >> $do_etcd_tmp_para/${K8S_node}extraargs.line
      fi
    else
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'primary_etcd' ]]; then
        echo -n "${TAB_3}listen-client-urls: " >> $do_etcd_tmp_para/${K8S_node}extraargs.line
        echo "https://${K8S_ip1}:2379"     >> $do_etcd_tmp_para/${K8S_node}extraargs.line
      fi
    fi
  done <<< "$kubash_hosts_csv_slurped"

  while IFS="," read -r $csv_columns
  do
    if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' ]]; then
        echo -n "${TAB_3}advertise-client-urls: " >> $do_etcd_tmp_para/${K8S_node}extraargs.line
        echo  "https://${K8S_ip1}:2379" >> $do_etcd_tmp_para/${K8S_node}extraargs.line
      fi
    else
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'primary_etcd' ]]; then
        echo -n "${TAB_3}advertise-client-urls: " >> $do_etcd_tmp_para/${K8S_node}extraargs.line
        echo  "https://${K8S_ip1}:2379" >> $do_etcd_tmp_para/${K8S_node}extraargs.line
      fi
    fi
  done <<< "$kubash_hosts_csv_slurped"

  while IFS="," read -r $csv_columns
  do
    if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' ]]; then
        echo -n "${TAB_3}initial-advertise-peer-urls: " >> $do_etcd_tmp_para/${K8S_node}extraargs.line
        echo  "https://${K8S_ip1}:2380"             >> $do_etcd_tmp_para/${K8S_node}extraargs.line
      fi
    else
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'primary_etcd' ]]; then
        echo -n "${TAB_3}initial-advertise-peer-urls: " >> $do_etcd_tmp_para/${K8S_node}extraargs.line
        echo  "https://${K8S_ip1}:2380"             >> $do_etcd_tmp_para/${K8S_node}extraargs.line
      fi
    fi
  done <<< "$kubash_hosts_csv_slurped"

  # deprecated these are no longer used in the current kubeadm
  #echo '  caFile: /etc/kubernetes/pki/etcd/ca.pem' >> $do_etcd_tmp_para/etcdcerts.line
  #echo '  certFile: /etc/kubernetes/pki/etcd/client.pem' >> $do_etcd_tmp_para/etcdcerts.line
  #echo '  keyFile: /etc/kubernetes/pki/etcd/client-key.pem' >> $do_etcd_tmp_para/etcdcerts.line

  squawk 19 "check number of etcd nodes"
  if [[ "$countetcdnodes" -lt "3" ]]; then
    croak 3  "not enough etcd nodes, [$countetcdnodes]"
  else
    if [[ "$((countetcdnodes%2))" -eq 0 ]]; then
      croak 3  "number of etcd nodes, [$countetcdnodes] is even which is not supported"
    fi
  fi

  if [[ -e $KUBASH_CLUSTER_DIR/kube_primary_etcd ]]; then
    my_master_ip=$(cat $KUBASH_CLUSTER_DIR/kube_primary_etcd)
    my_master_user=$(cat  $KUBASH_CLUSTER_DIR/kube_primary_etcd_user)
    my_master_port=$(cat $KUBASH_CLUSTER_DIR/kube_primary_etcd_port)
  elif [[ -e $KUBASH_CLUSTER_DIR/kube_primary ]]; then
    my_master_ip=$( cat $KUBASH_CLUSTER_DIR/kube_primary)
    my_master_user=$( cat $KUBASH_CLUSTER_DIR/kube_primary_user)
    my_master_port=$( cat $KUBASH_CLUSTER_DIR/kube_primary_port)
  else
    croak 3  'no master found'
  fi
  # create  config files
  while IFS="," read -r $csv_columns
  do
    get_major_minor_kube_version $K8S_user $K8S_ip1  $K8S_node $K8S_sshPort
    if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' || "$K8S_role" == 'primary_etcd' ]]; then
        cat $do_etcd_tmp_para/endpoints.line \
        $do_etcd_tmp_para/${K8S_node}etcd.line \
        $do_etcd_tmp_para/servercertsans.line \
        $do_etcd_tmp_para/peercertsans.line \
        $do_etcd_tmp_para/extraargs.head \
        $do_etcd_tmp_para/initial-cluster.head \
        $do_etcd_tmp_para/initial-cluster.line \
        $do_etcd_tmp_para/${K8S_node}extraargs.line \
        > $KUBASH_CLUSTER_DIR/${K8S_node}endpoints.line

        if [[ $KUBE_MAJOR_VER -eq 1 ]]; then
          squawk 20 'Major Version 1'
          if [[ $KUBE_MINOR_VER -lt 9 ]]; then
            croak 3  "$KUBE_MINOR_VER is too old may not ever be supported"
          elif [[ $KUBE_MINOR_VER -eq 11 ]]; then
            kubeadmin_config_tmp=$(mktemp)
            my_master_ip=$( cat $KUBASH_CLUSTER_DIR/kube_primary) \
            KUBERNETES_VERSION=$( cat $KUBASH_CLUSTER_DIR/kubernetes_version) \
            load_balancer_ip=$( cat $KUBASH_CLUSTER_DIR/kube_master1) \
            my_KUBE_CIDR=$my_KUBE_CIDR \
            ENDPOINTS_LINES=$( cat $KUBASH_CLUSTER_DIR/${K8S_node}endpoints.line ) \
            envsubst  < $KUBASH_DIR/templates/kubeadm-config-1.11.yaml \
              > $do_etcd_tmp_para/${K8S_node}kubeadmcfg.yaml
          elif [[ $KUBE_MINOR_VER -eq 12 ]]; then
            kubeadmin_config_tmp=$(mktemp)
            my_master_ip=$( cat $KUBASH_CLUSTER_DIR/kube_primary) \
            KUBERNETES_VERSION=$( cat $KUBASH_CLUSTER_DIR/kubernetes_version) \
            load_balancer_ip=$( cat $KUBASH_CLUSTER_DIR/kube_master1) \
            my_KUBE_CIDR=$my_KUBE_CIDR \
            ENDPOINTS_LINES=$( cat $KUBASH_CLUSTER_DIR/${K8S_node}endpoints.line ) \
            envsubst  < $KUBASH_DIR/templates/kubeadm-config-1.12.yaml \
              > $do_etcd_tmp_para/${K8S_node}kubeadmcfg.yaml
          else
            squawk 10 "$KUBE_MAJOR_VER.$KUBE_MINOR_VER supported"
            kubeadmin_config_tmp=$(mktemp)
            my_master_ip=$my_master_ip \
            KUBERNETES_VERSION=$( cat $KUBASH_CLUSTER_DIR/kubernetes_version) \
            load_balancer_ip=$( cat $KUBASH_CLUSTER_DIR/kube_master1) \
            my_KUBE_CIDR=$my_KUBE_CIDR \
            ENDPOINTS_LINES=$( cat $KUBASH_CLUSTER_DIR/${K8S_node}endpoints.line ) \
            envsubst  < $KUBASH_DIR/templates/kubeadm-config-${KUBE_MAJOR_VER}.${KUBE_MINOR_VER}.yaml \
              > $do_etcd_tmp_para/${K8S_node}kubeadmcfg.yaml
          fi
        elif [[ $MAJOR_VER -eq 0 ]]; then
          croak 3 'Major Version 0 unsupported'
        else
          croak 3 'Major Version Unknown'
        fi

        # now for the external
        cat $do_etcd_tmp_para/endpoints.line \
        $do_etcd_tmp_para/external-endpoints.line \
        > $do_etcd_tmp_para/${K8S_node}endpoints.line

        if [[ $KUBE_MAJOR_VER -eq 1 ]]; then
          squawk 20 'Major Version 1'
          if [[ $KUBE_MINOR_VER -lt 9 ]]; then
            croak 3  "$KUBE_MAJOR_VER.$KUBE_MINOR_VER is too old may not ever be supported"
          elif [[ $KUBE_MINOR_VER -gt 18 ]]; then
            croak 3  "$KUBE_MAJOR_VER.$KUBE_MINOR_VER is too new and is not supported"
          elif [[ $KUBE_MINOR_VER -eq 11 ]]; then
            kubeadmin_config_tmp=$(mktemp)
            my_master_ip=$( cat $KUBASH_CLUSTER_DIR/kube_primary) \
            KUBERNETES_VERSION=$( cat $KUBASH_CLUSTER_DIR/kubernetes_version) \
            load_balancer_ip=$( cat $KUBASH_CLUSTER_DIR/kube_master1) \
            my_KUBE_CIDR=$my_KUBE_CIDR \
            ENDPOINTS_LINES=$( cat $do_etcd_tmp_para/${K8S_node}endpoints.line) \
            envsubst  < $KUBASH_DIR/templates/kubeadm-config-external-1.11.yaml \
              > $do_etcd_tmp_para/${K8S_node}-external-kubeadmcfg.yaml
          elif [[ $KUBE_MINOR_VER -eq 12 ]]; then
            kubeadmin_config_tmp=$(mktemp)
            my_master_ip=$( cat $KUBASH_CLUSTER_DIR/kube_primary) \
            KUBERNETES_VERSION=$( cat $KUBASH_CLUSTER_DIR/kubernetes_version) \
            load_balancer_ip=$( cat $KUBASH_CLUSTER_DIR/kube_master1) \
            my_KUBE_CIDR=$my_KUBE_CIDR \
            ENDPOINTS_LINES=$( cat $do_etcd_tmp_para/${K8S_node}endpoints.line) \
            envsubst  < $KUBASH_DIR/templates/kubeadm-config-external-1.12.yaml \
              > $do_etcd_tmp_para/${K8S_node}-external-kubeadmcfg.yaml
          elif [[ $KUBE_MINOR_VER -gt 15 ]]; then
            kubeadmin_config_tmp=$(mktemp)
            my_master_ip=$( cat $KUBASH_CLUSTER_DIR/kube_primary) \
            KUBERNETES_VERSION=$( cat $KUBASH_CLUSTER_DIR/kubernetes_version) \
            load_balancer_ip=$( cat $KUBASH_CLUSTER_DIR/kube_master1) \
            my_KUBE_CIDR=$my_KUBE_CIDR \
            ENDPOINTS_LINES=$( cat $do_etcd_tmp_para/${K8S_node}endpoints.line) \
            envsubst  < $KUBASH_DIR/templates/kubeadm-config-external-1.16.yaml \
              > $do_etcd_tmp_para/${K8S_node}-external-kubeadmcfg.yaml
          fi
        elif [[ $MAJOR_VER -eq 0 ]]; then
          croak 3 'Major Version 0 unsupported'
        else
          croak 3 'Major Version Unknown'
        fi

        #squawk 25 "scp -P $K8S_sshPort $do_etcd_tmp_para/${K8S_node}kubeadmcfg.yaml $K8S_SU_USER@$K8S_ip1:/tmp/kubeadmcfg.yaml"
        #scp -P $K8S_sshPort $do_etcd_tmp_para/${K8S_node}kubeadmcfg.yaml $K8S_SU_USER@$K8S_ip1:/tmp/kubeadmcfg.yaml
        command2run="mkdir -p /tmp/${K8S_ip1}"
        sudo_command $my_master_port $my_master_user $my_master_ip "$command2run"
        squawk 25 "scp -P $my_master_port $do_etcd_tmp_para/${K8S_node}kubeadmcfg.yaml $my_master_user@$my_master_ip:/tmp/${K8S_ip1}/kubeadmcfg.yaml"
        scp -P $my_master_port $do_etcd_tmp_para/${K8S_node}kubeadmcfg.yaml $my_master_user@$my_master_ip:/tmp/${K8S_ip1}/kubeadmcfg.yaml
        scp -P $my_master_port $do_etcd_tmp_para/${K8S_node}-external-kubeadmcfg.yaml $my_master_user@$my_master_ip:/tmp/${K8S_ip1}/kubeadmcfg-external.yaml
        squawk 25 "scp -P $K8S_sshPort $do_etcd_tmp_para/${K8S_node}kubeadmcfg.yaml $K8S_user@${K8S_ip1}:/etc/kubernetes/kubeadmcfg.yaml"
        scp -P $K8S_sshPort $do_etcd_tmp_para/${K8S_node}kubeadmcfg.yaml $K8S_user@${K8S_ip1}:/etc/kubernetes/kubeadmcfg.yaml
        scp -P $K8S_sshPort $do_etcd_tmp_para/${K8S_node}-external-kubeadmcfg.yaml $K8S_user@${K8S_ip1}:/etc/kubernetes/kubeadmcfg-external.yaml
        squawk 73 'etcd prep_20'
        prep_20-etcd-service-manager $K8S_user ${K8S_ip1} ${K8S_node} $K8S_sshPort
        squawk 78 'end etcd prep_20'
      fi
    else
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'primary_etcd' ]]; then
        cat $do_etcd_tmp_para/endpoints.line \
        $do_etcd_tmp_para/${K8S_node}etcd.line \
        $do_etcd_tmp_para/servercertsans.line \
        $do_etcd_tmp_para/peercertsans.line \
        $do_etcd_tmp_para/extraargs.head \
        $do_etcd_tmp_para/initial-cluster.head \
        $do_etcd_tmp_para/initial-cluster.line \
        $do_etcd_tmp_para/${K8S_node}extraargs.line \
        > $KUBASH_CLUSTER_DIR/${K8S_node}endpoints.line

        if [[ $KUBE_MAJOR_VER -eq 1 ]]; then
          squawk 20 'Major Version 1'
          if [[ $KUBE_MINOR_VER -lt 9 ]]; then
            croak 3  "$KUBE_MINOR_VER is too old may not ever be supported"
          elif [[ $KUBE_MINOR_VER -eq 11 ]]; then
            kubeadmin_config_tmp=$(mktemp)
            my_master_ip=$( cat $KUBASH_CLUSTER_DIR/kube_primary) \
            KUBERNETES_VERSION=$( cat $KUBASH_CLUSTER_DIR/kubernetes_version) \
            load_balancer_ip=$( cat $KUBASH_CLUSTER_DIR/kube_master1) \
            my_KUBE_CIDR=$my_KUBE_CIDR \
            ENDPOINTS_LINES=$( cat $KUBASH_CLUSTER_DIR/${K8S_node}endpoints.line ) \
            envsubst  < $KUBASH_DIR/templates/kubeadm-config-1.11.yaml \
              > $do_etcd_tmp_para/${K8S_node}kubeadmcfg.yaml
          elif [[ $KUBE_MINOR_VER -eq 12 ]]; then
            kubeadmin_config_tmp=$(mktemp)
            my_master_ip=$( cat $KUBASH_CLUSTER_DIR/kube_primary) \
            KUBERNETES_VERSION=$( cat $KUBASH_CLUSTER_DIR/kubernetes_version) \
            load_balancer_ip=$( cat $KUBASH_CLUSTER_DIR/kube_master1) \
            my_KUBE_CIDR=$my_KUBE_CIDR \
            ENDPOINTS_LINES=$( cat $KUBASH_CLUSTER_DIR/${K8S_node}endpoints.line ) \
            envsubst  < $KUBASH_DIR/templates/kubeadm-config-1.12.yaml \
              > $do_etcd_tmp_para/${K8S_node}kubeadmcfg.yaml
          else
            squawk 10 "$KUBE_MAJOR_VER.$KUBE_MINOR_VER supported"
            kubeadmin_config_tmp=$(mktemp)
            my_master_ip=$my_master_ip \
            KUBERNETES_VERSION=$( cat $KUBASH_CLUSTER_DIR/kubernetes_version) \
            load_balancer_ip=$( cat $KUBASH_CLUSTER_DIR/kube_master1) \
            my_KUBE_CIDR=$my_KUBE_CIDR \
            ENDPOINTS_LINES=$( cat $KUBASH_CLUSTER_DIR/${K8S_node}endpoints.line ) \
            envsubst  < $KUBASH_DIR/templates/kubeadm-config-${KUBE_MAJOR_VER}.${KUBE_MINOR_VER}.yaml \
              > $do_etcd_tmp_para/${K8S_node}kubeadmcfg.yaml
          fi
        elif [[ $MAJOR_VER -eq 0 ]]; then
          croak 3 'Major Version 0 unsupported'
        else
          croak 3 'Major Version Unknown'
        fi

        command2run="mkdir -p /tmp/${K8S_ip1}"
        sudo_command $my_master_port $my_master_user $my_master_ip "$command2run"
        squawk 25 "scp -P $my_master_port $do_etcd_tmp_para/${K8S_node}kubeadmcfg.yaml $my_master_user@$my_master_ip:/tmp/${K8S_ip1}/kubeadmcfg.yaml"
        scp -P $my_master_port $do_etcd_tmp_para/${K8S_node}kubeadmcfg.yaml $my_master_user@$my_master_ip:/tmp/${K8S_ip1}/kubeadmcfg.yaml
        squawk 25 "scp -P $K8S_sshPort $do_etcd_tmp_para/${K8S_node}kubeadmcfg.yaml $K8S_user@${K8S_ip1}:/etc/kubernetes/kubeadmcfg.yaml"
        scp -P $K8S_sshPort $do_etcd_tmp_para/${K8S_node}kubeadmcfg.yaml $K8S_user@${K8S_ip1}:/etc/kubernetes/kubeadmcfg.yaml
        squawk 74 'etcd prep_20'
        prep_20-etcd-service-manager $K8S_user ${K8S_ip1} ${K8S_node} $K8S_sshPort
        squawk 74 'end etcd prep_20'

      elif [[ "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' ]]; then
        # now for the external
        cat $do_etcd_tmp_para/endpoints.line \
        $do_etcd_tmp_para/external-endpoints.line \
        > $do_etcd_tmp_para/${K8S_node}endpoints.line


        if [[ $KUBE_MAJOR_VER -eq 1 ]]; then
          squawk 20 'Major Version 1'
          if [[ $KUBE_MINOR_VER -lt 9 ]]; then
            croak 3  "$KUBE_MAJOR_VER.$KUBE_MINOR_VER is too old may not ever be supported"
          elif [[ $KUBE_MINOR_VER -eq 11 ]]; then
            kubeadmin_config_tmp=$(mktemp)
            my_master_ip=$( cat $KUBASH_CLUSTER_DIR/kube_primary) \
            KUBERNETES_VERSION=$( cat $KUBASH_CLUSTER_DIR/kubernetes_version) \
            load_balancer_ip=$( cat $KUBASH_CLUSTER_DIR/kube_master1) \
            my_KUBE_CIDR=$my_KUBE_CIDR \
            ENDPOINTS_LINES=$( cat $do_etcd_tmp_para/${K8S_node}endpoints.line) \
            envsubst  < $KUBASH_DIR/templates/kubeadm-config-external-1.11.yaml \
              > $do_etcd_tmp_para/${K8S_node}-external-kubeadmcfg.yaml
          elif [[ $KUBE_MINOR_VER -eq 12 ]]; then
            kubeadmin_config_tmp=$(mktemp)
            my_master_ip=$( cat $KUBASH_CLUSTER_DIR/kube_primary) \
            KUBERNETES_VERSION=$( cat $KUBASH_CLUSTER_DIR/kubernetes_version) \
            load_balancer_ip=$( cat $KUBASH_CLUSTER_DIR/kube_master1) \
            my_KUBE_CIDR=$my_KUBE_CIDR \
            ENDPOINTS_LINES=$( cat $do_etcd_tmp_para/${K8S_node}endpoints.line) \
            envsubst  < $KUBASH_DIR/templates/kubeadm-config-external-1.12.yaml \
              > $do_etcd_tmp_para/${K8S_node}-external-kubeadmcfg.yaml
          else
            squawk 10 "$KUBE_MAJOR_VER.$KUBE_MINOR_VER supported"
            kubeadmin_config_tmp=$(mktemp)
            my_master_ip=$my_master_ip \
            KUBERNETES_VERSION=$( cat $KUBASH_CLUSTER_DIR/kubernetes_version) \
            load_balancer_ip=$( cat $KUBASH_CLUSTER_DIR/kube_master1) \
            my_KUBE_CIDR=$my_KUBE_CIDR \
            ENDPOINTS_LINES=$( cat $KUBASH_CLUSTER_DIR/endpoints.line) \
            envsubst  < $KUBASH_DIR/templates/kubeadm-config-external-${KUBE_MAJOR_VER}.${KUBE_MINOR_VER}.yaml \
              > $do_etcd_tmp_para/${K8S_node}-external-kubeadmcfg.yaml
          fi
        elif [[ $MAJOR_VER -eq 0 ]]; then
          croak 3 'Major Version 0 unsupported'
        else
          croak 3 'Major Version Unknown'
        fi
        command2run="mkdir -p /tmp/${K8S_ip1}"
        sudo_command $my_master_port $my_master_user $my_master_ip "$command2run"
        squawk 25 "scp -P $my_master_port $do_etcd_tmp_para/${K8S_node}-external-kubeadmcfg.yaml $my_master_user@$my_master_ip:/tmp/${K8S_ip1}/kubeadmcfg.yaml"
        scp -P $my_master_port $do_etcd_tmp_para/${K8S_node}-external-kubeadmcfg.yaml $my_master_user@$my_master_ip:/tmp/${K8S_ip1}/kubeadmcfg.yaml
        squawk 25 "scp -P $K8S_sshPort $do_etcd_tmp_para/${K8S_node}-external-kubeadmcfg.yaml $K8S_user@${K8S_ip1}:/etc/kubernetes/kubeadmcfg.yaml"
        scp -P $K8S_sshPort $do_etcd_tmp_para/${K8S_node}-external-kubeadmcfg.yaml $K8S_user@${K8S_ip1}:/etc/kubernetes/kubeadmcfg.yaml
        squawk 75 'External master prep_20'
        prep_20-etcd-service-manager $K8S_user ${K8S_ip1} ${K8S_node} $K8S_sshPort
        squawk 75 'End create config loop'
      fi
    fi
  done <<< "$kubash_hosts_csv_slurped"
}
