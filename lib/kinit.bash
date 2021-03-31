#!/usr/bin/env bash

master_join () {
  squawk 1 " master_join $@"
  my_node_name=$1
  my_node_ip=$2
  my_node_user=$3
  my_node_port=$4


  if [[ "$DO_MASTER_JOIN" == "true" ]] ; then
    #finish_pki_for_masters $my_node_user $my_node_ip $my_node_name $my_node_port
    ssh -n -p $my_node_port $my_node_user@$my_node_ip "$PSUEDO hostname;$PSUEDO  uname -a"
    run_join=$(cat $KUBASH_CLUSTER_DIR/join.sh)
    squawk 1 " run join $run_join"
    ssh -n -p $my_node_port $my_node_user@$my_node_ip "$PSEUDO $run_join"
    w8_node $my_node_name
    rolero $my_node_name master
  fi
}

master_init_join () {
  squawk 1 " master_init_join $@"
  my_master_name=$1
  my_master_ip=$2
  my_master_user=$3
  my_master_port=$4
  if [[ -z "$kubash_hosts_csv_slurped" ]]; then
    hosts_csv_slurp
  fi

  #finish_pki_for_masters $my_master_user $my_master_ip $my_master_name $my_master_port

  rm -f $KUBASH_CLUSTER_DIR/ingress.ip1
  rm -f $KUBASH_CLUSTER_DIR/ingress.ip2
  rm -f $KUBASH_CLUSTER_DIR/ingress.ip3
  rm -f $KUBASH_CLUSTER_DIR/primary_master.ip1
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "ingress" ]]; then
      echo "$K8S_ip1" >> $KUBASH_CLUSTER_DIR/ingress.ip1
      echo "$K8S_ip2" >> $KUBASH_CLUSTER_DIR/ingress.ip2
      echo "$K8S_ip3" >> $KUBASH_CLUSTER_DIR/ingress.ip3
    elif [[ "$K8S_role" == "primary_master" ]]; then
      echo "$K8S_ip1" >> $KUBASH_CLUSTER_DIR/primary_master.ip1
    fi
  done <<< "$kubash_hosts_csv_slurped"
  if [[ -e  "$KUBASH_CLUSTER_DIR/ingress.ip2" ]]; then
    K8S_load_balancer_ip=$(head -n1 $KUBASH_CLUSTER_DIR/ingress.ip2)
  elif [[ -e  "$KUBASH_CLUSTER_DIR/ingress.ip3" ]]; then
    K8S_load_balancer_ip=$(head -n1 $KUBASH_CLUSTER_DIR/ingress.ip3)
  elif [[ -e  "$KUBASH_CLUSTER_DIR/ingress.ip1" ]]; then
    K8S_load_balancer_ip=$(head -n1 $KUBASH_CLUSTER_DIR/ingress.ip1)
  elif [[ -e  "$KUBASH_CLUSTER_DIR/primary_master.ip1" ]]; then
    K8S_load_balancer_ip=$(head -n1 $KUBASH_CLUSTER_DIR/primary_master.ip1)
  else
    croak 3  'no load balancer ip'
  fi

  if [[ "DO_KEEPALIVED" == 'true' ]]; then
    #keepalived
    setup_keepalived_tmp=$(mktemp -d)

    MASTER_VIP=$my_master_ip \
    envsubst < $KUBASH_DIR/templates/check_apiserver.sh \
    > $setup_keepalived_tmp/check_apiserver.sh
    copy_in_parallel_to_role master $setup_keepalived_tmp/check_apiserver.sh "/tmp/"
    command2run='sudo  mv /tmp/check_apiserver.sh /etc/keepalived/'
    do_command_in_parallel_on_role "master" "$command2run"

    MASTER_OR_BACKUP=BACKUP \
    PRIORITY=100 \
    INTERFACE_NET=$INTERFACE_NET \ 
    MASTER_VIP=$my_master_ip \
    envsubst < $KUBASH_DIR/templates/keepalived.conf
    > $setup_keepalived_tmp/keepalived.conf
    copy_in_parallel_to_role master $setup_keepalived_tmp/keepalived.conf "/tmp/"
    command2run='sudo  mv /tmp/keepalived.conf /etc/keepalived/'
    do_command_in_parallel_on_role "master" "$command2run"
    # Then let's overwrite that on our primary master
    MASTER_OR_BACKUP=MASTER \
    PRIORITY=101 \
    INTERFACE_NET=$INTERFACE_NET \ 
    MASTER_VIP=$my_master_ip \
    envsubst < $KUBASH_DIR/templates/keepalived.conf
    > $setup_keepalived_tmp/keepalived.conf
    rsync $KUBASH_RSYNC_OPTS "ssh -p $my_master_port" $setup_keepalived_tmp/keepalived.conf $my_master_user@$my_master_ip:/tmp/keepalived.conf
    command2run='sudo  mv /tmp/keepalived.conf /etc/keepalived/'
    ssh -n -p $my_master_port $my_master_user@$my_master_ip "$command2run"

    rm -f $setup_keepalived_tmp/keepalived.conf $setup_keepalived_tmp/check_apiserver.sh
    rmdir $setup_keepalived_tmp
  fi

  squawk 3 " master_init_join $my_master_name $my_master_ip $my_master_user $my_master_port"
  if [[ "$DO_MASTER_JOIN" == "true" ]] ; then
    ssh -n -p $my_master_port $my_master_user@$my_master_ip "$PSEUDO hostname;$PSEUDO  uname -a"
    my_grep='kubeadm join --token'
    squawk 3 'master_init_join kubeadm init'
    command2run='sudo systemctl restart kubelet'
    do_command_in_parallel_on_role "primary_master" "$command2run"
    do_command_in_parallel_on_role "master" "$command2run"
    #ssh -n -p $my_master_port $my_master_user@$my_master_ip "$command2run"
    command2run='sudo systemctl stop kubelet'
    #ssh -n -p $my_master_port $my_master_user@$my_master_ip "$command2run"
    do_command_in_parallel_on_role "primary_master" "$command2run"
    do_command_in_parallel_on_role "master" "$command2run"
    command2run='sudo netstat -ntpl'
    do_command_in_parallel_on_role "master" "$command2run"
    ssh -n -p $my_master_port $my_master_user@$my_master_ip "$command2run"
    GET_JOIN_CMD="kubeadm token create --print-join-command"
    if [[ -e "$KUBASH_CLUSTER_DIR/endpoints.line" ]]; then
      my_KUBE_INIT="PATH=$K8S_SU_PATH $PSEUDO kubeadm init $KUBEADMIN_IGNORE_PREFLIGHT_CHECKS --config=/etc/kubernetes/kubeadmcfg.yaml"
      squawk 5 "$my_KUBE_INIT"
      #run_join=$(ssh -n $my_master_user@$my_master_ip "$my_KUBE_INIT" | tee $TMP/rawresults.k8s | grep -- "$my_grep")
      run_join=$(ssh -n $my_master_user@$my_master_ip "$GET_JOIN_CMD" \
        | grep -P -- "$my_grep" \
      )
      if [[ -z "$run_join" ]]; then
        horizontal_rule
        croak 3  'kubeadm init failed!'
      fi
    else
      my_KUBE_INIT="PATH=$K8S_SU_PATH $PSEUDO kubeadm init $KUBEADMIN_IGNORE_PREFLIGHT_CHECKS --config=/etc/kubernetes/kubeadmcfg.yaml"
      squawk 5 "$my_KUBE_INIT"
      run_join=$(ssh -n $my_master_user@$my_master_ip "$GET_JOIN_CMD")
      if [[ -z "$run_join" ]]; then
        horizontal_rule
        croak 3  'kubeadm init failed!'
      fi
    fi
    squawk 9 "$(cat $TMP/rawresults.k8s)"
    echo $run_join > $KUBASH_CLUSTER_DIR/join.sh
    if [[ "$KUBASH_OIDC_AUTH" == 'true' ]]; then
      command2run='sudo sed -i "/- kube-apiserver/a\    - --oidc-issuer-url=https://accounts.google.com\n    - --oidc-username-claim=email\n    - --oidc-client-id=" /etc/kubernetes/manifests/kube-apiserver.yaml'
      ssh -n -p $my_master_port $my_master_user@$my_master_ip "$command2run"
    fi
    master_grab_kube_config $my_master_name $my_master_ip $my_master_user $my_master_port
    sudo_command $my_master_port $my_master_user $my_master_ip "$command2run"
    w8_kubectl
    rsync $KUBASH_RSYNC_OPTS "ssh -p $my_master_port" $KUBASH_DIR/scripts/grabkubepki $my_master_user@$my_master_ip:/tmp/grabkubepki
    command2run="bash /tmp/grabkubepki"
    sudo_command $this_port $this_user $this_host "$command2run"
    rsync $KUBASH_RSYNC_OPTS "ssh -p $my_master_port" $my_master_user@$my_master_ip:/tmp/kube-pki.tgz $KUBASH_CLUSTER_DIR/
    squawk 5 'and copy it to master and etcd hosts'
    copy_in_parallel_to_role "master" "$KUBASH_CLUSTER_DIR/kube-pki.tgz" "/tmp/"
    if [ "$VERBOSITY" -gt 5 ]; then
      command2run='cd /; tar ztvf /tmp/kube-pki.tgz'
      do_command_in_parallel_on_role "master"        "$command2run"
    fi
    command2run='cd /; tar zxf /tmp/kube-pki.tgz'
    do_command_in_parallel_on_role "master"        "$command2run"
    command2run='rm /tmp/kube-pki.tgz'
    do_command_in_parallel_on_role "master"        "$command2run"
    do_net
  fi
}

master_grab_kube_config () {
  squawk 33 "master_grab_kube_config $@"
  my_master_name=$1
  my_master_ip=$2
  my_master_user=$3
  my_master_port=$4
  squawk 3 " master_grab_kube_config my_master_name=$my_master_name my_master_ip=$my_master_ip my_master_user=$my_master_user my_master_port=$my_master_port"
  squawk 1 ' refresh-kube-config'
  squawk 5 "mkdir -p ~/.kube && sudo cp -av /etc/kubernetes/admin.conf ~/.kube/config && sudo chown -R $my_master_user. ~/.kube"
  ssh -n -p $my_master_port $my_master_user@$my_master_ip "mkdir -p ~/.kube && sudo cp -av /etc/kubernetes/admin.conf ~/.kube/config && sudo chown -R $my_master_user. ~/.kube"

  chkdir $HOME/.kube
  squawk 3 ' grab config'
  rm -f $KUBASH_CLUSTER_CONFIG
  ssh -n -p $my_master_port $my_master_user@$my_master_ip 'cat .kube/config' > $KUBASH_CLUSTER_CONFIG
  sed -i "s/^  name: kubernetes$/  name: $KUBASH_CLUSTER_NAME/" $KUBASH_CLUSTER_CONFIG
  sed -i "s/^    cluster: kubernetes$/    cluster: $KUBASH_CLUSTER_NAME/" $KUBASH_CLUSTER_CONFIG

  sudo chmod 600 $KUBASH_CLUSTER_CONFIG
  sudo chown -R $USER. $KUBASH_CLUSTER_CONFIG
}

node_join () {
  my_node_name=$1
  my_node_ip=$2
  my_node_user=$3
  my_node_port=$4
  squawk 1 " node_join $my_node_name $my_node_ip $my_node_user $my_node_port"
  if [[ "$DO_NODE_JOIN" == "true" ]] ; then
    #result=$(ssh -n -p $my_node_port $my_node_user@$my_node_ip "$PSEUDO hostname;$PSEUDO uname -a")
    result=$(ssh -n -p $my_node_port $my_node_user@$my_node_ip "hostname; uname -a")
    squawk 3 "hostname and uname is $result"
    squawk 3 "Kubeadmn join"
    run_join=$(cat $KUBASH_CLUSTER_DIR/join.sh \
        | grep -P -- "$my_grep" \
    )
    #result=$(ssh -n -p $my_node_port $my_node_user@$my_node_ip "$PSEUDO $run_join --ignore-preflight-errors=IsPrivilegedUser")
    result=$(ssh -n -p $my_node_port $my_node_user@$my_node_ip "$PSEUDO $run_join --ignore-preflight-errors=IsPrivilegedUser")
    squawk 3 "run_join result is $result"
    w8_node $my_node_name
    rolero $my_node_name node
  fi
}

finish_pki_for_masters () {
  squawk 5 "finish_pki_for_masters $@"
  if [[ $# -ne 4 ]]; then
    kubash_interactive
    echo 'Arguments does not equal 4!'
    croak 3  "Arguments: $@"
  fi
  this_user=$1
  this_host=$2
  this_name=$3
  this_port=$4
  command2run='mkdir -p /etc/kubernetes/pki/etcd'
  sudo_command $this_port $this_user $this_host "$command2run"
  squawk 5 'cp the etcd pki files'
  command2run="cp -v /etc/etcd/pki/ca.pem /etc/etcd/pki/client.pem /etc/etcd/pki/client-key.pem /etc/kubernetes/pki/etcd/"
  sudo_command $this_port $this_user $this_host "$command2run"
}

finish_etcd () {
  squawk 5 "finish_etcd $@"
  this_user=$1
  this_host=$2
  this_name=$3
  this_port=$4
  get_major_minor_kube_version $this_user $this_host $this_name $this_port
  if [[ $KUBE_MAJOR_VER == 1 ]]; then
    squawk 20 'Major Version 1'
    if [[ $KUBE_MINOR_VER -lt 12 ]]; then
      finish_etcd_direct_download $this_user $this_host $this_name $this_port
    else
      croak 3  'stubbed not working yet'
      #finish_etcd_kubelet_download $this_user $this_host $this_name $this_port
    fi
  elif [[ $MAJOR_VER == 0 ]]; then
    croak 3 'Major Version 0 unsupported'
  else
    croak 3 'Major Version Unknown'
  fi
}

finish_etcd_kubelet_download () {
  squawk 5 "finish_etcd_kubelet_download $@"
  this_user=$1
  this_host=$2
  this_name=$3
  this_port=$4
}

finish_etcd_direct_download () {
  squawk 5 "finish_etcd_direct_download $@"
  this_user=$1
  this_host=$2
  this_name=$3
  this_port=$4

  command2run="cd /etc/etcd/pki; cfssl print-defaults csr > config.json"
  sudo_command $this_port $this_user $this_host "$command2run"
  command2run="sed -i '0,/CN/{s/example\.net/'$this_name'/}' /etc/etcd/pki/config.json"
  sudo_command $this_port $this_user $this_host "$command2run"
  command2run="sed -i 's/www\.example\.net/'$this_host'/' /etc/etcd/pki/config.json"
  sudo_command $this_port $this_user $this_host "$command2run"
  command2run="sed -i 's/example\.net/'$this_name'/' /etc/etcd/pki/config.json"
  sudo_command $this_port $this_user $this_host "$command2run"
  command2run="cd /etc/etcd/pki; cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=server config.json | cfssljson -bare server"
  sudo_command $this_port $this_user $this_host "$command2run"
  command2run="cd /etc/etcd/pki; cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=peer config.json | cfssljson -bare peer"
  sudo_command $this_port $this_user $this_host "$command2run"
  command2run='chown -R etcd:etcd /etc/etcd/pki'
  sudo_command $this_port $this_user $this_host "$command2run"

  if [[ -e $KUBASH_DIR/tmp/etcd-${ETCD_VERSION}-linux-amd64.tar.gz ]]; then
    squawk 9 'Etcd binary already downloaded'
  else
    cd $KUBASH_DIR/tmp
    wget -c https://github.com/coreos/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz
  fi
  command2run='id -u etcd &>/dev/null || useradd etcd'
  sudo_command $this_port $this_user $this_host "$command2run"
  etcd_extract_tmp=$(mktemp -d)
  sudo tar --strip-components=1 -C $etcd_extract_tmp -xzf $KUBASH_DIR/tmp/etcd-${ETCD_VERSION}-linux-amd64.tar.gz
  rsync $KUBASH_RSYNC_OPTS "ssh -p $this_port" $etcd_extract_tmp/etcd $this_user@$this_host:/tmp/
  rsync $KUBASH_RSYNC_OPTS "ssh -p $this_port" $etcd_extract_tmp/etcdctl $this_user@$this_host:/tmp/
  $PSEUDO rm -Rf $etcd_extract_tmp
  command2run='sudo mv /tmp/etcd /usr/local/bin/'
  do_command $this_port $this_user $this_host "$command2run"
  command2run='sudo mv /tmp/etcdctl /usr/local/bin/'
  do_command $this_port $this_user $this_host "$command2run"
  etctmp=$(mktemp)
  KUBASH_CLUSTER_NAME=$KUBASH_CLUSTER_NAME \
  PEER_NAME=$this_name \
  PRIVATE_IP=$this_host \
  ETCD_INITCLUSER_LINE="$(cat $KUBASH_CLUSTER_DIR/etcd.line)" \
  envsubst < $KUBASH_DIR/templates/etcd.conf.yml \
  > $etctmp
  rsync $KUBASH_RSYNC_OPTS "ssh -p $this_port" $etctmp  $this_user@$this_host:/tmp/etcd.conf.yml
  command2run="mv /tmp/etcd.conf.yml /etc/etcd/etcd.conf.yml"
  sudo_command $this_port $this_user $this_host "$command2run"

  rsync $KUBASH_RSYNC_OPTS "ssh -p $this_port" $KUBASH_DIR/templates/etcd.service  $this_user@$this_host:/tmp/etcd.service
  command2run='mv /tmp/etcd.service /lib/systemd/system/etcd.service'
  sudo_command $this_port $this_user $this_host "$command2run"

  rm $etctmp
  command2run='mkdir -p /etc/etcd; chown -R etcd.etcd /etc/etcd'
  sudo_command $this_port $this_user $this_host "$command2run"
  command2run='mkdir -p /var/lib/etcd; chown -R etcd.etcd /var/lib/etcd'
  sudo_command $this_port $this_user $this_host "$command2run"
  command2run='systemctl daemon-reload'
  sudo_command $this_port $this_user $this_host "$command2run"
}

start_etcd () {

  if [[ -z "$kubash_hosts_csv_slurped" ]]; then
    hosts_csv_slurp
  fi
  # Run kubeadm init on master0
  start_etcd_tmp_para=$(mktemp -d --suffix='.para.tmp' 2>/dev/null)
  touch $start_etcd_tmp_para/hopper
  squawk 3 " start_etcd"

  countzero=0
  touch $start_etcd_tmp_para/endpoints.line
  #echo 'etcd:' >> $start_etcd_tmp_para/endpoints.line
  echo ' external:' >> $start_etcd_tmp_para/endpoints.line
  echo '  endpoints:' >> $start_etcd_tmp_para/endpoints.line
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "etcd" || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' ]]; then
      if [[ "$countzero" -lt "3" ]]; then
  command2run='systemctl start etcd'
  squawk 5 "ssh -n -p $K8S_sshPort $K8S_provisionerUser@$K8S_ip1 'sudo bash -l -c \"$command2run\"'"
  echo "ssh -n -p $K8S_sshPort $K8S_provisionerUser@$K8S_ip1 'sudo bash -l -c \"$command2run\"'" >> $start_etcd_tmp_para/hopper
      fi
    fi
  done <<< "$kubash_hosts_csv_slurped"

  if [[ "$VERBOSITY" -gt "9" ]] ; then
    cat $start_etcd_tmp_para/hopper
  fi
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    $PARALLEL  -j $PARALLEL_JOBS -- < $start_etcd_tmp_para/hopper
  else
    bash $start_etcd_tmp_para/hopper
  fi
  rm -Rf $start_etcd_tmp_para
}

kubeadm_reset () {
  squawk 3 "Kubeadmin reset - warning this command fails (*and can be ignored) for coreOS as kubeadm does not exist yet"
  #command2run="PATH=$K8S_SU_PATH yes y|kubeadm reset"
  command2run="yes y|kubeadm reset"
  # hack if debugging to skip this step
  set +e
  do_command_in_parallel "$command2run"
  set -e
}

prep_init_etcd () {
  squawk 5 "prep_init_etcd args: '$@'"
  prep_init_etcd_user=$1
  prep_init_etcd_host=$2
  prep_init_etcd_name=$3
  prep_init_etcd_port=$4

  get_major_minor_kube_version $prep_init_etcd_user $prep_init_etcd_host $prep_init_etcd_name $prep_init_etcd_port
  if [[ $KUBE_MAJOR_VER -eq 1 ]]; then
    squawk 175 'Kube Major Version 1 for prep init etcd'
    if [[ $KUBE_MINOR_VER -lt 12 ]]; then
      #croak 3  "$KUBE_MAJOR_VER.$KUBE_MINOR_VER less than 12 broken atm prep_init_etcd_kubelet_download $prep_init_etcd_user $prep_init_etcd_host $prep_init_etcd_name $prep_init_etcd_port"
      squawk 175 "$KUBE_MAJOR_VER.$KUBE_MINOR_VER Kube Minor Version less than 12 for prep init etcd"
      prep_init_etcd_classic $prep_init_etcd_user $prep_init_etcd_host $prep_init_etcd_name $prep_init_etcd_port
    else
      squawk 175 "$KUBE_MAJOR_VER.$KUBE_MINOR_VER for prep init etcd"
      squawk 55 "prep_init_etcd_kubelet_download $prep_init_etcd_user $prep_init_etcd_host $prep_init_etcd_name $prep_init_etcd_port"
      prep_init_etcd_kubelet_download $prep_init_etcd_user $prep_init_etcd_host $prep_init_etcd_name $prep_init_etcd_port
      squawk 83 'End pre_init_etcd'
    fi
  elif [[ $MAJOR_VER -eq 0 ]]; then
    croak 3 'Major Version 0 unsupported'
  else
    croak 3 'Major Version Unknown'
  fi
}

prep_init_etcd_kubelet_download  () {
  squawk 5 prep_init_etcd_kubelet_download
  prep_init_etcd_kubelet_download_tmp=$(mktemp -d)
  prep_init_etcd_kubelet_download_user=$1
  prep_init_etcd_kubelet_download_host=$2
  prep_init_etcd_kubelet_download_name=$3
  prep_init_etcd_kubelet_download_port=$4

  squawk 55 "prep_20-etcd-service-manager $prep_init_etcd_kubelet_download_user $prep_init_etcd_kubelet_download_host $prep_init_etcd_kubelet_download_name $prep_init_etcd_kubelet_download_port"
  prep_20-etcd-service-manager $prep_init_etcd_kubelet_download_user $prep_init_etcd_kubelet_download_host $prep_init_etcd_kubelet_download_name $prep_init_etcd_kubelet_download_port
  squawk 76 'end etcd prep_20'

  sleep 3

  command2run='netstat -ntpl'
  sudo_command $prep_init_etcd_kubelet_download_port $prep_init_etcd_kubelet_download_user $prep_init_etcd_kubelet_download_host "$command2run"
  command2run='kubeadm  alpha phase certs etcd-ca'
  sudo_command $prep_init_etcd_kubelet_download_port $prep_init_etcd_kubelet_download_user $prep_init_etcd_kubelet_download_host "$command2run"
  command2run='ls -lh /etc/kubernetes/pki/etcd/ca.crt'
  #sudo_command $prep_init_etcd_kubelet_download_port $prep_init_etcd_kubelet_download_user $prep_init_etcd_kubelet_download_host "$command2run"
  command2run='ls -lh /etc/kubernetes/pki/etcd/ca.key'
  #sudo_command $prep_init_etcd_kubelet_download_port $prep_init_etcd_kubelet_download_user $prep_init_etcd_kubelet_download_host "$command2run"

  squawk 55 "prep_etcd_gen_certs $prep_init_etcd_kubelet_download_port $prep_init_etcd_kubelet_download_user $prep_init_etcd_kubelet_download_host $prep_init_etcd_kubelet_download_port $prep_init_etcd_kubelet_download_user $prep_init_etcd_kubelet_download_host"
  prep_etcd_gen_certs $prep_init_etcd_kubelet_download_port $prep_init_etcd_kubelet_download_user $prep_init_etcd_kubelet_download_host $prep_init_etcd_kubelet_download_port $prep_init_etcd_kubelet_download_user $prep_init_etcd_kubelet_download_host
}

prep_20-etcd-service-manager () {
  if [ $# -ne 4 ]; then
    # Print usage
    echo 'Error! wrong number of arguments'
    echo 'usage:'
    croak 3  "$0 user host name port"
  fi
  squawk 5 prep_init_etcd_kubelet_download
  prep_20_etcd_service_manager_tmp=$(mktemp -d)
  prep_20_etcd_service_manager_user=$1
  prep_20_etcd_service_manager_host=$2
  prep_20_etcd_service_manager_name=$3
  prep_20_etcd_service_manager_port=$4

  prep_20_etcd_service_manager_host=$2 \
  envsubst < \
    $KUBASH_DIR/templates/20-etcd-service-manager.conf \
    > $prep_20_etcd_service_manager_tmp/20-etcd-service-manager.conf
  squawk 55 "rsync -zave ssh -p $prep_20_etcd_service_manager_port $prep_20_etcd_service_manager_tmp/20-etcd-service-manager.conf $prep_20_etcd_service_manager_user@$prep_20_etcd_service_manager_host:/etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf"
  rsync -zave "ssh -p $prep_20_etcd_service_manager_port" $prep_20_etcd_service_manager_tmp/20-etcd-service-manager.conf $prep_20_etcd_service_manager_user@$prep_20_etcd_service_manager_host:/etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
  rm $prep_20_etcd_service_manager_tmp/20-etcd-service-manager.conf
  rmdir $prep_20_etcd_service_manager_tmp
  command2run='systemctl daemon-reload && systemctl restart kubelet'
  squawk 55 "sudo_command $prep_20_etcd_service_manager_port $prep_20_etcd_service_manager_user $prep_20_etcd_service_manager_host $command2run"
  sudo_command $prep_20_etcd_service_manager_port $prep_20_etcd_service_manager_user $prep_20_etcd_service_manager_host "$command2run"
  squawk 99 'End prep_20-etcd-service-manager'
}

prep_etcd_gen_certs () {
  prepetcdgencerts_port=$1
  prepetcdgencerts_user=$2
  prepetcdgencerts_host=$3
  prepetcdgencerts_primary_etcd_master_port=$4
  prepetcdgencerts_primary_etcd_master_user=$5
  prepetcdgencerts_primary_etcd_master=$6
  squawk 55 "prep_etcd_gen_certs port $prepetcdgencerts_port user $prepetcdgencerts_user host $prepetcdgencerts_host on master $prepetcdgencerts_primary_etcd_master_user '@' $prepetcdgencerts_primary_etcd_master : $prepetcdgencerts_primary_etcd_master_port"
  command2run="find /tmp/${prepetcdgencerts_host} -name ca.key -type f -delete -print \
    && find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete -print \
    && kubeadm alpha phase certs etcd-server --config=/tmp/${prepetcdgencerts_host}/kubeadmcfg.yaml \
    && kubeadm alpha phase certs etcd-peer --config=/tmp/${prepetcdgencerts_host}/kubeadmcfg.yaml \
    && kubeadm alpha phase certs etcd-healthcheck-client --config=/tmp/${prepetcdgencerts_host}/kubeadmcfg.yaml \
    && kubeadm alpha phase certs apiserver-etcd-client --config=/tmp/${prepetcdgencerts_host}/kubeadmcfg.yaml \
    && cp -R /etc/kubernetes/pki /tmp/${prepetcdgencerts_host}/"
  sudo_command $prepetcdgencerts_primary_etcd_master_port  $prepetcdgencerts_primary_etcd_master_user  $prepetcdgencerts_primary_etcd_master "$command2run"
  squawk 86 'cleanup non-reusable certificates'
  command2run="find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete -print"
  sudo_command $prepetcdgencerts_primary_etcd_master_port  $prepetcdgencerts_primary_etcd_master_user  $prepetcdgencerts_primary_etcd_master "$command2run"
  if [[ "$prepetcdgencerts_host" == "$prepetcdgencerts_primary_etcd_master" ]]; then
    command2run="rsync -av /tmp/${prepetcdgencerts_host}/* /etc/kubernetes/"
    squawk 25 "$command2run"
    sudo_command $prepetcdgencerts_primary_etcd_master_port  $prepetcdgencerts_primary_etcd_master_user  $prepetcdgencerts_primary_etcd_master "$command2run"
    command2run="chown -R root:root /etc/kubernetes/pki"
    sudo_command $prepetcdgencerts_port $prepetcdgencerts_user $prepetcdgencerts_host "$command2run"
  else
    squawk 25 "$prepetcdgencerts_host !=  $prepetcdgencerts_primary_etcd_master"
    command2run="rsync -ave \"ssh -p $prepetcdgencerts_port\" /tmp/${prepetcdgencerts_host}/pki ${prepetcdgencerts_user}@${prepetcdgencerts_host}:/etc/kubernetes/"
    squawk 25 "$command2run"
    sudo_command $prepetcdgencerts_primary_etcd_master_port  $prepetcdgencerts_primary_etcd_master_user  $prepetcdgencerts_primary_etcd_master "$command2run"
    command2run="chown -R root:root /etc/kubernetes/pki"
    sudo_command $prepetcdgencerts_port $prepetcdgencerts_user $prepetcdgencerts_host "$command2run"
  fi
  squawk 86 "clean up certs that should not be copied off prepetcdgencerts host"
  command2run="find /tmp/${prepetcdgencerts_host} -name ca.key -type f -delete -print"
  sudo_command $prepetcdgencerts_primary_etcd_master_port  $prepetcdgencerts_primary_etcd_master_user  $prepetcdgencerts_primary_etcd_master "$command2run"
}

finalize_etcd_gen_certs () {
  finalize_etcdgencerts_port=$1
  finalize_etcdgencerts_user=$2
  finalize_etcdgencerts_host=$3
  squawk 55 "finalize_etcd_gen_certs port $finalize_etcdgencerts_port user $finalize_etcdgencerts_user host $finalize_etcdgencerts_host"
  command2run="cp -R  /tmp/${finalize_etcdgencerts_host}/kubeadmcfg.yaml /etc/kubernetes/ \
    && cp -R  /tmp/${finalize_etcdgencerts_host}/pki /etc/kubernetes/ \
    && chown -R root:root /etc/kubernetes/pki"
  sudo_command $finalize_etcdgencerts_port $finalize_etcdgencerts_user $finalize_etcdgencerts_host "$command2run"
}

prep_init_etcd_classic () {
  this_user=$1
  this_host=$2
  this_name=$3
  this_port=$4

  init_etcd_tmp=$(mktemp -d)
  mkdir $init_etcd_tmp/pki
  cp $KUBASH_DIR/templates/ca-config.json $init_etcd_tmp/pki/ca-config.json
  cp $KUBASH_DIR/templates/client.json $init_etcd_tmp/pki/client.json
  jinja2 $KUBASH_DIR/templates/ca-csr.json $KUBASH_CLUSTER_DIR/ca-data.yaml --format=yaml > $init_etcd_tmp/pki/ca-csr.json
  command2run='mkdir -p /etc/etcd'
  squawk 5 "command2run $command2run"
  sudo_command $this_port $this_user $this_host "$command2run"
  squawk 15 "rsync $KUBASH_RSYNC_OPTS 'ssh -p $this_port' $init_etcd_tmp/pki $this_user@$this_host:/tmp/"
  rsync $KUBASH_RSYNC_OPTS "ssh -p $this_port" $init_etcd_tmp/pki $this_user@$this_host:/tmp/
  command2run='ls -lh /tmp/pki'
  #sudo_command $this_port $this_user $this_host "$command2run"
  command2run='rm -Rf /etc/etcd/pki'
  sudo_command $this_port $this_user $this_host "$command2run"
  command2run='mv /tmp/pki /etc/etcd/pki'
  sudo_command $this_port $this_user $this_host "$command2run"
  rm -Rf $init_etcd_tmp

  command2run="chown $this_user /etc/etcd/pki"
  sudo_command $this_port $this_user $this_host "$command2run"
  rsync $KUBASH_RSYNC_OPTS "ssh -p $this_port" $KUBASH_DIR/templates/ca-config.json $this_user@$this_host:/tmp/ca-config.json
  command2run='mv /tmp/ca-config.json /etc/etcd/pki/ca-config.json'
  sudo_command $this_port $this_user $this_host "$command2run"

  # crictl
  if [[ $DO_CRICTL = 'true' ]]; then
    real_path_crictl=$(realpath ${KUBASH_BIN}/crictl)
    copy_in_parallel_to_all "$real_path_crictl" "/tmp/crictl"
    command2run='mv /tmp/crictl /usr/local/bin/crictl'
    do_command_in_parallel "$command2run"
  fi

  copy_in_parallel_to_all "${KUBASH_BIN}/cfssljson" "/tmp/cfssljson"
  command2run='mv /tmp/cfssljson /usr/local/bin/cfssljson'
  sudo_command $this_port $this_user $this_host "$command2run"
  do_command_in_parallel "$command2run"

  copy_in_parallel_to_all "${KUBASH_BIN}/cfssl" "/tmp/cfssl"
  command2run='mv /tmp/cfssl /usr/local/bin/cfssl'
  sudo_command $this_port $this_user $this_host "$command2run"
  do_command_in_parallel "$command2run"

  # Hack, delete after rebuild
  #command2run="echo 'PATH=/usr/local/bin:$PATH' >> /root/.bash_profile"
  #sudo_command $this_port $this_user $this_host "$command2run"
  #do_command_in_parallel_on_role "etcd"          "$command2run"
  #if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
  #  do_command_in_parallel_on_role "master"        "$command2run"
  #fi

  # add etcd user if it doesn't exist
  command2run='id -u etcd &>/dev/null || useradd etcd'
  sudo_command $this_port $this_user $this_host "$command2run"
  do_command_in_parallel_on_role "etcd"          "$command2run"
  if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
    do_command_in_parallel_on_role "master"        "$command2run"
  fi

  command2run='cd /etc/etcd/pki; cfssl gencert -initca ca-csr.json | cfssljson -bare ca -'
  sudo_command $this_port $this_user $this_host "$command2run"

  command2run='cd /etc/etcd/pki; cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=client client.json | cfssljson -bare client'
  sudo_command $this_port $this_user $this_host "$command2run"

  rsync $KUBASH_RSYNC_OPTS "ssh -p $this_port" $KUBASH_DIR/scripts/grabpki $this_user@$this_host:/tmp/grabpki
  command2run="bash /tmp/grabpki"
  sudo_command $this_port $this_user $this_host "$command2run"
  squawk 5 'pull etcd-pki.tgz from primary master'
  rsync $KUBASH_RSYNC_OPTS "ssh -p $this_port" $this_user@$this_host:/tmp/etcd-pki.tgz $KUBASH_CLUSTER_DIR/
  squawk 5 'and copy it to master and etcd hosts'
  copy_in_parallel_to_role "etcd" "$KUBASH_CLUSTER_DIR/etcd-pki.tgz" "/tmp/"
  copy_in_parallel_to_role "master" "$KUBASH_CLUSTER_DIR/etcd-pki.tgz" "/tmp/"
  command2run='cd /; tar zxf /tmp/etcd-pki.tgz'
  do_command_in_parallel_on_role "master"        "$command2run"
  do_command_in_parallel_on_role "etcd"          "$command2run"
  command2run='rm /tmp/etcd-pki.tgz'
  do_command_in_parallel_on_role "master"        "$command2run"
  do_command_in_parallel_on_role "etcd"          "$command2run"
  finish_etcd $this_user $this_host $this_name $this_port
}

prep_etcd () {
  squawk 5 "prep_etcd args: '$@'"
  this_user=$1
  this_host=$2
  this_name=$3
  this_port=$4

  get_major_minor_kube_version $this_user $this_host $this_name $this_port
  if [[ $KUBE_MAJOR_VER -eq 1 ]]; then
    squawk 175 'Kube Major Version 1 for prep etcd'
    if [[ $KUBE_MINOR_VER -lt 12 ]]; then
      squawk 75 'Kube Minor Version less than 12 for prep etcd'
      finish_etcd $this_user $this_host $this_name $this_port
    else
      squawk 75 'Kube Major Version greater than or equal to 12 for prep etcd'
      if [[ -e $KUBASH_CLUSTER_DIR/kube_primary_etcd ]]; then
        kube_primary=$(cat $KUBASH_CLUSTER_DIR/kube_primary_etcd)
        kube_primary_port=$(cat $KUBASH_CLUSTER_DIR/kube_primary_etcd_port)
        kube_primary_user=$(cat $KUBASH_CLUSTER_DIR/kube_primary_etcd_user)
      elif [[ -e $KUBASH_CLUSTER_DIR/kube_primary ]]; then
        kube_primary=$(cat $KUBASH_CLUSTER_DIR/kube_primary)
        kube_primary_port=$(cat $KUBASH_CLUSTER_DIR/kube_primary_port)
        kube_primary_user=$(cat $KUBASH_CLUSTER_DIR/kube_primary_user)
      else
        croak 3  'no master found'
      fi
      prep_etcd_gen_certs $this_port $this_user $this_host $kube_primary_port $kube_primary_user $kube_primary
      #prep_etcd_gen_certs $this_port $this_user $this_host $this_port $kube_primary_user $kube_primary
    fi
  elif [[ $MAJOR_VER -eq 0 ]]; then
    croak 3 'Major Version 0 unsupported'
  else
    croak 3 'Major Version Unknown'
  fi
}

check_coreos () {
  squawk 1 " check_coreos"
  do_coreos_init_count=0
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_os" == "coreos" ]]; then
      if [[ "$do_coreos_init_count" -lt "1" ]]; then
        do_coreos_initialization
  break
      fi
      ((++do_coreos_init_count))
    fi
  done < $KUBASH_HOSTS_CSV
}

grab_kube_pki_ext_etcd_sub () {
  grab_sub_USER=$1
  grab_sub_HOST=$2
  grab_sub_PORT=$3
  # Make a list of required etcd certificate files for subsequent masters
  # break indentation
    command2run='cat << EOF > sub-pki-files.txt
/etc/kubernetes/pki/ca.crt
/etc/kubernetes/pki/ca.key
/etc/kubernetes/pki/sa.key
/etc/kubernetes/pki/sa.pub
/etc/kubernetes/pki/front-proxy-ca.crt
/etc/kubernetes/pki/front-proxy-ca.key
EOF'
  # unbreak indentation

  squawk 55 "ssh ${grab_sub_USER}@${grab_sub_HOST} $command2run"
  sudo_command ${grab_sub_PORT} ${grab_sub_USER} ${grab_sub_HOST} "$command2run"

  # create the archive
  command2run="tar -czf /tmp/sub-pki.tar.gz -T sub-pki-files.txt"
  sudo_command ${grab_sub_PORT} ${grab_sub_USER} ${grab_sub_HOST} "$command2run"
  squawk 55 "scp -P ${grab_sub_PORT} ${grab_sub_USER}@${grab_sub_HOST}/tmp/sub-pki.tar.gz ${KUBASH_CLUSTER_DIR}/sub-pki.tar.gz"
  scp -P ${grab_sub_PORT} ${grab_sub_USER}@${grab_sub_HOST}:/tmp/sub-pki.tar.gz ${KUBASH_CLUSTER_DIR}/sub-pki.tar.gz
  command2run="rm /tmp/sub-pki.tar.gz"
}

grab_kube_pki_stacked_method () {
  grab_USER=$1
  grab_HOST=$2
  grab_PORT=$3
  # Make a list of required etcd certificate files
  # break indentation
    command2run='cat << EOF > kube-pki-files.txt
/etc/kubernetes/pki/ca.crt
/etc/kubernetes/pki/ca.key
/etc/kubernetes/pki/sa.key
/etc/kubernetes/pki/sa.pub
/etc/kubernetes/pki/front-proxy-ca.crt
/etc/kubernetes/pki/front-proxy-ca.key
/etc/kubernetes/pki/etcd/ca.crt
/etc/kubernetes/pki/etcd/ca.key
/etc/kubernetes/admin.conf
EOF'
  # unbreak indentation
#/etc/kubernetes/controller-manager.conf
#/etc/kubernetes/scheduler.conf

  squawk 55 "ssh ${grab_USER}@${grab_HOST} $command2run"
  sudo_command ${grab_PORT} ${grab_USER} ${grab_HOST} "$command2run"

  # create the archive
  command2run="tar -czf /tmp/kube-pki.tar.gz -T kube-pki-files.txt"
  sudo_command ${grab_PORT} ${grab_USER} ${grab_HOST} "$command2run"
  squawk 55 "scp -P ${grab_PORT} ${grab_USER}@${grab_HOST}/tmp/kube-pki.tar.gz ${KUBASH_CLUSTER_DIR}/kube-pki.tar.gz"
  scp -P ${grab_PORT} ${grab_USER}@${grab_HOST}:/tmp/kube-pki.tar.gz ${KUBASH_CLUSTER_DIR}/kube-pki.tar.gz
  command2run="rm /tmp/kube-pki.tar.gz"
  #sudo_command ${grab_PORT} ${grab_USER} ${grab_HOST} "$command2run"
}

push_kube_pki_stacked_method () {
  push_USER=$1
  push_HOST=$2
  push_PORT=$3
  squawk 9 "rsync $KUBASH_RSYNC_OPTS ssh -p $push_PORT ${KUBASH_CLUSTER_DIR}/kube-pki.tar.gz $push_USER@$push_HOST:/tmp/"
  rsync $KUBASH_RSYNC_OPTS "ssh -p $push_PORT" ${KUBASH_CLUSTER_DIR}/kube-pki.tar.gz $push_USER@$push_HOST:/tmp/
  #command2run='mkdir -p /etc/kubernetes/pki && tar -xzvf /tmp/kube-pki.tar.gz -C /etc/kubernetes/pki --strip-components=3'
  command2run='mkdir -p /etc/kubernetes/pki && cd / && tar -xzvf /tmp/kube-pki.tar.gz'
  sudo_command ${push_PORT} ${push_USER} ${push_HOST} "$command2run"
  command2run='rm /tmp/kube-pki.tar.gz'
  #sudo_command ${push_PORT} ${push_USER} ${push_HOST} "$command2run"
}

push_kube_pki_ext_etcd_sub () {
  push_sub_USER=$1
  push_sub_HOST=$2
  push_sub_PORT=$3
  squawk 9 "rsync $KUBASH_RSYNC_OPTS ssh -p $push_sub_PORT ${KUBASH_CLUSTER_DIR}/sub-pki.tar.gz $push_sub_USER@$push_sub_HOST:/tmp/"
  rsync $KUBASH_RSYNC_OPTS "ssh -p $push_sub_PORT" ${KUBASH_CLUSTER_DIR}/sub-pki.tar.gz $push_sub_USER@$push_sub_HOST:/tmp/
  command2run='mkdir -p /etc/kubernetes/pki && cd / && tar -xzvf /tmp/sub-pki.tar.gz'
  sudo_command ${push_sub_PORT} ${push_sub_USER} ${push_sub_HOST} "$command2run"
  command2run='rm /tmp/sub-pki.tar.gz'
  #sudo_command ${push_sub_PORT} ${push_sub_USER} ${push_sub_HOST} "$command2run"
}

grab_pki_ext_etcd_method () {
  grab_pki_ext_etcdUSER=$1
  grab_pki_ext_etcdHOST=$2
  grab_pki_ext_etcdPORT=$3
  # Make a list of required etcd certificate files
  # break indentation
    command2run='cat << EOF > etcd-pki-files.txt
/etc/kubernetes/pki/etcd/ca.crt
/etc/kubernetes/pki/apiserver-etcd-client.crt
/etc/kubernetes/pki/apiserver-etcd-client.key
EOF'
  # unbreak indentation
  squawk 55 "ssh ${grab_pki_ext_etcdUSER}@${grab_pki_ext_etcdHOST} $command2run"
  sudo_command ${grab_pki_ext_etcdPORT} ${grab_pki_ext_etcdUSER} ${grab_pki_ext_etcdHOST} "$command2run"

  # create the archive
  command2run="tar -czf /tmp/etcd-pki.tar.gz -T etcd-pki-files.txt"
  sudo_command ${grab_pki_ext_etcdPORT} ${grab_pki_ext_etcdUSER} ${grab_pki_ext_etcdHOST} "$command2run"
  squawk 53 "scp -P ${grab_pki_ext_etcdPORT} ${grab_pki_ext_etcdUSER}@${grab_pki_ext_etcdHOST}/tmp/etcd-pki.tar.gz ${KUBASH_CLUSTER_DIR}/etcd-pki.tar.gz"
  scp -P ${grab_pki_ext_etcdPORT} ${grab_pki_ext_etcdUSER}@${grab_pki_ext_etcdHOST}:/tmp/etcd-pki.tar.gz ${KUBASH_CLUSTER_DIR}/etcd-pki.tar.gz
  command2run="rm /tmp/etcd-pki.tar.gz"
  sudo_command ${grab_pki_ext_etcdPORT} ${grab_pki_ext_etcdUSER} ${grab_pki_ext_etcdHOST} "$command2run"
}

push_pki_ext_etcd_method () {
  squawk 25 "push_pki_ext_etcd_method $@"
  push_pki_ext_etcd_USER=$1
  push_pki_ext_etcd_HOST=$2
  push_pki_ext_etcd_PORT=$3
  squawk 9 "rsync $KUBASH_RSYNC_OPTS ssh -p $push_pki_ext_etcd_PORT ${KUBASH_CLUSTER_DIR}/etcd-pki.tar.gz $push_pki_ext_etcd_USER@$push_pki_ext_etcd_HOST:/tmp/"
  rsync $KUBASH_RSYNC_OPTS "ssh -p $push_pki_ext_etcd_PORT" ${KUBASH_CLUSTER_DIR}/etcd-pki.tar.gz $push_pki_ext_etcd_USER@$push_pki_ext_etcd_HOST:/tmp/
  #command2run='mkdir -p /etc/kubernetes/pki && tar -xzvf /tmp/etcd-pki.tar.gz -C /etc/kubernetes/pki --strip-components=3'
  command2run='mkdir -p /etc/kubernetes/pki && cd / && tar -xzvf /tmp/etcd-pki.tar.gz'
  sudo_command ${push_pki_ext_etcd_PORT} ${push_pki_ext_etcd_USER} ${push_pki_ext_etcd_HOST} "$command2run"
  command2run='rm /tmp/etcd-pki.tar.gz'
  sudo_command ${push_pki_ext_etcd_PORT} ${push_pki_ext_etcd_USER} ${push_pki_ext_etcd_HOST} "$command2run"
}

determine_api_version () {
  if [[ $KUBE_MAJOR_VER -eq 1 ]]; then
    squawk 20 'Major Version 1'
    if [[ $KUBE_MINOR_VER -lt 9 ]]; then
      croak 3  "$KUBE_MINOR_VER is too old may not ever be supported"
    elif [[ $KUBE_MINOR_VER -eq 9 ]]; then
      squawk 20 'Minor Version 9'
      squawk 75 kubeadm_apiVersion="kubeadm.k8s.io/v1alpha1"
      export kubeadm_apiVersion="kubeadm.k8s.io/v1alpha1"
      kubeadm_cfg_kind=MasterConfiguration
      croak 3 "$KUBE_MINOR_VER is too old and is not supported"
    elif [[ $KUBE_MINOR_VER -eq 10 ]]; then
      squawk 20 'Minor Version 10'
      squawk 75 kubeadm_apiVersion="kubeadm.k8s.io/v1alpha1"
      export kubeadm_apiVersion="kubeadm.k8s.io/v1alpha1"
      kubeadm_cfg_kind=MasterConfiguration
      croak 3 "$KUBE_MINOR_VER is too old and is not supported"
    elif [[ $KUBE_MINOR_VER -eq 11 ]]; then
      squawk 20 'Minor Version 11'
      squawk 75 kubeadm_apiVersion="kubeadm.k8s.io/v1alpha2"
      export kubeadm_apiVersion="kubeadm.k8s.io/v1alpha2"
      kubeadm_cfg_kind=MasterConfiguration
      croak 3 "$KUBE_MINOR_VER is too old and is not supported"
    elif [[ $KUBE_MINOR_VER -eq 12 ]]; then
      squawk 20 'Minor Version 12'
      squawk 75 kubeadm_apiVersion="kubeadm.k8s.io/v1alpha2"
      export kubeadm_apiVersion="kubeadm.k8s.io/v1alpha2"
      kubeadm_cfg_kind=MasterConfiguration
      croak 3 "$KUBE_MINOR_VER is too old and is not supported"
    elif [[ $KUBE_MINOR_VER -eq 13 ]]; then
      squawk 20 'Minor Version 13'
      squawk 75 kubeadm_apiVersion="kubeadm.k8s.io/v1alpha3"
      export kubeadm_apiVersion="kubeadm.k8s.io/v1alpha3"
      kubeadm_cfg_kind=ClusterConfiguration
    elif [[ $KUBE_MINOR_VER -eq 14 ]]; then
      squawk 20 'Minor Version 14'
      squawk 75 kubeadm_apiVersion="kubeadm.k8s.io/v1beta1"
      export kubeadm_apiVersion="kubeadm.k8s.io/v1beta1"
      kubeadm_cfg_kind=ClusterConfiguration
    elif [[ $KUBE_MINOR_VER -eq 15 ]]; then
      squawk 20 'Minor Version 14'
      squawk 75 kubeadm_apiVersion="kubeadm.k8s.io/v1beta1"
      export kubeadm_apiVersion="kubeadm.k8s.io/v1beta1"
      kubeadm_cfg_kind=ClusterConfiguration
    elif [[ $KUBE_MINOR_VER -ge 16 ]]; then
      squawk 20 "Minor version = $KUBE_MINOR_VER,  Version greater than or equal 16"
      squawk 75 kubeadm_apiVersion="kubeadm.k8s.io/v1beta2"
      export kubeadm_apiVersion="kubeadm.k8s.io/v1beta2"
      kubeadm_cfg_kind=ClusterConfiguration
    else
      croak 3  "$KUBE_MINOR_VER not supported yet"
    fi
  elif [[ $MAJOR_VER -eq 0 ]]; then
    croak 3 'Major Version 0 unsupported'
  else
    croak 3 'Major Version Unknown'
  fi
}

etcd_kubernetes_ext_etcd_method () {
  etcd_kubernetes_13_ext_etcd_method
}

etcd_kubernetes_12_ext_etcd_method () {
  etcd_test_tmp=$(mktemp -d)
  INIT_USER=root
  #my_KUBE_CIDR="10.244.0.0/16"
  set_csv_columns
  etc_count_zero=0
  master_count_zero=0
  node_count_zero=0
  while IFS="," read -r $csv_columns
  do
    if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' || "$K8S_role" == 'primary_etcd' ]]; then
        ETCDHOSTS[$etc_count_zero]=$K8S_ip1
        ETCDNAMES[$etc_count_zero]=$K8S_node
        ETCDPORTS[$etc_count_zero]=$K8S_sshPort
        MASTERHOSTS[$master_count_zero]=$K8S_ip1
        MASTERNAMES[$master_count_zero]=$K8S_node
        MASTERPORTS[$master_count_zero]=$K8S_sshPort
        ((++etc_count_zero))
        ((++master_count_zero))
      elif [[ "$K8S_role" == 'node' ]]; then
        NODEHOSTS[$node_count_zero]=$K8S_ip1
        NODENAMES[$node_count_zero]=$K8S_node
        NODEPORTS[$node_count_zero]=$K8S_sshPort
        ((++node_count_zero))
      fi
    else
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'primary_etcd' ]]; then
        ETCDHOSTS[$etc_count_zero]=$K8S_ip1
        ETCDNAMES[$etc_count_zero]=$K8S_node
        ETCDPORTS[$etc_count_zero]=$K8S_sshPort
        ((++etc_count_zero))
      elif [[ "$K8S_role" == 'node' ]]; then
        NODEHOSTS[$node_count_zero]=$K8S_ip1
        NODENAMES[$node_count_zero]=$K8S_node
        NODEPORTS[$node_count_zero]=$K8S_sshPort
        ((++node_count_zero))
      elif [[ "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' ]]; then
        MASTERHOSTS[$master_count_zero]=$K8S_ip1
        MASTERNAMES[$master_count_zero]=$K8S_node
        MASTERPORTS[$master_count_zero]=$K8S_sshPort
        ((++master_count_zero))
      fi
    fi
  done <<< "$kubash_hosts_csv_slurped"
  echo $ETCDHOSTS
  sleep 33
  squawk 11 "866~ get_major_minor_kube_version $K8S_user ${MASTERHOSTS[0]} ${MASTERNAMES[0]} ${MASTERPORTS[0]}"
  get_major_minor_kube_version $K8S_user ${MASTERHOSTS[0]} ${MASTERNAMES[0]} ${MASTERPORTS[0]}
  determine_api_version

  echo -n "            initial-cluster: " > $etcd_test_tmp/initial-cluster.head
  count_etcd=0
  countetcdnodes=0
  while IFS="," read -r $csv_columns
  do
    echo "- \"${K8S_ip1}\"" >> $etcd_test_tmp/apiservercertsans.line
    if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' ]]; then
        if [[ $countetcdnodes -gt 0 ]]; then
          printf ',' >> $etcd_test_tmp/initial-cluster.line
        fi
        if [[ "$ETCD_TLS" == 'true' ]]; then
          printf "${K8S_node}=https://${K8S_ip1}:2380" >> $etcd_test_tmp/initial-cluster.line
          echo "      - https://${K8S_ip1}:2379" >> $etcd_test_tmp/endpoints.line
        else
          printf "${K8S_node}=https://${K8S_ip1}:2380" >> $etcd_test_tmp/initial-cluster.line
          echo "      - https://${K8S_ip1}:2379" >> $etcd_test_tmp/endpoints.line
          #printf "${K8S_node}=http://${K8S_ip1}:2380" >> $etcd_test_tmp/initial-cluster.line
          #echo "      - http://${K8S_ip1}:2379" >> $etcd_test_tmp/endpoints.line
        fi
        ((++countetcdnodes))
      fi
    else
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'primary_etcd' ]]; then
        if [[ $countetcdnodes -gt 0 ]]; then
          printf ',' >> $etcd_test_tmp/initial-cluster.line
        fi
        if [[ "$ETCD_TLS" == 'true' ]]; then
          printf "${K8S_node}=https://${K8S_ip1}:2380" >> $etcd_test_tmp/initial-cluster.line
          echo "      - https://${K8S_ip1}:2379" >> $etcd_test_tmp/endpoints.line
        else
          printf "${K8S_node}=https://${K8S_ip1}:2380" >> $etcd_test_tmp/initial-cluster.line
          echo "      - https://${K8S_ip1}:2379" >> $etcd_test_tmp/endpoints.line
          #printf "${K8S_node}=http://${K8S_ip1}:2380" >> $etcd_test_tmp/initial-cluster.line
          #echo "      - http://${K8S_ip1}:2379" >> $etcd_test_tmp/endpoints.line
        fi
        ((++countetcdnodes))
      fi
    fi
    ((++count_etcd))
  done <<< "$kubash_hosts_csv_slurped"
  if [[ "$ETCD_TLS" == 'true' ]]; then
    echo '      caFile: /etc/kubernetes/pki/etcd/ca.crt
      certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
      keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key' \
    >> $etcd_test_tmp/endpoints.line
  else
    echo '      caFile: /etc/kubernetes/pki/etcd/ca.crt
      certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
      keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key' \
    >> $etcd_test_tmp/endpoints.line
  fi
  printf " \n" >> $etcd_test_tmp/initial-cluster.line
  initial_cluster_line=$(cat $etcd_test_tmp/initial-cluster.head $etcd_test_tmp/initial-cluster.line)
  api_server_cert_sans_line=$(cat $etcd_test_tmp/apiservercertsans.line)
  endpoints_line=$(cat $etcd_test_tmp/endpoints.line)
  rm $etcd_test_tmp/initial-cluster.head $etcd_test_tmp/initial-cluster.line $etcd_test_tmp/apiservercertsans.line $etcd_test_tmp/endpoints.line

  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    PORT=${ETCDPORTS[$i]}
    sqawk 20 " Create temp directories to store files that will end up on other hosts."
    squawk 32 "mkdir -p $etcd_test_tmp/${HOST}/"
    mkdir -p $etcd_test_tmp/${HOST}/

    # break indentation
    command2run="cat << EOF > /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
[Service]
ExecStart=
ExecStart=/usr/bin/kubelet --address=127.0.0.1 --pod-manifest-path=/etc/kubernetes/manifests --allow-privileged=true
Restart=always
EOF"
    # unbreak indentation

    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"

    squawk 32 "mkdir -p /var/lib/kubelet/"
    command2run='mkdir -p /var/lib/kubelet'
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
    # break indentation
    command2run='cat << EOF > /var/lib/kubelet/config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: 127.0.0.1
staticpodpath: /etc/kubernetes/manifests
EOF'
    # unbreak indentation
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
  done
  #do_command_in_parallel_on_os 'coreos' "mkdir -p /opt/cni/bin"
  command2run="sed -i 's:/usr/bin:/opt/bin:g' /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf"
  set +e
  do_command_in_parallel_on_os 'coreos' "$command2run"
  set -e
  #do_command_in_parallel_on_role 'primary_etcd' "$command2run"
  #do_command_in_parallel_on_role 'etcd' "$command2run"

  for i in "${!MASTERHOSTS[@]}"; do
    HOST=${MASTERHOSTS[$i]}
    PORT=${ETCDPORTS[$i]}
    sqawk 21 " Create temp directories to store files that will end up on other hosts. Master version"
    squawk 33 "mkdir -p $etcd_test_tmp/${HOST}/"
    mkdir -p $etcd_test_tmp/${HOST}/
    # break indentation
    #command2run='cat << EOF > /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
#[Service]
#ExecStart=
#ExecStart=/usr/bin/kubelet --address=127.0.0.1 --pod-manifest-path=/etc/kubernetes/manifests --allow-privileged=true
#Restart=always
#EOF'
    ## unbreak indentation
    #squawk 55 "ssh ${INIT_USER}@${HOST} $command2run"
    #ssh ${INIT_USER}@${HOST} "$command2run"
  done


  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    NAME=${ETCDNAMES[$i]}
    cat << EOF > $etcd_test_tmp/${HOST}/kubeadmcfg.yaml
apiVersion: "$kubeadm_apiVersion"
kind: $kubeadm_cfg_kind
kubernetesVersion: $KUBERNETES_VERSION
etcd:
    local:
        serverCertSANs:
        - "${HOST}"
        peerCertSANs:
        - "${HOST}"
        extraArgs:
$initial_cluster_line
            initial-cluster-state: new
            name: ${NAME}
EOF
  if [[ "$ETCD_TLS" == 'true' ]]; then
    echo "            listen-peer-urls: https://${HOST}:2380
            listen-client-urls: https://${HOST}:2379
            advertise-client-urls: https://${HOST}:2379
            initial-advertise-peer-urls: https://${HOST}:2380" \
     >> $etcd_test_tmp/${HOST}/kubeadmcfg.yaml
  elif [[ "$ETCD_TLS" == 'calamazoo' ]]; then
    # neutered
    echo "            listen-peer-urls: http://${HOST}:2380
            listen-client-urls: http://${HOST}:2379
            advertise-client-urls: http://${HOST}:2379
            initial-advertise-peer-urls: http://${HOST}:2380" \
     >> $etcd_test_tmp/${HOST}/kubeadmcfg.yaml
  else
    echo "            listen-peer-urls: https://${HOST}:2380
            listen-client-urls: https://${HOST}:2379
            advertise-client-urls: https://${HOST}:2379
            initial-advertise-peer-urls: https://${HOST}:2380" \
     >> $etcd_test_tmp/${HOST}/kubeadmcfg.yaml
  fi
    command2run='systemctl daemon-reload'
    squawk 53 "ssh ${INIT_USER}@${HOST} $command2run"
    ssh ${INIT_USER}@${HOST} "$command2run"
    command2run='systemctl restart kubelet'
    squawk 53 "ssh ${INIT_USER}@${HOST} $command2run"
    ssh ${INIT_USER}@${HOST} "$command2run"
  done
  for i in "${!MASTERHOSTS[@]}"; do
    HOST=${MASTERHOSTS[$i]}
    NAME=${MASTERNAMES[$i]}
    if [[ $KUBE_MAJOR_VER -eq 1 ]]; then
      if [[ $KUBE_MINOR_VER -gt 11 ]]; then
       if [[ $SEMAPHORE_FLAG_KILL = 'not_gonna_be_it' ]]; then
        cat << EOF > $etcd_test_tmp/${HOST}/kubeadmcfg.yaml
apiVersion: $kubeadm_apiVersion
kind: InitConfiguration
kubernetesVersion: $KUBERNETES_VERSION
apiEndpoint:
  advertiseAddress: ${HOST}
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  name: ${NAME}
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
---
EOF
      fi
     fi
   fi
    cat << EOF >> $etcd_test_tmp/${HOST}/kubeadmcfg.yaml
apiVersion: $kubeadm_apiVersion
kind: $kubeadm_cfg_kind
kubernetesVersion: $KUBERNETES_VERSION
apiServerCertSANs:
- "127.0.0.1"
$api_server_cert_sans_line
controlPlaneEndpoint: "${MASTERHOSTS[0]}:6443"
etcd:
  external:
      endpoints:
$endpoints_line
networking:
  podSubnet: $my_KUBE_CIDR
EOF
    command2run='systemctl daemon-reload'
    squawk 53 "ssh ${INIT_USER}@${HOST} $command2run"
    ssh ${INIT_USER}@${HOST} "$command2run"
    #command2run='systemctl restart kubelet'
    #squawk 53 "ssh ${INIT_USER}@${HOST} $command2run"
    #ssh ${INIT_USER}@${HOST} "$command2run"
  done

  command2run='kubeadm alpha phase certs etcd-ca'
  squawk 53 "ssh ${INIT_USER}@${ETCDHOSTS[0]} $command2run"
  ssh ${INIT_USER}@${ETCDHOSTS[0]} "$command2run"

  squawk 5 "copy pki directory to host 0"
  command2run='mkdir -p /etc/kubernetes/pki'
  ssh ${INIT_USER}@${ETCDHOSTS[0]} "$command2run"|tar pzxvf -
  command2run='tar zcf - pki'
  PREV_PWD=$(pwd)
  cd $etcd_test_tmp/${ETCDHOSTS[0]}/
  squawk 56 "ssh ${INIT_USER}@${HOST} cd /etc/kubernetes;$command2run|tar pzxvf -"
  ssh ${INIT_USER}@${ETCDHOSTS[0]} "cd /etc/kubernetes;$command2run"|tar pzxvf -
  cd $PREV_PWD

  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    PREV_PWD=$(pwd)
    cd $etcd_test_tmp/
    squawk 53 "tar zcf - ${HOST} | ssh ${INIT_USER}@${ETCDHOSTS[0]} cd /tmp; tar pzxvf -"
    tar zcf - ${HOST} | ssh ${INIT_USER}@${ETCDHOSTS[0]} "cd /tmp; tar pzxvf -"
    cd $PREV_PWD
  done

  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    command2run="kubeadm alpha phase certs etcd-server --config=/tmp/${HOST}/kubeadmcfg.yaml"
    squawk 53 "ssh ${INIT_USER}@${ETCDHOSTS[0]} $command2run"
    ssh ${INIT_USER}@${ETCDHOSTS[0]} "$command2run"
    command2run="kubeadm alpha phase certs etcd-peer --config=/tmp/${HOST}/kubeadmcfg.yaml"
    squawk 53 "ssh ${INIT_USER}@${ETCDHOSTS[0]} $command2run"
    ssh ${INIT_USER}@${ETCDHOSTS[0]} "$command2run"
    command2run="kubeadm alpha phase certs etcd-healthcheck-client --config=/tmp/${HOST}/kubeadmcfg.yaml"
    squawk 53 "ssh ${INIT_USER}@${ETCDHOSTS[0]} $command2run"
    ssh ${INIT_USER}@${ETCDHOSTS[0]} "$command2run"
    command2run="kubeadm alpha phase certs apiserver-etcd-client --config=/tmp/${HOST}/kubeadmcfg.yaml"
    squawk 53 "ssh ${INIT_USER}@${ETCDHOSTS[0]} $command2run"
    ssh ${INIT_USER}@${ETCDHOSTS[0]} "$command2run"
    command2run="rsync -a /etc/kubernetes/pki /tmp/${HOST}/"
    squawk 53 "ssh ${INIT_USER}@${ETCDHOSTS[0]} $command2run"
    ssh ${INIT_USER}@${ETCDHOSTS[0]} "$command2run"
    squawk 5 "cleanup non-reusable certificates"
    command2run="find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete"
    squawk 53 "ssh ${INIT_USER}@${ETCDHOSTS[0]} $command2run"
    ssh ${INIT_USER}@${ETCDHOSTS[0]} "$command2run"
    squawk 5 "clean up certs that should not be copied off this host"
    command2run="find /tmp/${HOST} -name ca.key -type f -delete"
    squawk 53 "ssh ${INIT_USER}@${ETCDHOSTS[0]} $command2run"
    ssh ${INIT_USER}@${ETCDHOSTS[0]} "$command2run"
    #if [[ $i -eq 0 ]]; then
      #grab_pki_ext_etcd_method $K8S_user ${ETCDHOSTS[0]} ${ETCDPORTS[0]}
    #fi
  done

  squawk 5 "gather the pki and configs"
  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    PREV_PWD=$(pwd)
    cd $etcd_test_tmp/
    squawk 53 "ssh ${INIT_USER}@${ETCDHOSTS[0]} mkdir -p /etc/kubernetes && cd /tmp;tar zcf - ${HOST} | tar pzxvf -"
    ssh ${INIT_USER}@${ETCDHOSTS[0]} "mkdir -p /etc/kubernetes && cd /tmp;tar zcf - ${HOST}" | tar pzxvf -
    cd $PREV_PWD
  done
  squawk 5 "distribute the pki and configs to etcd hosts"
  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    PORT=${ETCDPORTS[$i]}
    PREV_PWD=$(pwd)
    cd $etcd_test_tmp/${HOST}
    squawk 53 "tar zcf - pki | ssh -p $PORT ${INIT_USER}@${HOST} cd /etc/kubernetes; tar pzxvf -"
    tar zcf - pki | ssh -p $PORT ${INIT_USER}@${HOST} "cd /etc/kubernetes; tar pzxvf -"
    squawk 53 "tar zcf - kubeadmcfg.yaml | ssh -p $PORT ${INIT_USER}@${HOST} cd /etc/kubernetes; tar pzxvf -"
    tar zcf - kubeadmcfg.yaml | ssh -p $PORT ${INIT_USER}@${HOST} "cd /etc/kubernetes; tar pzxvf -"
    cd $PREV_PWD
  done

  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    PORT=${ETCDPORTS[$i]}
    command2run="chown -R root:root /etc/kubernetes/pki"
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
    command2run="kubeadm alpha phase etcd local --config=/etc/kubernetes/kubeadmcfg.yaml"
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
  done
  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    PORT=${ETCDPORTS[$i]}
    command2run='ls -alh /root'
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
    command2run='ls -Ralh /etc/kubernetes/pki'
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
  done

  command2run="kubeadm config --kubernetes-version $KUBERNETES_VERSION images pull"
  for i in "${!MASTERHOSTS[@]}"; do
    HOST=${MASTERHOSTS[$i]}
    PORT=${MASTERPORTS[$i]}
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
  done
  squawk 33 "sleep 33 - give etcd a chance to settle"
  sleep 33

  command2run="docker run --rm  \
    --net host \
    -v /etc/kubernetes:/etc/kubernetes quay.io/coreos/etcd:v3.2.18 etcdctl \
    --cert-file /etc/kubernetes/pki/etcd/peer.crt \
    --key-file /etc/kubernetes/pki/etcd/peer.key \
    --ca-file /etc/kubernetes/pki/etcd/ca.crt \
    --endpoints https://${ETCDHOSTS[0]}:2379 cluster-health"

  squawk 53 'To test etcd run this commmand'
  squawk 53 "$command2run"
  this_counter=0
  while [[ "$this_counter" -lt "15" ]]; do
    sleep 3
    squawk 53 "sudo_command ${ETCDPORTS[0]} $K8S_user ${ETCDHOSTS[0]} $command2run"
    sudo_command ${ETCDPORTS[0]} $K8S_user ${ETCDHOSTS[0]} "$command2run"
    if [[ "$?" == "0" ]]; then
      squawk 1 "cluster is healthy"
      this_counter=100
    fi
    ((++this_counter))
  done
  grab_pki_ext_etcd_method $K8S_user ${ETCDHOSTS[0]} ${ETCDPORTS[0]}
  #grab_kube_pki_stacked_method $K8S_user ${ETCDHOSTS[0]} ${ETCDPORTS[0]}

  # distribute the pki and configs
  #for i in "${!MASTERHOSTS[@]}"; do
    #squawk 53 "cp -a $etcd_test_tmp/${ETCDHOSTS[0]}/pki $etcd_test_tmp/${MASTERHOSTS[$i]}/"
    #cp -a $etcd_test_tmp/${ETCDHOSTS[0]}/pki $etcd_test_tmp/${MASTERHOSTS[$i]}/
  #done
  for i in "${!MASTERHOSTS[@]}"; do
    HOST=${MASTERHOSTS[$i]}
    PREV_PWD=$(pwd)
    push_pki_ext_etcd_method  $K8S_user ${MASTERHOSTS[$i]} ${MASTERPORTS[$i]}
    cd $etcd_test_tmp/${HOST}
    #squawk 53 "tar zcf - pki | ssh ${INIT_USER}@${HOST} cd /etc/kubernetes; tar pzxvf -"
    #tar zcf - pki | ssh ${INIT_USER}@${HOST} "cd /etc/kubernetes; tar pzxvf -"
    squawk 53 "tar zcf - kubeadmcfg.yaml | ssh ${INIT_USER}@${HOST} cd /etc/kubernetes; tar pzxvf -"
    tar zcf - kubeadmcfg.yaml | ssh ${INIT_USER}@${HOST} "cd /etc/kubernetes; tar pzxvf -"
    cd $PREV_PWD
  done
  for i in "${!MASTERHOSTS[@]}"; do
    HOST=${MASTERHOSTS[$i]}
    #command2run='systemctl daemon-reload'
    #echo "ssh ${INIT_USER}@${HOST} $command2run"
  #  ssh ${INIT_USER}@${HOST} "$command2run"
    #command2run='systemctl stop kubelet'
    #echo "ssh ${INIT_USER}@${HOST} $command2run"
  #  ssh ${INIT_USER}@${HOST} "$command2run"
  done

  if [[ "$VERBOSITY" -ge "10" ]] ; then
    command2run="kubeadm init --dry-run --ignore-preflight-errors=FileAvailable--etc-kubernetes-manifests-etcd.yaml,ExternalEtcdVersion --config /etc/kubernetes/kubeadmcfg.yaml"
    squawk 105 "$command2run"
    sudo_command ${MASTERPORTS[0]} ${INIT_USER} ${MASTERHOSTS[0]} "$command2run"
  fi
  #sleep 11
  #command2run="kubeadm init  --ignore-preflight-errors=FileAvailable--etc-kubernetes-manifests-etcd.yaml,ExternalEtcdVersion --config /etc/kubernetes/kubeadmcfg.yaml"
  #master_grab_kube_config ${MASTERNAMES[0]} ${MASTERHOSTS[0]} $K8S_user ${MASTERPORTS[0]}
  #sudo_command ${MASTERPORTS[0]} $K8S_user ${MASTERHOSTS[0]} "$command2run"
  #command2run="kubeadm init --config /etc/kubernetes/kubeadmcfg.yaml"
  for i in "${!MASTERHOSTS[@]}"; do
    HOST=${MASTERHOSTS[$i]}
    NAME=${MASTERNAMES[$i]}
    if [[ -e "$KUBASH_CLUSTER_DIR/master_join.sh" ]]; then
      rsync $KUBASH_RSYNC_OPTS "ssh -p ${MASTERPORTS[$i]}" $KUBASH_CLUSTER_DIR/master_join.sh $INIT_USER@$HOST:/tmp/
      push_kube_pki_ext_etcd_sub ${INIT_USER} ${MASTERHOSTS[$i]} ${MASTERPORTS[$i]}
      my_KUBE_INIT="bash -l /tmp/master_join.sh"
      squawk 5 "kube init --> $my_KUBE_INIT"
      ssh -n -p ${MASTERPORTS[$i]} ${INIT_USER}@${HOST} "bash -l -c '$my_KUBE_INIT'" 2>&1 | tee $etcd_test_tmp/${HOST}-rawresults.k8s
      w8_node $my_node_name
    else
      my_KUBE_INIT="kubeadm init --config=/etc/kubernetes/kubeadmcfg.yaml"
      squawk 5 "master kube init --> $my_KUBE_INIT"
      squawk 25 "ssh -n -p ${MASTERPORTS[$i]} ${INIT_USER}@${HOST} 'bash -l -c which kubeadm'"
      ssh -n -p ${MASTERPORTS[$i]} ${INIT_USER}@${HOST} "bash -l -c 'which kubeadm'"
      my_grep='kubeadm join .* --token'
      #ssh -n -p ${MASTERPORTS[$i]} ${INIT_USER}@${HOST} "$my_KUBE_INIT" 2>&1 | tee $etcd_test_tmp/${HOST}-joinrawresults.k8s
      sudo_command ${MASTERPORTS[$i]} ${INIT_USER} ${HOST} "$my_KUBE_INIT"
      GET_JOIN_CMD="kubeadm token create --print-join-command"
      ssh -n -p ${MASTERPORTS[$i]} ${INIT_USER}@${HOST} "bash -l -c '$GET_JOIN_CMD'" 2>&1 | tee $etcd_test_tmp/${HOST}-rawresults.k8s
      run_join=$(cat $etcd_test_tmp/${HOST}-rawresults.k8s \
        | grep -P -- "$my_grep" \
      )
      join_token=$(cat $etcd_test_tmp/${HOST}-rawresults.k8s \
        | grep -P -- "$my_grep" \
        | sed 's/\(.*\)--token\ \(\S*\)\ --discovery-token-ca-cert-hash\ .*/\2/')
      if [[ -z "$run_join" ]]; then
        horizontal_rule
        croak 3  'kubeadm init failed!'
      else
        echo $run_join > $KUBASH_CLUSTER_DIR/join.sh
        echo $run_join > $KUBASH_CLUSTER_DIR/master_join.sh
        #sed -i 's/$/ --ignore-preflight-errors=FileAvailable--etc-kubernetes-pki-ca.crt/' $KUBASH_CLUSTER_DIR/join.sh
        if [[ $KUBE_MINOR_VER -lt 16 ]]; then
          sed -i 's/$/ --experimental-control-plane/' $KUBASH_CLUSTER_DIR/master_join.sh
        elif [[ $KUBE_MINOR_VER -gt 15 ]]; then
          sed -i 's/$/ --control-plane/' $KUBASH_CLUSTER_DIR/master_join.sh
        fi
        echo $join_token > $KUBASH_CLUSTER_DIR/join_token
        master_grab_kube_config ${NAME} ${HOST} ${INIT_USER} ${MASTERPORTS[$i]}
        grab_kube_pki_ext_etcd_sub ${INIT_USER} ${MASTERHOSTS[$i]} ${MASTERPORTS[$i]}
        squawk 120 "rsync $KUBASH_RSYNC_OPTS ssh -p ${MASTERPORTS[$i]} $KUBASH_DIR/w8s/generic.w8 $INIT_USER@$HOST:/tmp/"
        rsync $KUBASH_RSYNC_OPTS "ssh -p ${MASTERPORTS[$i]}" $KUBASH_DIR/w8s/generic.w8 $INIT_USER@$HOST:/tmp/
        command2run='mv /tmp/generic.w8 /root/'
        squawk 153 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${INIT_USER} ${MASTERHOSTS[$i]} "$command2run"
        command2run='/root/generic.w8 kube-controller kube-system'
        squawk 153 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${INIT_USER} ${MASTERHOSTS[$i]} "$command2run"
        command2run='/root/generic.w8 kube-scheduler kube-system'
        squawk 153 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${INIT_USER} ${MASTERHOSTS[$i]} "$command2run"
        command2run='/root/generic.w8 kube-apiserver kube-system'
        squawk 153 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${INIT_USER} ${MASTERHOSTS[$i]} "$command2run"
        sleep 11
        squawk 5 "do_net before other masters"
        w8_kubectl
        do_net
        w8_node $my_node_name
      fi
    fi
  done
  while IFS="," read -r $csv_columns
  do
    squawk 85 "ROLE $K8S_role $K8S_user $K8S_ip1 $K8S_sshPort"
    if [[ "$K8S_role" == 'node' ]]; then
      squawk 101 'neutered'
      #squawk 65 "push kube pki ext etcd sub $K8S_user $K8S_ip1 $K8S_sshPort"
      #push_pki_ext_etcd_method   $K8S_user $K8S_ip1 $K8S_sshPort
      #push_kube_pki_ext_etcd_sub $K8S_user $K8S_ip1 $K8S_sshPort
    fi
  done <<< "$kubash_hosts_csv_slurped"
  rm -Rf $etcd_test_tmp
}

etcd_kubernetes_13_ext_etcd_method () {
  etcd_test_tmp=$(mktemp -d)
  INIT_USER=root
  set_csv_columns
  etc_count_zero=0
  master_count_zero=0
  node_count_zero=0
  while IFS="," read -r $csv_columns
  do
    if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' || "$K8S_role" == 'primary_etcd' ]]; then
        ETCDHOSTS[$etc_count_zero]=$K8S_ip1
        ETCDNAMES[$etc_count_zero]=$K8S_node
        ETCDPORTS[$etc_count_zero]=$K8S_sshPort
        MASTERHOSTS[$master_count_zero]=$K8S_ip1
        MASTERNAMES[$master_count_zero]=$K8S_node
        MASTERPORTS[$master_count_zero]=$K8S_sshPort
        ((++etc_count_zero))
        ((++master_count_zero))
      elif [[ "$K8S_role" == 'node' ]]; then
        NODEHOSTS[$node_count_zero]=$K8S_ip1
        NODENAMES[$node_count_zero]=$K8S_node
        NODEPORTS[$node_count_zero]=$K8S_sshPort
        ((++node_count_zero))
      fi
    else
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'primary_etcd' ]]; then
        ETCDHOSTS[$etc_count_zero]=$K8S_ip1
        ETCDNAMES[$etc_count_zero]=$K8S_node
        ETCDPORTS[$etc_count_zero]=$K8S_sshPort
        ((++etc_count_zero))
      elif [[ "$K8S_role" == 'node' ]]; then
        NODEHOSTS[$node_count_zero]=$K8S_ip1
        NODENAMES[$node_count_zero]=$K8S_node
        NODEPORTS[$node_count_zero]=$K8S_sshPort
        ((++node_count_zero))
      elif [[ "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' ]]; then
        MASTERHOSTS[$master_count_zero]=$K8S_ip1
        MASTERNAMES[$master_count_zero]=$K8S_node
        MASTERPORTS[$master_count_zero]=$K8S_sshPort
        ((++master_count_zero))
      fi
    fi
  done <<< "$kubash_hosts_csv_slurped"
  echo $ETCDHOSTS
  sleep 33
  squawk 11 "1361~ get_major_minor_kube_version $K8S_user ${MASTERHOSTS[0]} ${MASTERNAMES[0]} ${MASTERPORTS[0]}"
  get_major_minor_kube_version $K8S_user ${MASTERHOSTS[0]} ${MASTERNAMES[0]} ${MASTERPORTS[0]}
  determine_api_version

  echo -n "            initial-cluster: " > $etcd_test_tmp/initial-cluster.head
  count_etcd=0
  countetcdnodes=0
  while IFS="," read -r $csv_columns
  do
    echo "- \"${K8S_ip1}\"" >> $etcd_test_tmp/apiservercertsans.line
    if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' ]]; then
        if [[ $countetcdnodes -gt 0 ]]; then
          printf ',' >> $etcd_test_tmp/initial-cluster.line
        fi
        if [[ "$ETCD_TLS" == 'true' ]]; then
          printf "${K8S_node}=https://${K8S_ip1}:2380" >> $etcd_test_tmp/initial-cluster.line
          echo "      - https://${K8S_ip1}:2379" >> $etcd_test_tmp/endpoints.line
        else
          printf "${K8S_node}=https://${K8S_ip1}:2380" >> $etcd_test_tmp/initial-cluster.line
          echo "      - https://${K8S_ip1}:2379" >> $etcd_test_tmp/endpoints.line
        fi
        ((++countetcdnodes))
      fi
    else
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'primary_etcd' ]]; then
        if [[ $countetcdnodes -gt 0 ]]; then
          printf ',' >> $etcd_test_tmp/initial-cluster.line
        fi
        if [[ "$ETCD_TLS" == 'true' ]]; then
          printf "${K8S_node}=https://${K8S_ip1}:2380" >> $etcd_test_tmp/initial-cluster.line
          echo "      - https://${K8S_ip1}:2379" >> $etcd_test_tmp/endpoints.line
        else
          printf "${K8S_node}=https://${K8S_ip1}:2380" >> $etcd_test_tmp/initial-cluster.line
          echo "      - https://${K8S_ip1}:2379" >> $etcd_test_tmp/endpoints.line
        fi
        ((++countetcdnodes))
      fi
    fi
    ((++count_etcd))
  done <<< "$kubash_hosts_csv_slurped"
  if [[ "$ETCD_TLS" == 'true' ]]; then
    echo '      caFile: /etc/kubernetes/pki/etcd/ca.crt
      certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
      keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key' \
    >> $etcd_test_tmp/endpoints.line
  else
    echo '      caFile: /etc/kubernetes/pki/etcd/ca.crt
      certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
      keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key' \
    >> $etcd_test_tmp/endpoints.line
  fi
  printf " \n" >> $etcd_test_tmp/initial-cluster.line
  initial_cluster_line=$(cat $etcd_test_tmp/initial-cluster.head $etcd_test_tmp/initial-cluster.line)
  api_server_cert_sans_line=$(cat $etcd_test_tmp/apiservercertsans.line)
  endpoints_line=$(cat $etcd_test_tmp/endpoints.line)
  rm $etcd_test_tmp/initial-cluster.head $etcd_test_tmp/initial-cluster.line $etcd_test_tmp/apiservercertsans.line $etcd_test_tmp/endpoints.line

  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    PORT=${ETCDPORTS[$i]}
    # Create temp directories to store files that will end up on other hosts.
    squawk 50 "mkdir -p $etcd_test_tmp/${HOST}/"
    mkdir -p $etcd_test_tmp/${HOST}/

    # break indentation
    command2run="cat << EOF > /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
[Service]
ExecStart=
ExecStart=/usr/bin/kubelet --address=127.0.0.1 --pod-manifest-path=/etc/kubernetes/manifests --allow-privileged=true
Restart=always
EOF"
    # unbreak indentation
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"

    squawk 50 "mkdir -p /var/lib/kubelet/"
    command2run='mkdir -p /var/lib/kubelet'
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
    # break indentation
    command2run='cat << EOF > /var/lib/kubelet/config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: 127.0.0.1
staticpodpath: /etc/kubernetes/manifests
EOF'
    # unbreak indentation
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
  done
  command2run="sed -i 's:/usr/bin:/opt/bin:g' /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf"
  set +e
  do_command_in_parallel_on_os 'coreos' "$command2run"
  set -e
  #do_command_in_parallel_on_role 'primary_etcd' "$command2run"
  #do_command_in_parallel_on_role 'etcd' "$command2run"

  for i in "${!MASTERHOSTS[@]}"; do
    HOST=${MASTERHOSTS[$i]}
    squawk 51 "mkdir -p $etcd_test_tmp/${HOST}/"
    mkdir -p $etcd_test_tmp/${HOST}/
  done


  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    NAME=${ETCDNAMES[$i]}
    cat << EOF > $etcd_test_tmp/${HOST}/kubeadmcfg.yaml
apiVersion: "$kubeadm_apiVersion"
kind: $kubeadm_cfg_kind
kubernetesVersion: $KUBERNETES_VERSION
etcd:
    local:
        serverCertSANs:
        - "${HOST}"
        peerCertSANs:
        - "${HOST}"
        extraArgs:
$initial_cluster_line
            initial-cluster-state: new
            name: ${NAME}
EOF
  if [[ "$ETCD_TLS" == 'true' ]]; then
    echo "            listen-peer-urls: https://${HOST}:2380
            listen-client-urls: https://${HOST}:2379
            advertise-client-urls: https://${HOST}:2379
            initial-advertise-peer-urls: https://${HOST}:2380" \
     >> $etcd_test_tmp/${HOST}/kubeadmcfg.yaml
  elif [[ "$ETCD_TLS" == 'calamazoo' ]]; then
    # neutered
    echo "            listen-peer-urls: http://${HOST}:2380
            listen-client-urls: http://${HOST}:2379
            advertise-client-urls: http://${HOST}:2379
            initial-advertise-peer-urls: http://${HOST}:2380" \
     >> $etcd_test_tmp/${HOST}/kubeadmcfg.yaml
  else
    echo "            listen-peer-urls: https://${HOST}:2380
            listen-client-urls: https://${HOST}:2379
            advertise-client-urls: https://${HOST}:2379
            initial-advertise-peer-urls: https://${HOST}:2380" \
     >> $etcd_test_tmp/${HOST}/kubeadmcfg.yaml
  fi
    command2run='systemctl daemon-reload'
    squawk 53 "ssh ${INIT_USER}@${HOST} $command2run"
    ssh ${INIT_USER}@${HOST} "$command2run"
    command2run='systemctl restart kubelet'
    squawk 53 "ssh ${INIT_USER}@${HOST} $command2run"
    ssh ${INIT_USER}@${HOST} "$command2run"
  done
  for i in "${!MASTERHOSTS[@]}"; do
    HOST=${MASTERHOSTS[$i]}
    NAME=${MASTERNAMES[$i]}
    if [[ $KUBE_MAJOR_VER -eq 1 ]]; then
      if [[ $KUBE_MINOR_VER -gt 11 ]]; then
       if [[ $SEMAPHORE_FLAG_KILL = 'not_gonna_be_it' ]]; then
        cat << EOF > $etcd_test_tmp/${HOST}/kubeadmcfg.yaml
apiVersion: $kubeadm_apiVersion
kind: InitConfiguration
kubernetesVersion: $KUBERNETES_VERSION
apiEndpoint:
  advertiseAddress: ${HOST}
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  name: ${NAME}
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
---
EOF
      fi
     fi
   fi
    cat << EOF >> $etcd_test_tmp/${HOST}/kubeadmcfg.yaml
apiVersion: $kubeadm_apiVersion
kind: $kubeadm_cfg_kind
kubernetesVersion: $KUBERNETES_VERSION
apiServerCertSANs:
- "127.0.0.1"
$api_server_cert_sans_line
controlPlaneEndpoint: "${MASTERHOSTS[0]}:6443"
etcd:
  external:
      endpoints:
$endpoints_line
networking:
  podSubnet: $my_KUBE_CIDR
EOF
    command2run='systemctl daemon-reload'
    squawk 53 "ssh ${INIT_USER}@${HOST} $command2run"
    ssh ${INIT_USER}@${HOST} "bash -l -c '$command2run'"
  done

  command2run='kubeadm init phase certs etcd-ca'
  squawk 53 "ssh ${INIT_USER}@${ETCDHOSTS[0]} $command2run"
  ssh ${INIT_USER}@${ETCDHOSTS[0]} "bash -l -c '$command2run'"

  squawk 5 "copy pki directory to host 0"
  command2run='mkdir -p /etc/kubernetes/pki'
  ssh ${INIT_USER}@${ETCDHOSTS[0]} "$command2run"|tar pzxvf -
  command2run='tar zcf - pki'
  PREV_PWD=$(pwd)
  cd $etcd_test_tmp/${ETCDHOSTS[0]}/
  squawk 56 "ssh ${INIT_USER}@${HOST} cd /etc/kubernetes;$command2run|tar pzxvf -"
  ssh ${INIT_USER}@${ETCDHOSTS[0]} "cd /etc/kubernetes;bash -l -c '$command2run'"|tar pzxvf -
  cd $PREV_PWD

  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    PREV_PWD=$(pwd)
    cd $etcd_test_tmp/
    squawk 53 "tar zcf - ${HOST} | ssh ${INIT_USER}@${ETCDHOSTS[0]} cd /tmp; tar pzxvf -"
    tar zcf - ${HOST} | ssh ${INIT_USER}@${ETCDHOSTS[0]} "cd /tmp; tar pzxvf -"
    cd $PREV_PWD
  done

  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    command2run="kubeadm init phase certs etcd-server --config=/tmp/${HOST}/kubeadmcfg.yaml"
    squawk 53 "ssh ${INIT_USER}@${ETCDHOSTS[0]} $command2run"
    ssh ${INIT_USER}@${ETCDHOSTS[0]} "bash -l -c '$command2run'"
    command2run="kubeadm init phase certs etcd-peer --config=/tmp/${HOST}/kubeadmcfg.yaml"
    squawk 53 "ssh ${INIT_USER}@${ETCDHOSTS[0]} $command2run"
    ssh ${INIT_USER}@${ETCDHOSTS[0]} "bash -l -c '$command2run'"
    command2run="kubeadm init phase certs etcd-healthcheck-client --config=/tmp/${HOST}/kubeadmcfg.yaml"
    squawk 53 "ssh ${INIT_USER}@${ETCDHOSTS[0]} $command2run"
    ssh ${INIT_USER}@${ETCDHOSTS[0]} "bash -l -c '$command2run'"
    command2run="kubeadm init phase certs apiserver-etcd-client --config=/tmp/${HOST}/kubeadmcfg.yaml"
    squawk 53 "ssh ${INIT_USER}@${ETCDHOSTS[0]} $command2run"
    ssh ${INIT_USER}@${ETCDHOSTS[0]} "bash -l -c '$command2run'"
    command2run="rsync -a /etc/kubernetes/pki /tmp/${HOST}/"
    squawk 53 "ssh ${INIT_USER}@${ETCDHOSTS[0]} $command2run"
    ssh ${INIT_USER}@${ETCDHOSTS[0]} "bash -l -c '$command2run'"
    squawk 5 "cleanup non-reusable certificates"
    command2run="find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete"
    squawk 53 "ssh ${INIT_USER}@${ETCDHOSTS[0]} $command2run"
    ssh ${INIT_USER}@${ETCDHOSTS[0]} "bash -l -c '$command2run'"
    squawk 5 "clean up certs that should not be copied off this host"
    command2run="find /tmp/${HOST} -name ca.key -type f -delete"
    squawk 53 "ssh ${INIT_USER}@${ETCDHOSTS[0]} $command2run"
    ssh ${INIT_USER}@${ETCDHOSTS[0]} "bash -l -c '$command2run'"
  done

  squawk 5 "gather the pki and configs"
  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    PREV_PWD=$(pwd)
    cd $etcd_test_tmp/
    squawk 53 "ssh -p $PORT ${INIT_USER}@${ETCDHOSTS[0]} mkdir -p /etc/kubernetes && cd /tmp;tar zcf - ${HOST} | tar pzxvf -"
    ssh -p $PORT ${INIT_USER}@${ETCDHOSTS[0]} "mkdir -p /etc/kubernetes && cd /tmp;tar zcf - ${HOST}" | tar pzxvf -
    cd $PREV_PWD
  done
  squawk 5 "distribute the pki and configs to etcd hosts"
  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    PORT=${ETCDPORTS[$i]}
    PREV_PWD=$(pwd)
    cd $etcd_test_tmp/${HOST}
    squawk 55 "tar zcf - pki | ssh -p $PORT ${INIT_USER}@${HOST} cd /etc/kubernetes; tar pzxvf -"
    tar zcf - pki | ssh -p $PORT ${INIT_USER}@${HOST} "cd /etc/kubernetes; tar pzxvf -"
    squawk 55 "tar zcf - kubeadmcfg.yaml | ssh -p $PORT ${INIT_USER}@${HOST} cd /etc/kubernetes; tar pzxvf -"
    tar zcf - kubeadmcfg.yaml | ssh -p $PORT ${INIT_USER}@${HOST} "cd /etc/kubernetes; tar pzxvf -"
    cd $PREV_PWD
  done

  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    PORT=${ETCDPORTS[$i]}
    command2run="chown -R root:root /etc/kubernetes/pki"
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
    command2run="kubeadm init phase etcd local --config=/etc/kubernetes/kubeadmcfg.yaml"
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
  done
  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    PORT=${ETCDPORTS[$i]}
    command2run='ls -alh /root'
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
    command2run='ls -Ralh /etc/kubernetes/pki'
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
  done

  command2run="kubeadm config --kubernetes-version $KUBERNETES_VERSION images pull"
  for i in "${!MASTERHOSTS[@]}"; do
    HOST=${MASTERHOSTS[$i]}
    PORT=${MASTERPORTS[$i]}
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
  done
  squawk 33 "sleep 33 - give etcd a chance to settle"
  sleep 33

  command2run="docker run --rm  \
    --net host \
    -v /etc/kubernetes:/etc/kubernetes quay.io/coreos/etcd:v3.2.18 etcdctl \
    --cert-file /etc/kubernetes/pki/etcd/peer.crt \
    --key-file /etc/kubernetes/pki/etcd/peer.key \
    --ca-file /etc/kubernetes/pki/etcd/ca.crt \
    --endpoints https://${ETCDHOSTS[0]}:2379 cluster-health"

  squawk 55 'To test etcd run this commmand'
  squawk 55 "$command2run"
  this_counter=0
  while [[ "$this_counter" -lt "15" ]]; do
    sleep 3
    squawk 55 "sudo_command ${ETCDPORTS[0]} $K8S_user ${ETCDHOSTS[0]} $command2run"
    sudo_command ${ETCDPORTS[0]} $K8S_user ${ETCDHOSTS[0]} "$command2run"
    if [[ "$?" == "0" ]]; then
      squawk 1 "cluster is healthy"
      this_counter=100
    fi
    ((++this_counter))
  done
  grab_pki_ext_etcd_method $K8S_user ${ETCDHOSTS[0]} ${ETCDPORTS[0]}

  for i in "${!MASTERHOSTS[@]}"; do
    HOST=${MASTERHOSTS[$i]}
    PREV_PWD=$(pwd)
    push_pki_ext_etcd_method  $K8S_user ${MASTERHOSTS[$i]} ${MASTERPORTS[$i]}
    cd $etcd_test_tmp/${HOST}
    squawk 55 "tar zcf - kubeadmcfg.yaml | ssh ${INIT_USER}@${HOST} cd /etc/kubernetes; tar pzxvf -"
    tar zcf - kubeadmcfg.yaml | ssh ${INIT_USER}@${HOST} "cd /etc/kubernetes; tar pzxvf -"
    cd $PREV_PWD
  done
  for i in "${!MASTERHOSTS[@]}"; do
    HOST=${MASTERHOSTS[$i]}
  done

  if [[ "$VERBOSITY" -ge "10" ]] ; then
    command2run="kubeadm init --dry-run --ignore-preflight-errors=FileAvailable--etc-kubernetes-manifests-etcd.yaml,ExternalEtcdVersion --config /etc/kubernetes/kubeadmcfg.yaml"
    squawk 105 "$command2run"
    #ssh ${INIT_USER}@${MASTERHOSTS[0]} "bash -l -c '$command2run'"
    sudo_command ${MASTERPORTS[0]} ${INIT_USER} ${MASTERHOSTS[0]} "$command2run"
  fi
  for i in "${!MASTERHOSTS[@]}"; do
    HOST=${MASTERHOSTS[$i]}
    NAME=${MASTERNAMES[$i]}
    if [[ -e "$KUBASH_CLUSTER_DIR/master_join.sh" ]]; then
      rsync $KUBASH_RSYNC_OPTS "ssh -p ${MASTERPORTS[$i]}" $KUBASH_CLUSTER_DIR/master_join.sh $INIT_USER@$HOST:/tmp/
      push_kube_pki_ext_etcd_sub ${INIT_USER} ${MASTERHOSTS[$i]} ${MASTERPORTS[$i]}
      my_KUBE_INIT="bash -l /tmp/master_join.sh"
      squawk 5 "kube init --> $my_KUBE_INIT"
      ssh -n -p ${MASTERPORTS[$i]} ${INIT_USER}@${HOST} "which kubeadm"
      ssh -n -p ${MASTERPORTS[$i]} ${INIT_USER}@${HOST} "$my_KUBE_INIT" 2>&1 | tee $etcd_test_tmp/${HOST}-rawresults.k8s
      w8_node $my_node_name
    else
      my_KUBE_INIT="kubeadm init --config=/etc/kubernetes/kubeadmcfg.yaml"
      squawk 5 "master kube init --> $my_KUBE_INIT"
      squawk 25 "ssh -n -p ${MASTERPORTS[$i]} ${INIT_USER}@${HOST} 'bash -l -c which kubeadm'"
      ssh -n -p ${MASTERPORTS[$i]} ${INIT_USER}@${HOST} "bash -l -c 'which kubeadm'"
      my_grep='kubeadm join .* --token'
      ssh -n -p ${MASTERPORTS[$i]} ${INIT_USER}@${HOST} "bash -l -c '$my_KUBE_INIT'" 2>&1 | tee $etcd_test_tmp/${HOST}-joinrawresults.k8s
      GET_JOIN_CMD="kubeadm token create --print-join-command"
      ssh -n -p ${MASTERPORTS[$i]} ${INIT_USER}@${HOST} "bash -l -c '$GET_JOIN_CMD'" 2>&1 | tee $etcd_test_tmp/${HOST}-rawresults.k8s
      run_join=$(cat $etcd_test_tmp/${HOST}-rawresults.k8s \
        | grep -P -- "$my_grep" \
      )
      #run_join=$(cat $etcd_test_tmp/${HOST}-rawresults.k8s | grep -P -- "$my_grep")
      join_token=$(cat $etcd_test_tmp/${HOST}-rawresults.k8s \
        | grep -P -- "$my_grep" \
        | sed 's/\(.*\)--token\ \(\S*\)\ --discovery-token-ca-cert-hash\ .*/\2/')
      if [[ -z "$run_join" ]]; then
        horizontal_rule
        croak 3  'kubeadm init failed!'
      else
        echo $run_join > $KUBASH_CLUSTER_DIR/join.sh
        echo $run_join > $KUBASH_CLUSTER_DIR/master_join.sh
        if [[ $KUBE_MINOR_VER -lt 16 ]]; then
          sed -i 's/$/ --experimental-control-plane/' $KUBASH_CLUSTER_DIR/master_join.sh
        elif [[ $KUBE_MINOR_VER -gt 15 ]]; then
          sed -i 's/$/ --control-plane/' $KUBASH_CLUSTER_DIR/master_join.sh
        fi
        echo $join_token > $KUBASH_CLUSTER_DIR/join_token
        master_grab_kube_config ${NAME} ${HOST} ${INIT_USER} ${MASTERPORTS[$i]}
        grab_kube_pki_ext_etcd_sub ${INIT_USER} ${MASTERHOSTS[$i]} ${MASTERPORTS[$i]}
        squawk 120 "rsync $KUBASH_RSYNC_OPTS ssh -p ${MASTERPORTS[$i]} $KUBASH_DIR/w8s/generic.w8 $INIT_USER@$HOST:/tmp/"
        rsync $KUBASH_RSYNC_OPTS "ssh -p ${MASTERPORTS[$i]}" $KUBASH_DIR/w8s/generic.w8 $INIT_USER@$HOST:/tmp/
        command2run='mv /tmp/generic.w8 /root/'
        squawk 155 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${INIT_USER} ${MASTERHOSTS[$i]} "$command2run"
        command2run='/root/generic.w8 kube-proxy kube-system'
        squawk 155 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${INIT_USER} ${MASTERHOSTS[$i]} "$command2run"
        command2run='/root/generic.w8 kube-apiserver kube-system'
        squawk 155 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${INIT_USER} ${MASTERHOSTS[$i]} "$command2run"
        command2run='/root/generic.w8 kube-controller kube-system'
        squawk 155 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${INIT_USER} ${MASTERHOSTS[$i]} "$command2run"
        command2run='/root/generic.w8 kube-scheduler kube-system'
        squawk 155 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${INIT_USER} ${MASTERHOSTS[$i]} "$command2run"
        sleep 11
        squawk 5 "do_net before other masters"
        w8_kubectl
        do_net
        w8_node $my_node_name
      fi
    fi
  done
  rm -Rf $etcd_test_tmp
}

etcd_kubernetes_13_ext_etcd_method () {
  etcd_test_tmp=$(mktemp -d)
  INIT_USER=root
  set_csv_columns
  etc_count_zero=0
  master_count_zero=0
  node_count_zero=0
  while IFS="," read -r $csv_columns
  do
    if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' || "$K8S_role" == 'primary_etcd' ]]; then
        ETCDHOSTS[$etc_count_zero]=$K8S_ip1
        ETCDNAMES[$etc_count_zero]=$K8S_node
        ETCDPORTS[$etc_count_zero]=$K8S_sshPort
        MASTERHOSTS[$master_count_zero]=$K8S_ip1
        MASTERNAMES[$master_count_zero]=$K8S_node
        MASTERPORTS[$master_count_zero]=$K8S_sshPort
        ((++etc_count_zero))
        ((++master_count_zero))
      elif [[ "$K8S_role" == 'node' ]]; then
        NODEHOSTS[$node_count_zero]=$K8S_ip1
        NODENAMES[$node_count_zero]=$K8S_node
        NODEPORTS[$node_count_zero]=$K8S_sshPort
        ((++node_count_zero))
      fi
    else
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'primary_etcd' ]]; then
        ETCDHOSTS[$etc_count_zero]=$K8S_ip1
        ETCDNAMES[$etc_count_zero]=$K8S_node
        ETCDPORTS[$etc_count_zero]=$K8S_sshPort
        ((++etc_count_zero))
      elif [[ "$K8S_role" == 'node' ]]; then
        NODEHOSTS[$node_count_zero]=$K8S_ip1
        NODENAMES[$node_count_zero]=$K8S_node
        NODEPORTS[$node_count_zero]=$K8S_sshPort
        ((++node_count_zero))
      elif [[ "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' ]]; then
        MASTERHOSTS[$master_count_zero]=$K8S_ip1
        MASTERNAMES[$master_count_zero]=$K8S_node
        MASTERPORTS[$master_count_zero]=$K8S_sshPort
        ((++master_count_zero))
      fi
    fi
  done <<< "$kubash_hosts_csv_slurped"
  echo $ETCDHOSTS
  sleep 33
  squawk 11 "1807~ get_major_minor_kube_version $K8S_user ${MASTERHOSTS[0]} ${MASTERNAMES[0]} ${MASTERPORTS[0]}"
  get_major_minor_kube_version $K8S_user ${MASTERHOSTS[0]} ${MASTERNAMES[0]} ${MASTERPORTS[0]}
  determine_api_version

  echo -n "            initial-cluster: " > $etcd_test_tmp/initial-cluster.head
  count_etcd=0
  countetcdnodes=0
  while IFS="," read -r $csv_columns
  do
    echo "- \"${K8S_ip1}\"" >> $etcd_test_tmp/apiservercertsans.line
    if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' ]]; then
        if [[ $countetcdnodes -gt 0 ]]; then
          printf ',' >> $etcd_test_tmp/initial-cluster.line
        fi
        if [[ "$ETCD_TLS" == 'true' ]]; then
          printf "${K8S_node}=https://${K8S_ip1}:2380" >> $etcd_test_tmp/initial-cluster.line
          echo "      - https://${K8S_ip1}:2379" >> $etcd_test_tmp/endpoints.line
        else
          printf "${K8S_node}=https://${K8S_ip1}:2380" >> $etcd_test_tmp/initial-cluster.line
          echo "      - https://${K8S_ip1}:2379" >> $etcd_test_tmp/endpoints.line
        fi
        ((++countetcdnodes))
      fi
    else
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'primary_etcd' ]]; then
        if [[ $countetcdnodes -gt 0 ]]; then
          printf ',' >> $etcd_test_tmp/initial-cluster.line
        fi
        if [[ "$ETCD_TLS" == 'true' ]]; then
          printf "${K8S_node}=https://${K8S_ip1}:2380" >> $etcd_test_tmp/initial-cluster.line
          echo "      - https://${K8S_ip1}:2379" >> $etcd_test_tmp/endpoints.line
        else
          printf "${K8S_node}=https://${K8S_ip1}:2380" >> $etcd_test_tmp/initial-cluster.line
          echo "      - https://${K8S_ip1}:2379" >> $etcd_test_tmp/endpoints.line
        fi
        ((++countetcdnodes))
      fi
    fi
    ((++count_etcd))
  done <<< "$kubash_hosts_csv_slurped"
  if [[ "$ETCD_TLS" == 'true' ]]; then
    echo '      caFile: /etc/kubernetes/pki/etcd/ca.crt
      certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
      keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key' \
    >> $etcd_test_tmp/endpoints.line
  else
    echo '      caFile: /etc/kubernetes/pki/etcd/ca.crt
      certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
      keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key' \
    >> $etcd_test_tmp/endpoints.line
  fi
  printf " \n" >> $etcd_test_tmp/initial-cluster.line
  initial_cluster_line=$(cat $etcd_test_tmp/initial-cluster.head $etcd_test_tmp/initial-cluster.line)
  api_server_cert_sans_line=$(cat $etcd_test_tmp/apiservercertsans.line)
  endpoints_line=$(cat $etcd_test_tmp/endpoints.line)
  rm $etcd_test_tmp/initial-cluster.head $etcd_test_tmp/initial-cluster.line $etcd_test_tmp/apiservercertsans.line $etcd_test_tmp/endpoints.line

  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    PORT=${ETCDPORTS[$i]}
    # Create temp directories to store files that will end up on other hosts.
    squawk 66 "mkdir -p $etcd_test_tmp/${HOST}/"
    mkdir -p $etcd_test_tmp/${HOST}/

    # break indentation
    command2run="cat << EOF > /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
[Service]
ExecStart=
ExecStart=/usr/bin/kubelet --address=127.0.0.1 --pod-manifest-path=/etc/kubernetes/manifests --allow-privileged=true
Restart=always
EOF"
    # unbreak indentation
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"

    squawk 66 "mkdir -p /var/lib/kubelet/"
    command2run='mkdir -p /var/lib/kubelet'
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
    # break indentation
    command2run='cat << EOF > /var/lib/kubelet/config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: 127.0.0.1
staticpodpath: /etc/kubernetes/manifests
EOF'
    # unbreak indentation
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
  done
  command2run="sed -i 's:/usr/bin:/opt/bin:g' /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf"
  set +e
  do_command_in_parallel_on_os 'coreos' "$command2run"
  set -e
  #do_command_in_parallel_on_role 'primary_etcd' "$command2run"
  #do_command_in_parallel_on_role 'etcd' "$command2run"

  for i in "${!MASTERHOSTS[@]}"; do
    HOST=${MASTERHOSTS[$i]}
    squawk 67 "mkdir -p $etcd_test_tmp/${HOST}/"
    mkdir -p $etcd_test_tmp/${HOST}/
  done


  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    NAME=${ETCDNAMES[$i]}
    cat << EOF > $etcd_test_tmp/${HOST}/kubeadmcfg.yaml
apiVersion: "$kubeadm_apiVersion"
kind: $kubeadm_cfg_kind
kubernetesVersion: $KUBERNETES_VERSION
etcd:
    local:
        serverCertSANs:
        - "${HOST}"
        peerCertSANs:
        - "${HOST}"
        extraArgs:
$initial_cluster_line
            initial-cluster-state: new
            name: ${NAME}
EOF
  if [[ "$ETCD_TLS" == 'true' ]]; then
    echo "            listen-peer-urls: https://${HOST}:2380
            listen-client-urls: https://${HOST}:2379
            advertise-client-urls: https://${HOST}:2379
            initial-advertise-peer-urls: https://${HOST}:2380" \
     >> $etcd_test_tmp/${HOST}/kubeadmcfg.yaml
  elif [[ "$ETCD_TLS" == 'calamazoo' ]]; then
    # neutered
    echo "            listen-peer-urls: http://${HOST}:2380
            listen-client-urls: http://${HOST}:2379
            advertise-client-urls: http://${HOST}:2379
            initial-advertise-peer-urls: http://${HOST}:2380" \
     >> $etcd_test_tmp/${HOST}/kubeadmcfg.yaml
  else
    echo "            listen-peer-urls: https://${HOST}:2380
            listen-client-urls: https://${HOST}:2379
            advertise-client-urls: https://${HOST}:2379
            initial-advertise-peer-urls: https://${HOST}:2380" \
     >> $etcd_test_tmp/${HOST}/kubeadmcfg.yaml
  fi
    command2run='systemctl daemon-reload'
    squawk 55 "ssh ${INIT_USER}@${HOST} $command2run"
    ssh ${INIT_USER}@${HOST} "$command2run"
    command2run='systemctl restart kubelet'
    squawk 55 "ssh ${INIT_USER}@${HOST} $command2run"
    ssh ${INIT_USER}@${HOST} "$command2run"
  done
  for i in "${!MASTERHOSTS[@]}"; do
    HOST=${MASTERHOSTS[$i]}
    NAME=${MASTERNAMES[$i]}
    if [[ $KUBE_MAJOR_VER -eq 1 ]]; then
      if [[ $KUBE_MINOR_VER -gt 11 ]]; then
       if [[ $SEMAPHORE_FLAG_KILL = 'not_gonna_be_it' ]]; then
        cat << EOF > $etcd_test_tmp/${HOST}/kubeadmcfg.yaml
apiVersion: $kubeadm_apiVersion
kind: InitConfiguration
kubernetesVersion: $KUBERNETES_VERSION
apiEndpoint:
  advertiseAddress: ${HOST}
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  name: ${NAME}
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
---
EOF
      fi
     fi
   fi
    cat << EOF >> $etcd_test_tmp/${HOST}/kubeadmcfg.yaml
apiVersion: $kubeadm_apiVersion
kind: $kubeadm_cfg_kind
kubernetesVersion: $KUBERNETES_VERSION
apiServerCertSANs:
- "127.0.0.1"
$api_server_cert_sans_line
controlPlaneEndpoint: "${MASTERHOSTS[0]}:6443"
etcd:
  external:
      endpoints:
$endpoints_line
networking:
  podSubnet: $my_KUBE_CIDR
EOF
    command2run='systemctl daemon-reload'
    squawk 55 "ssh ${INIT_USER}@${HOST} $command2run"
    ssh ${INIT_USER}@${HOST} "$command2run"
  done

  command2run='kubeadm init phase certs etcd-ca'
  squawk 55 "ssh ${INIT_USER}@${ETCDHOSTS[0]} $command2run"
  ssh ${INIT_USER}@${ETCDHOSTS[0]} "bash -l -c '$command2run'"

  squawk 5 "copy pki directory to host 0"
  command2run='tar zcf - pki'
  PREV_PWD=$(pwd)
  cd $etcd_test_tmp/${ETCDHOSTS[0]}/
  squawk 56 "ssh ${INIT_USER}@${HOST} mkdir -p /etc/kubernetes && cd /etc/kubernetes;$command2run|tar pzxvf -"
  ssh ${INIT_USER}@${ETCDHOSTS[0]} "mkdir -p /etc/kubernetes && cd /etc/kubernetes;bash -l -c '$command2run'"|tar pzxvf -
  cd $PREV_PWD

  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    PREV_PWD=$(pwd)
    cd $etcd_test_tmp/
    squawk 55 "tar zcf - ${HOST} | ssh ${INIT_USER}@${ETCDHOSTS[0]} cd /tmp; tar pzxvf -"
    tar zcf - ${HOST} | ssh ${INIT_USER}@${ETCDHOSTS[0]} "cd /tmp; tar pzxvf -"
    cd $PREV_PWD
  done

  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    command2run="kubeadm init phase certs etcd-server --config=/tmp/${HOST}/kubeadmcfg.yaml"
    sudo_command ${ETCDPORTS[0]} ${INIT_USER} ${ETCDHOSTS[0]} "$command2run"
    command2run="kubeadm init phase certs etcd-peer --config=/tmp/${HOST}/kubeadmcfg.yaml"
    sudo_command ${ETCDPORTS[0]} ${INIT_USER} ${ETCDHOSTS[0]} "$command2run"
    command2run="kubeadm init phase certs etcd-healthcheck-client --config=/tmp/${HOST}/kubeadmcfg.yaml"
    sudo_command ${ETCDPORTS[0]} ${INIT_USER} ${ETCDHOSTS[0]} "$command2run"
    command2run="kubeadm init phase certs apiserver-etcd-client --config=/tmp/${HOST}/kubeadmcfg.yaml"
    sudo_command ${ETCDPORTS[0]} ${INIT_USER} ${ETCDHOSTS[0]} "$command2run"
    command2run="rsync -a /etc/kubernetes/pki /tmp/${HOST}/"
    sudo_command ${ETCDPORTS[0]} ${INIT_USER} ${ETCDHOSTS[0]} "$command2run"
    squawk 5 "cleanup non-reusable certificates"
    command2run="find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete"
    sudo_command ${ETCDPORTS[0]} ${INIT_USER} ${ETCDHOSTS[0]} "$command2run"
    squawk 5 "clean up certs that should not be copied off this host"
    command2run="find /tmp/${HOST} -name ca.key -type f -delete"
    sudo_command ${ETCDPORTS[0]} ${INIT_USER} ${ETCDHOSTS[0]} "$command2run"
  done

  squawk 5 "gather the pki and configs"
  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    PORT=${ETCDPORTS[$i]}
    PREV_PWD=$(pwd)
    cd $etcd_test_tmp/
    squawk 55 "ssh -p $PORT ${INIT_USER}@${ETCDHOSTS[0]} mkdir -p /etc/kubernetes && cd /tmp;tar zcf - ${HOST} | tar pzxvf -"
    ssh -p $PORT ${INIT_USER}@${ETCDHOSTS[0]} "mkdir -p /etc/kubernetes && cd /tmp;tar zcf - ${HOST}" | tar pzxvf -
    cd $PREV_PWD
  done
  squawk 5 "distribute the pki and configs to etcd hosts"
  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    PORT=${ETCDPORTS[$i]}
    PREV_PWD=$(pwd)
    cd $etcd_test_tmp/${HOST}
    squawk 55 "tar zcf - pki | ssh -p $PORT ${INIT_USER}@${HOST} cd /etc/kubernetes; tar pzxvf -"
    tar zcf - pki | ssh -p $PORT ${INIT_USER}@${HOST} "cd /etc/kubernetes; tar pzxvf -"
    squawk 55 "tar zcf - kubeadmcfg.yaml | ssh -p $PORT ${INIT_USER}@${HOST} cd /etc/kubernetes; tar pzxvf -"
    tar zcf - kubeadmcfg.yaml | ssh -p $PORT ${INIT_USER}@${HOST} "cd /etc/kubernetes; tar pzxvf -"
    cd $PREV_PWD
  done

  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    PORT=${ETCDPORTS[$i]}
    command2run="chown -R root:root /etc/kubernetes/pki"
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
    command2run="kubeadm init phase etcd local --config=/etc/kubernetes/kubeadmcfg.yaml"
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
  done
  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    PORT=${ETCDPORTS[$i]}
    command2run='ls -alh /root'
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
    command2run='ls -Ralh /etc/kubernetes/pki'
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
  done

  command2run="kubeadm config --kubernetes-version $KUBERNETES_VERSION images pull"
  for i in "${!MASTERHOSTS[@]}"; do
    HOST=${MASTERHOSTS[$i]}
    PORT=${MASTERPORTS[$i]}
    sudo_command ${PORT} ${INIT_USER} ${HOST} "$command2run"
  done
  squawk 33 "sleep 33 - give etcd a chance to settle"
  sleep 33

  command2run="docker run --rm  \
    --net host \
    -v /etc/kubernetes:/etc/kubernetes quay.io/coreos/etcd:v3.2.18 etcdctl \
    --cert-file /etc/kubernetes/pki/etcd/peer.crt \
    --key-file /etc/kubernetes/pki/etcd/peer.key \
    --ca-file /etc/kubernetes/pki/etcd/ca.crt \
    --endpoints https://${ETCDHOSTS[0]}:2379 cluster-health"

  squawk 55 'To test etcd run this commmand'
  squawk 55 "$command2run"
  this_counter=0
  while [[ "$this_counter" -lt "15" ]]; do
    sleep 3
    squawk 55 "sudo_command ${ETCDPORTS[0]} $K8S_user ${ETCDHOSTS[0]} $command2run"
    sudo_command ${ETCDPORTS[0]} $K8S_user ${ETCDHOSTS[0]} "$command2run"
    if [[ "$?" == "0" ]]; then
      squawk 1 "cluster is healthy"
      this_counter=100
    fi
    ((++this_counter))
  done
  grab_pki_ext_etcd_method $K8S_user ${ETCDHOSTS[0]} ${ETCDPORTS[0]}

  for i in "${!MASTERHOSTS[@]}"; do
    HOST=${MASTERHOSTS[$i]}
    PREV_PWD=$(pwd)
    push_pki_ext_etcd_method  $K8S_user ${MASTERHOSTS[$i]} ${MASTERPORTS[$i]}
    cd $etcd_test_tmp/${HOST}
    squawk 55 "tar zcf - kubeadmcfg.yaml | ssh ${INIT_USER}@${HOST} cd /etc/kubernetes; tar pzxvf -"
    tar zcf - kubeadmcfg.yaml | ssh ${INIT_USER}@${HOST} "cd /etc/kubernetes; tar pzxvf -"
    cd $PREV_PWD
  done
  for i in "${!MASTERHOSTS[@]}"; do
    HOST=${MASTERHOSTS[$i]}
  done

  if [[ "$VERBOSITY" -ge "10" ]] ; then
    command2run="kubeadm init --dry-run --ignore-preflight-errors=FileAvailable--etc-kubernetes-manifests-etcd.yaml,ExternalEtcdVersion --config /etc/kubernetes/kubeadmcfg.yaml"
    squawk 105 "$command2run"
    sudo_command ${MASTERPORTS[0]} ${INIT_USER} ${MASTERHOSTS[0]} "$command2run"
  fi
  for i in "${!MASTERHOSTS[@]}"; do
    HOST=${MASTERHOSTS[$i]}
    NAME=${MASTERNAMES[$i]}
    if [[ -e "$KUBASH_CLUSTER_DIR/master_join.sh" ]]; then
      rsync $KUBASH_RSYNC_OPTS "ssh -p ${MASTERPORTS[$i]}" $KUBASH_CLUSTER_DIR/master_join.sh $INIT_USER@$HOST:/tmp/
      push_kube_pki_ext_etcd_sub ${INIT_USER} ${MASTERHOSTS[$i]} ${MASTERPORTS[$i]}
      my_KUBE_INIT="bash -l /tmp/master_join.sh"
      squawk 5 "kube init --> $my_KUBE_INIT"
      ssh -n -p ${MASTERPORTS[$i]} ${INIT_USER}@${HOST} "$my_KUBE_INIT" 2>&1 | tee $etcd_test_tmp/${HOST}-rawresults.k8s
      w8_node $my_node_name
    else
      my_KUBE_INIT="kubeadm init --config=/etc/kubernetes/kubeadmcfg.yaml"
      squawk 5 "master kube init --> $my_KUBE_INIT"
      squawk 25 "ssh -n -p ${MASTERPORTS[$i]} ${INIT_USER}@${HOST} 'bash -l -c which kubeadm'"
      ssh -n -p ${MASTERPORTS[$i]} ${INIT_USER}@${HOST} "bash -l -c 'which kubeadm'"
      my_grep='kubeadm join .* --token'
      ssh -n -p ${MASTERPORTS[$i]} ${INIT_USER}@${HOST} "bash -l -c '$my_KUBE_INIT'" 2>&1 | tee $etcd_test_tmp/${HOST}-joinrawresults.k8s
      GET_JOIN_CMD="kubeadm token create --print-join-command"
      ssh -n -p ${MASTERPORTS[$i]} ${INIT_USER}@${HOST} "bash -l -c '$GET_JOIN_CMD'" 2>&1 | tee $etcd_test_tmp/${HOST}-rawresults.k8s
      run_join=$(cat $etcd_test_tmp/${HOST}-rawresults.k8s \
        | grep -P -- "$my_grep" \
      )
      #run_join=$(cat $etcd_test_tmp/${HOST}-rawresults.k8s | grep -P -- "$my_grep")
      join_token=$(cat $etcd_test_tmp/${HOST}-rawresults.k8s \
        | grep -P -- "$my_grep" \
        | sed 's/\(.*\)--token\ \(\S*\)\ --discovery-token-ca-cert-hash\ .*/\2/')
      if [[ -z "$run_join" ]]; then
        horizontal_rule
        croak 3  'kubeadm init failed!'
      else
        echo $run_join > $KUBASH_CLUSTER_DIR/join.sh
        echo $run_join > $KUBASH_CLUSTER_DIR/master_join.sh
        if [[ $KUBE_MINOR_VER -lt 16 ]]; then
          sed -i 's/$/ --experimental-control-plane/' $KUBASH_CLUSTER_DIR/master_join.sh
        elif [[ $KUBE_MINOR_VER -gt 15 ]]; then
          sed -i 's/$/ --control-plane/' $KUBASH_CLUSTER_DIR/master_join.sh
        fi
        echo $join_token > $KUBASH_CLUSTER_DIR/join_token
        master_grab_kube_config ${NAME} ${HOST} ${INIT_USER} ${MASTERPORTS[$i]}
        grab_kube_pki_ext_etcd_sub ${INIT_USER} ${MASTERHOSTS[$i]} ${MASTERPORTS[$i]}
        squawk 120 "rsync $KUBASH_RSYNC_OPTS ssh -p ${MASTERPORTS[$i]} $KUBASH_DIR/w8s/generic.w8 $INIT_USER@$HOST:/tmp/"
        rsync $KUBASH_RSYNC_OPTS "ssh -p ${MASTERPORTS[$i]}" $KUBASH_DIR/w8s/generic.w8 $INIT_USER@$HOST:/tmp/
        command2run='mv /tmp/generic.w8 /root/'
        squawk 155 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${INIT_USER} ${MASTERHOSTS[$i]} "$command2run"
        command2run='/root/generic.w8 kube-proxy kube-system'
        squawk 155 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${INIT_USER} ${MASTERHOSTS[$i]} "$command2run"
        command2run='/root/generic.w8 kube-apiserver kube-system'
        squawk 155 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${INIT_USER} ${MASTERHOSTS[$i]} "$command2run"
        command2run='/root/generic.w8 kube-controller kube-system'
        squawk 155 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${INIT_USER} ${MASTERHOSTS[$i]} "$command2run"
        command2run='/root/generic.w8 kube-scheduler kube-system'
        squawk 155 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${INIT_USER} ${MASTERHOSTS[$i]} "$command2run"
        sleep 11
        squawk 5 "do_net before other masters"
        w8_kubectl
        do_net
        w8_node $my_node_name
      fi
    fi
  done
  rm -Rf $etcd_test_tmp
}

etcd_kubernetes_docs_stacked_method () {
  etcd_kubernetes_13_docs_stacked_method
}

etcd_kubernetes_12_docs_stacked_method () {
  number_limiter=$1
  etcd_stacked_tmp=$(mktemp -d)
  STACKED_USER=root
  set_csv_columns
  etc_count_zero=0
  master_count_zero=0
  node_count_zero=0
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' || "$K8S_role" == 'primary_etcd' ]]; then
      ETCDHOSTS[$etc_count_zero]=$K8S_ip1
      ETCDNAMES[$etc_count_zero]=$K8S_node
      ETCDPORTS[$etc_count_zero]=$K8S_sshPort
      MASTERHOSTS[$master_count_zero]=$K8S_ip1
      MASTERNAMES[$master_count_zero]=$K8S_node
      MASTERPORTS[$master_count_zero]=$K8S_sshPort
      ((++etc_count_zero))
      ((++master_count_zero))
    elif [[ "$K8S_role" == 'node' ]]; then
      NODEHOSTS[$node_count_zero]=$K8S_ip1
      NODENAMES[$node_count_zero]=$K8S_node
      NODEPORTS[$node_count_zero]=$K8S_sshPort
      ((++node_count_zero))
    fi
  done <<< "$kubash_hosts_csv_slurped"
  echo $ETCDHOSTS
  sleep 33
  squawk 11 "2229~ get_major_minor_kube_version $K8S_user ${MASTERHOSTS[0]} ${MASTERNAMES[0]} ${MASTERPORTS[0]}"
  get_major_minor_kube_version $K8S_user ${MASTERHOSTS[0]} ${MASTERNAMES[0]} ${MASTERPORTS[0]}
  determine_api_version

  echo -n '            initial-cluster: "' > $etcd_stacked_tmp/initial-cluster.head
  if [[ "$ETCD_TLS" == 'true' ]]; then
    echo -n '            listen-client-urls: "https://127.0.0.1:2379,' > $etcd_stacked_tmp/listen-client_urls.head
  else
    echo -n '            listen-client-urls: "https://127.0.0.1:2379,' > $etcd_stacked_tmp/listen-client_urls.head
  fi
  count_etcd=0
  countetcdnodes=0
  while IFS="," read -r $csv_columns
  do
    echo "- \"${K8S_ip1}\"" >> $etcd_stacked_tmp/apiservercertsans.line
    if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' || "$K8S_role" == 'primary_etcd' ]]; then
      if [[ $countetcdnodes -gt 0 ]]; then
        printf ',' >> $etcd_stacked_tmp/initial-cluster.line
        printf ',' >> $etcd_stacked_tmp/listen-client_urls.line
      fi
      if [[ "$ETCD_TLS" == 'true' ]]; then
        echo "      - https://${K8S_ip1}:2379" >> $etcd_stacked_tmp/endpoints.line
        printf "${K8S_node}=https://${K8S_ip1}:2380" >>  $etcd_stacked_tmp/initial-cluster.line
        printf "https://${K8S_ip1}:2379" > $etcd_stacked_tmp/${countetcdnodes}-listen-client_urls.line
      else
        echo "      - https://${K8S_ip1}:2379" >> $etcd_stacked_tmp/endpoints.line
        printf "${K8S_node}=https://${K8S_ip1}:2380" >>  $etcd_stacked_tmp/initial-cluster.line
        printf "https://${K8S_ip1}:2379" > $etcd_stacked_tmp/${countetcdnodes}-listen-client_urls.line
      fi
      cp $etcd_stacked_tmp/initial-cluster.line $etcd_stacked_tmp/${countetcdnodes}-initial-cluster.line
      printf '"' >> $etcd_stacked_tmp/${countetcdnodes}-initial-cluster.line
      printf " \n" >> $etcd_stacked_tmp/${countetcdnodes}-initial-cluster.line
      printf '"' >> $etcd_stacked_tmp/${countetcdnodes}-listen-client_urls.line
      printf " \n" >> $etcd_stacked_tmp/${countetcdnodes}-listen-client_urls.line
      ((++countetcdnodes))
    fi
    ((++count_etcd))
  done <<< "$kubash_hosts_csv_slurped"
  printf '"' >> $etcd_stacked_tmp/initial-cluster.line
  printf '"' >> $etcd_stacked_tmp/listen-client_urls.line
  printf " \n" >> $etcd_stacked_tmp/initial-cluster.line
  printf " \n" >> $etcd_stacked_tmp/listen-client_urls.line

  initial_cluster_line=$(cat $etcd_stacked_tmp/initial-cluster.head $etcd_stacked_tmp/initial-cluster.line)
  api_server_cert_sans_line=$(cat $etcd_stacked_tmp/apiservercertsans.line)
  endpoints_line=$(cat $etcd_stacked_tmp/endpoints.line)

  for i in "${!MASTERHOSTS[@]}"; do
    initial_cluster_line=$(cat $etcd_stacked_tmp/initial-cluster.head $etcd_stacked_tmp/${i}-initial-cluster.line)
    listen_client_urls_line=$(cat $etcd_stacked_tmp/listen-client_urls.head $etcd_stacked_tmp/${i}-listen-client_urls.line)
    api_server_cert_sans_line=$(cat $etcd_stacked_tmp/apiservercertsans.line)
    endpoints_line=$(cat $etcd_stacked_tmp/endpoints.line)
    HOST=${MASTERHOSTS[$i]}
    NAME=${MASTERNAMES[$i]}
    mkdir -p $etcd_stacked_tmp/${HOST}
    if [ "$i" -eq '0' ]; then
      INITIAL_CLUSTER_STATE=new
    else
      INITIAL_CLUSTER_STATE=existing
    fi
    cat << EOF > $etcd_stacked_tmp/${HOST}/kubeadmcfg.yaml
apiVersion: $kubeadm_apiVersion
kind: $kubeadm_cfg_kind
kubernetesVersion: $KUBERNETES_VERSION
apiServerCertSANs:
- "127.0.0.1"
$api_server_cert_sans_line
controlPlaneEndpoint: "${MASTERHOSTS[0]}:6443"
etcd:
    local:
        serverCertSANs:
        - "${HOST}"
        - "${NAME}"
        peerCertSANs:
        - "${HOST}"
        - "${NAME}"
        extraArgs:
$listen_client_urls_line
            advertise-client-urls: "https://${HOST}:2379"
            listen-peer-urls: "https://${HOST}:2380"
            initial-advertise-peer-urls: "https://${HOST}:2380"
$initial_cluster_line
            initial-cluster-state: $INITIAL_CLUSTER_STATE
networking:
  podSubnet: $my_KUBE_CIDR
EOF
    rsync $KUBASH_RSYNC_OPTS "ssh -p ${MASTERPORTS[$i]}" $etcd_stacked_tmp/${HOST}/kubeadmcfg.yaml $STACKED_USER@$HOST:/tmp/
    command2run='mkdir -p /etc/kubernetes/'
    sudo_command ${MASTERPORTS[$i]} ${STACKED_USER} ${MASTERHOSTS[$i]} "$command2run"
    command2run='mv /tmp/kubeadmcfg.yaml /etc/kubernetes/'
    sudo_command ${MASTERPORTS[$i]} ${STACKED_USER} ${MASTERHOSTS[$i]} "$command2run"
    command2run='which kubeadm'
    sudo_command ${MASTERPORTS[$i]} ${STACKED_USER} ${MASTERHOSTS[$i]} "$command2run"

    if [[ -e "$KUBASH_CLUSTER_DIR/join.sh" ]]; then
      rsync $KUBASH_RSYNC_OPTS "ssh -p ${MASTERPORTS[$i]}" $KUBASH_DIR/templates/kube_stacked_init.sh $STACKED_USER@$HOST:/tmp/
      squawk 55 "push_kube_pki_stacked_method  $K8S_user ${MASTERHOSTS[$i]} ${MASTERPORTS[$i]}"
      push_kube_pki_stacked_method ${STACKED_USER} ${MASTERHOSTS[$i]} ${MASTERPORTS[$i]}
      command2run="ls -Rl /etc/kubernetes"
      sudo_command ${MASTERPORTS[$i]} ${STACKED_USER} ${MASTERHOSTS[$i]} "$command2run"
      command2run="rm -fv /etc/kubernetes/kubelet.conf"
      sudo_command ${MASTERPORTS[$i]} ${STACKED_USER} ${MASTERHOSTS[$i]} "$command2run"
      escaped_master=$( echo ${MASTERHOSTS[0]} |sed 's/\./\\./g')
      sedder="s/$escaped_master/$HOST/g"
      command2run='mv /tmp/kube_stacked_init.sh /etc/kubernetes/'
      sudo_command ${MASTERPORTS[$i]} ${STACKED_USER} ${MASTERHOSTS[$i]} "$command2run"
      my_KUBE_INIT="bash /etc/kubernetes/kube_stacked_init.sh ${MASTERHOSTS[0]} ${MASTERNAMES[0]} ${MASTERHOSTS[$i]} ${MASTERNAMES[$i]}"
      squawk 5 "kube init --> $my_KUBE_INIT"
      ssh -n -p ${MASTERPORTS[$i]} ${STACKED_USER}@${HOST} "$my_KUBE_INIT" 2>&1 | tee $etcd_stacked_tmp/${HOST}-rawresults.k8s
    else
      my_KUBE_INIT="kubeadm init --config=/etc/kubernetes/kubeadmcfg.yaml"
      squawk 5 "master kube init --> $my_KUBE_INIT"
      squawk 25 "ssh -n -p ${MASTERPORTS[$i]} ${STACKED_USER}@${HOST} 'bash -l -c which kubeadm'"
      ssh -n -p ${MASTERPORTS[$i]} ${STACKED_USER}@${HOST} "bash -l -c 'which kubeadm'"
      my_grep='kubeadm join .* --token'
      ssh -n -p ${MASTERPORTS[$i]} ${STACKED_USER}@${HOST} "bash -l -c '$my_KUBE_INIT'" 2>&1 | tee $etcd_stacked_tmp/${HOST}-joinrawresults.k8s
      GET_JOIN_CMD="kubeadm token create --print-join-command"
      ssh -n -p ${MASTERPORTS[$i]} ${STACKED_USER}@${HOST} "bash -l -c '$GET_JOIN_CMD'" 2>&1 | tee $etcd_stacked_tmp/${HOST}-rawresults.k8s
      run_join=$(cat $etcd_stacked_tmp/${HOST}-rawresults.k8s \
        | grep -P -- "$my_grep" \
      )
      #run_join=$(cat $etcd_stacked_tmp/${HOST}-rawresults.k8s | grep -P -- "$my_grep")
      join_token=$(cat $etcd_stacked_tmp/${HOST}-rawresults.k8s \
        | grep -P -- "$my_grep" \
        | sed 's/\(.*\)--token\ \(\S*\)\ --discovery-token-ca-cert-hash\ .*/\2/')
      if [[ -z "$run_join" ]]; then
        horizontal_rule
        croak 3  'kubeadm init failed!'
      else
        echo $run_join > $KUBASH_CLUSTER_DIR/join.sh
        echo $join_token > $KUBASH_CLUSTER_DIR/join_token
        master_grab_kube_config ${NAME} ${HOST} ${STACKED_USER} ${MASTERPORTS[$i]}
        grab_kube_pki_stacked_method ${STACKED_USER} ${MASTERHOSTS[$i]} ${MASTERPORTS[$i]}
        squawk 120 "rsync $KUBASH_RSYNC_OPTS ssh -p ${MASTERPORTS[$i]} $KUBASH_DIR/w8s/generic.w8 $STACKED_USER@$HOST:/tmp/"
        rsync $KUBASH_RSYNC_OPTS "ssh -p ${MASTERPORTS[$i]}" $KUBASH_DIR/w8s/generic.w8 $STACKED_USER@$HOST:/tmp/
        command2run='mv /tmp/generic.w8 /root/'
        squawk 155 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${STACKED_USER} ${MASTERHOSTS[$i]} "$command2run"
        command2run='/root/generic.w8 kube-controller kube-system'
        squawk 155 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${STACKED_USER} ${MASTERHOSTS[$i]} "$command2run"
        command2run='/root/generic.w8 kube-scheduler kube-system'
        squawk 155 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${STACKED_USER} ${MASTERHOSTS[$i]} "$command2run"
        command2run='/root/generic.w8 kube-apiserver kube-system'
        squawk 155 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${STACKED_USER} ${MASTERHOSTS[$i]} "$command2run"
        squawk 5 "do_net before other masters"
        w8_kubectl
        do_net
        w8_node $my_node_name
      fi
    fi
  done
  squawk 55 'key nodes'
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == 'node' ]]; then
      squawk 165 'nodes will have certs created by the join command'
    fi
  done <<< "$kubash_hosts_csv_slurped"
  rm -Rf $etcd_stacked_tmp

}

etcd_kubernetes_13_docs_stacked_method () {
  number_limiter=$1
  etcd_stacked_tmp=$(mktemp -d)
  STACKED_USER=root
  set_csv_columns
  etc_count_zero=0
  master_count_zero=0
  node_count_zero=0
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' || "$K8S_role" == 'primary_etcd' ]]; then
      ETCDHOSTS[$etc_count_zero]=$K8S_ip1
      ETCDNAMES[$etc_count_zero]=$K8S_node
      ETCDPORTS[$etc_count_zero]=$K8S_sshPort
      MASTERHOSTS[$master_count_zero]=$K8S_ip1
      MASTERNAMES[$master_count_zero]=$K8S_node
      MASTERPORTS[$master_count_zero]=$K8S_sshPort
      ((++etc_count_zero))
      ((++master_count_zero))
    elif [[ "$K8S_role" == 'node' ]]; then
      NODEHOSTS[$node_count_zero]=$K8S_ip1
      NODENAMES[$node_count_zero]=$K8S_node
      NODEPORTS[$node_count_zero]=$K8S_sshPort
      ((++node_count_zero))
    fi
  done <<< "$kubash_hosts_csv_slurped"
  squawk 11 "2420~ get_major_minor_kube_version $K8S_user ${MASTERHOSTS[0]} ${MASTERNAMES[0]} ${MASTERPORTS[0]}"
  get_major_minor_kube_version $K8S_user ${MASTERHOSTS[0]} ${MASTERNAMES[0]} ${MASTERPORTS[0]}
  determine_api_version

  count_etcd=0
  while IFS="," read -r $csv_columns
  do
    echo "${TAB_1}- \"${K8S_ip1}\"" >> $etcd_stacked_tmp/apiservercertsans.line
    ((++count_etcd))
  done <<< "$kubash_hosts_csv_slurped"

  api_server_cert_sans_line=$(cat $etcd_stacked_tmp/apiservercertsans.line)

  for i in "${!MASTERHOSTS[@]}"; do
    squawk 35 "master-loop ${MASTERHOSTS[$i]} ${MASTERPORTS[$i]}"
    api_server_cert_sans_line=$(cat $etcd_stacked_tmp/apiservercertsans.line)
    HOST=${MASTERHOSTS[$i]}
    NAME=${MASTERNAMES[$i]}
    mkdir -p $etcd_stacked_tmp/${HOST}
    if [ "$i" -eq '0' ]; then
      INITIAL_CLUSTER_STATE=new
    else
      INITIAL_CLUSTER_STATE=existing
    fi
    cat << EOF > $etcd_stacked_tmp/${HOST}/kubeadmcfg.yaml
apiVersion: $kubeadm_apiVersion
kind: $kubeadm_cfg_kind
kubernetesVersion: $KUBERNETES_VERSION
apiServer:
  certSANs:
  - "127.0.0.1"
$api_server_cert_sans_line
controlPlaneEndpoint: "${MASTERHOSTS[0]}:6443"
networking:
  podSubnet: $my_KUBE_CIDR
EOF
    rsync $KUBASH_RSYNC_OPTS "ssh -p ${MASTERPORTS[$i]}" $etcd_stacked_tmp/${HOST}/kubeadmcfg.yaml $STACKED_USER@$HOST:/tmp/
    command2run='mkdir -p /etc/kubernetes/'
    sudo_command ${MASTERPORTS[$i]} ${STACKED_USER} ${MASTERHOSTS[$i]} "$command2run"
    command2run='mv /tmp/kubeadmcfg.yaml /etc/kubernetes/'
    sudo_command ${MASTERPORTS[$i]} ${STACKED_USER} ${MASTERHOSTS[$i]} "$command2run"
    command2run='which kubeadm'
    sudo_command ${MASTERPORTS[$i]} ${STACKED_USER} ${MASTERHOSTS[$i]} "$command2run"

    if [[ -e "$KUBASH_CLUSTER_DIR/master_join.sh" ]]; then
      rsync $KUBASH_RSYNC_OPTS "ssh -p ${MASTERPORTS[$i]}" $KUBASH_CLUSTER_DIR/master_join.sh $STACKED_USER@$HOST:/tmp/
      squawk 55 "push_kube_pki_stacked_method  $K8S_user ${MASTERHOSTS[$i]} ${MASTERPORTS[$i]}"
      push_kube_pki_stacked_method ${STACKED_USER} ${MASTERHOSTS[$i]} ${MASTERPORTS[$i]}
      my_KUBE_INIT="bash -l /tmp/master_join.sh"
      squawk 5 "kube init --> $my_KUBE_INIT"
      ssh -n -p ${MASTERPORTS[$i]} ${STACKED_USER}@${HOST} "$my_KUBE_INIT" 2>&1 | tee $etcd_stacked_tmp/${HOST}-rawresults.k8s
      w8_node $my_node_name
    else
      my_KUBE_INIT="kubeadm init --config=/etc/kubernetes/kubeadmcfg.yaml"
      squawk 5 "master kube init --> $my_KUBE_INIT"
      squawk 25 "ssh -n -p ${MASTERPORTS[$i]} ${STACKED_USER}@${HOST} 'bash -l -c which kubeadm'"
      ssh -n -p ${MASTERPORTS[$i]} ${STACKED_USER}@${HOST} "bash -l -c 'which kubeadm'"
      my_grep='kubeadm join .* --token'
      ssh -n -p ${MASTERPORTS[$i]} ${STACKED_USER}@${HOST} "bash -l -c '$my_KUBE_INIT'" 2>&1 | tee $etcd_stacked_tmp/${HOST}-joinrawresults.k8s
      GET_JOIN_CMD="kubeadm token create --print-join-command"
      ssh -n -p ${MASTERPORTS[$i]} ${STACKED_USER}@${HOST} "bash -l -c '$GET_JOIN_CMD'" 2>&1 | tee $etcd_stacked_tmp/${HOST}-rawresults.k8s
      run_join=$(cat $etcd_stacked_tmp/${HOST}-rawresults.k8s \
        | grep -P -- "$my_grep" \
      )
      #run_join=$(cat $etcd_stacked_tmp/${HOST}-rawresults.k8s | grep -P -- "$my_grep")
      join_token=$(cat $etcd_stacked_tmp/${HOST}-rawresults.k8s \
        | grep -P -- "$my_grep" \
        | sed 's/\(.*\)--token\ \(\S*\)\ --discovery-token-ca-cert-hash\ .*/\2/')
      if [[ -z "$run_join" ]]; then
        horizontal_rule
        croak 3  'kubeadm init failed!'
      else
        echo $run_join > $KUBASH_CLUSTER_DIR/join.sh
        echo $run_join > $KUBASH_CLUSTER_DIR/master_join.sh
        if [[ $KUBE_MINOR_VER -lt 16 ]]; then
          sed -i 's/$/ --experimental-control-plane/' $KUBASH_CLUSTER_DIR/master_join.sh
        elif [[ $KUBE_MINOR_VER -gt 15 ]]; then
          sed -i 's/$/ --control-plane/' $KUBASH_CLUSTER_DIR/master_join.sh
        fi
        echo $join_token > $KUBASH_CLUSTER_DIR/join_token
        master_grab_kube_config ${NAME} ${HOST} ${STACKED_USER} ${MASTERPORTS[$i]}
        grab_kube_pki_stacked_method ${STACKED_USER} ${MASTERHOSTS[$i]} ${MASTERPORTS[$i]}
        squawk 120 "rsync $KUBASH_RSYNC_OPTS ssh -p ${MASTERPORTS[$i]} $KUBASH_DIR/w8s/generic.w8 $STACKED_USER@$HOST:/tmp/"
        rsync $KUBASH_RSYNC_OPTS "ssh -p ${MASTERPORTS[$i]}" $KUBASH_DIR/w8s/generic.w8 $STACKED_USER@$HOST:/tmp/
        command2run='mv /tmp/generic.w8 /root/'
        squawk 155 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${STACKED_USER} ${MASTERHOSTS[$i]} "$command2run"
        command2run='/root/generic.w8 kube-controller kube-system'
        squawk 155 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${STACKED_USER} ${MASTERHOSTS[$i]} "$command2run"
        command2run='/root/generic.w8 kube-scheduler kube-system'
        squawk 155 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${STACKED_USER} ${MASTERHOSTS[$i]} "$command2run"
        command2run='/root/generic.w8 kube-apiserver kube-system'
        squawk 155 "$command2run"
        sudo_command ${MASTERPORTS[$i]} ${STACKED_USER} ${MASTERHOSTS[$i]} "$command2run"
        squawk 5 "do_net before other masters"
        w8_kubectl
        do_net
        w8_node $my_node_name
      fi
    fi
  done
  squawk 55 'key nodes'
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == 'node' ]]; then
      squawk 165 'nodes will have certs created by the join command'
    fi
  done <<< "$kubash_hosts_csv_slurped"
  rm -Rf $etcd_stacked_tmp
}

scanner () {
  squawk 17 "scanner $@"
  node_ip=$1
  node_port=$2
  removestalekeys $node_ip
  ssh-keyscan -p $node_port $node_ip >> ~/.ssh/known_hosts
}

scanlooper () {
  squawk 5 "scanlooper"
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    scanner $K8S_ip1 $K8S_sshPort
  done <<< "$kubash_hosts_csv_slurped"
}

ntpsync_in_parallel () {
  squawk 2 'syncing ntp on all hosts'
  ntp_sync_tmp_para=$(mktemp -d --suffix='.para.tmp')
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    squawk 103 "ntp sync $K8S_user@$K8S_ip1"
    MY_NTP_SYNC="hostname && timedatectl set-ntp true"
    squawk 5 "ssh -n -p $K8S_sshPort $K8S_provisionerUser@$K8S_ip1 \"$MY_NTP_SYNC\""
    echo "ssh -n -p $K8S_sshPort $K8S_provisionerUser@$K8S_ip1 \"$MY_NTP_SYNC\""\
        >> $ntp_sync_tmp_para/hopper
  done < $KUBASH_HOSTS_CSV
  while IFS="," read -r $csv_columns
  do
    squawk 103 "ntp sync $K8S_user@$K8S_ip1"
    MY_NTP_SYNC="hostname && timedatectl status "
    squawk 5 "ssh -n -p $K8S_sshPort $K8S_provisionerUser@$K8S_ip1 \"$MY_NTP_SYNC\""
    echo "ssh -n -p $K8S_sshPort $K8S_provisionerUser@$K8S_ip1 \"$MY_NTP_SYNC\""\
        >> $ntp_sync_tmp_para/hopper2
  done < $KUBASH_HOSTS_CSV
  while IFS="," read -r $csv_columns
  do
    squawk 103 "ntp sync $K8S_user@$K8S_ip1"
    MY_NTP_SYNC="hostname && date"
    squawk 5 "ssh -n -p $K8S_sshPort $K8S_provisionerUser@$K8S_ip1 \"$MY_NTP_SYNC\""
    echo "ssh -n -p $K8S_sshPort $K8S_provisionerUser@$K8S_ip1 \"$MY_NTP_SYNC\""\
        >> $ntp_sync_tmp_para/hopper3
  done < $KUBASH_HOSTS_CSV

  if [[ "$VERBOSITY" -gt "9" ]] ; then
    cat $ntp_sync_tmp_para/hopper
  fi
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    $PARALLEL  -j $PARALLEL_JOBS -- < $ntp_sync_tmp_para/hopper
    $PARALLEL  -j $PARALLEL_JOBS -- < $ntp_sync_tmp_para/hopper2
    $PARALLEL  -j $PARALLEL_JOBS -- < $ntp_sync_tmp_para/hopper3
  else
    squawk 10 "batch --> timedatectl set-ntp true <-- batch"
    bash $ntp_sync_tmp_para/hopper
    squawk 10 "batch --> timedatectl status"
    bash $ntp_sync_tmp_para/hopper2
    squawk 10 "date"
    bash $ntp_sync_tmp_para/hopper3
  fi
  rm -Rf $ntp_sync_tmp_para
  squawk 90 "finished ntpsync section"
}

do_nodes () {
  do_nodes_in_parallel
}

do_nodes_in_parallel () {
  do_nodes_tmp_para=$(mktemp -d)
  touch $do_nodes_tmp_para/hopper
  squawk 3 " do_nodes_in_parallel"
  if [[ -z "$kubash_hosts_csv_slurped" ]]; then
    hosts_csv_slurp
  fi
  countzero_do_nodes=0
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "node" || "$K8S_role" == "ingress" || "$K8S_role" == "storage" ]]; then
      squawk 81 " K8S_role NODE"
      squawk 81 " K8S_role $K8S_role $K8S_ip1 $K8S_user $K8S_sshPort"
      echo "kubash -n $KUBASH_CLUSTER_NAME node_join --node-join-name $K8S_node --node-join-ip $K8S_ip1 --node-join-user $K8S_SU_USER --node-join-port $K8S_sshPort --node-join-role node" \
        >> $do_nodes_tmp_para/hopper
    else
      squawk 91 " K8S_role NOT NODE"
      squawk 91 " K8S_role $K8S_role $K8S_ip1 $K8S_user $K8S_sshPort"
    fi
    ((++countzero_do_nodes))
    squawk 3 " count $countzero_do_nodes"
  done <<< "$kubash_hosts_csv_slurped"

  if [[ "$VERBOSITY" -gt "9" ]] ; then
    cat $do_nodes_tmp_para/hopper
  fi
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    $PARALLEL  -j $PARALLEL_JOBS -- < $do_nodes_tmp_para/hopper
  else
    bash $do_nodes_tmp_para/hopper
  fi
  rm -Rf $do_nodes_tmp_para
  taint_all_storage
  #mount_all_iscsi_targets
}

process_hosts_csv () {
  squawk 3 "ntp sync in parallel"
  ntpsync_in_parallel
  squawk 3 "2644~ process_hosts_csv"
  primary_master_count=0
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "primary_master" ]]; then
      squawk 3 "get major minor version for primary master get_major_minor_kube_version $K8S_user $K8S_ip1  $K8S_node $K8S_sshPort"
      get_major_minor_kube_version $K8S_user $K8S_ip1  $K8S_node $K8S_sshPort
      let primary_master_count++ 
      echo "primary_master_count $primary_master_count"
    else 
      squawk 103 "not primary_master"
    fi
  done <<< "$kubash_hosts_csv_slurped"
  squawk 11 "Primary master count is $primary_master_count "
  if [[ $primary_master_count == 1 ]]; then
      squawk 103 "primary_master_count is one, good"
  elif [[ $primary_master_count -gt 1 ]]; then
      croak 1  "Too many primary masters there should only be one. Check your yaml and try again, highlander."
  elif [[ $primary_master_count -lt 1 ]]; then
      croak 1  "No primary masters there should be one. Check your yaml and try again."
  else
      croak 1  "No primary masters there should be one. Check your yaml and try again."
  fi
  if [[ $KUBE_MAJOR_VER == 1 ]]; then
    squawk 101 'Major Version 1'
    squawk 53  "$KUBE_MAJOR_VER.$KUBE_MINOR_VER supported"
    if [[ $KUBE_MINOR_VER == 12 ]]; then
      if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
        etcd_kubernetes_12_docs_stacked_method
      else
        etcd_kubernetes_12_ext_etcd_method
      fi
    elif [[ $KUBE_MINOR_VER == 13 ]]; then
      if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
        etcd_kubernetes_13_docs_stacked_method
      else
        etcd_kubernetes_13_ext_etcd_method
      fi
    elif [[ $KUBE_MINOR_VER == 14 ]]; then
      if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
        etcd_kubernetes_docs_stacked_method
      else
        etcd_kubernetes_ext_etcd_method
      fi
    elif [[ $KUBE_MINOR_VER == 15 ]]; then
      if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
        etcd_kubernetes_docs_stacked_method
      else
        etcd_kubernetes_ext_etcd_method
      fi
    else
      if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
        etcd_kubernetes_docs_stacked_method
      else
        etcd_kubernetes_ext_etcd_method
      fi
    fi
  elif [[ $KUBE_MAJOR_VER == 2 ]]; then
      croak 3  "$KUBE_MAJOR_VER.$KUBE_MINOR_VER is two and not supported at this time"
  else
    croak 3  "Kube Major version = '$KUBE_MAJOR_VER' is not 1. Kube Minor version = $KUBE_MINOR_VER. Which is not supported at this time."
  fi
  # spin up nodes
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    do_nodes_in_parallel
  else
    do_nodes
  fi
}

initialize () {
  squawk 1 " initialize"
  check_csv
  if [[ -z "$kubash_hosts_csv_slurped" ]]; then
    hosts_csv_slurp
  fi
  scanlooper
  check_coreos
  process_hosts_csv
}

kubeadm2ha_initialize () {
  squawk 1 "kubeadm2ha initialize"
  check_csv
  if [[ -e "$KUBASH_ANSIBLE_HOSTS" ]]; then
    squawk 1 'Hosts file found, not overwriting'
  else
    write_ansible_kubeadm2ha_hosts
  fi
  ansible-playbook \
    -f $PARALLEL_JOBS \
    -i $KUBASH_ANSIBLE_HOSTS \
    $KUBASH_DIR/submodules/kubeadm2ha/ansible/cluster-setup.yaml
  ansible-playbook \
    -f $PARALLEL_JOBS \
    -i $KUBASH_ANSIBLE_HOSTS \
    $KUBASH_DIR/submodules/kubeadm2ha/ansible/cluster-dashboard.yaml
 git@gitlab.com:monitaur/bin.git ansible-playbook \
    -f $PARALLEL_JOBS \
    -i $KUBASH_ANSIBLE_HOSTS \
    $KUBASH_DIR/submodules/kubeadm2ha/ansible/cluster-load-balanced.yaml
  ansible-playbook \
    -f $PARALLEL_JOBS \
    -i $KUBASH_ANSIBLE_HOSTS \
    $KUBASH_DIR/submodules/kubeadm2ha/ansible/etcd-operator.yaml
  ansible-playbook \
    -f $PARALLEL_JOBS \
    -i $KUBASH_ANSIBLE_HOSTS \
    $KUBASH_DIR/submodules/kubeadm2ha/ansible/local-access.yaml
}

kubespray_initialize () {
  squawk 1 "kubespray initialize"
  check_csv
  if [[ -e "$KUBASH_KUBESPRAY_HOSTS" ]]; then
    squawk 1 'Hosts file found, not overwriting'
  else
    write_ansible_kubespray_hosts
  fi
  #yes yes|ansible-playbook \
    #-i $KUBASH_KUBESPRAY_HOSTS \
    #-e kube_version=$KUBERNETES_VERSION \
    #$KUBASH_DIR/submodules/kubespray/reset.yml
  ansible-playbook \
    -i $KUBASH_KUBESPRAY_HOSTS \
    -e '{ kubeadm_enabled: True }' \
    $KUBASH_DIR/submodules/kubespray/cluster.yml
}

openshift_initialize () {
  squawk 1 "openshift initialize"
  check_csv
  if [[ -e "$KUBASH_ANSIBLE_HOSTS" ]]; then
    squawk 1 'Hosts file found, not overwriting'
  else
    write_ansible_openshift_hosts
  fi
  ansible-playbook \
    -i $KUBASH_ANSIBLE_HOSTS \
    $KUBASH_DIR/submodules/openshift-ansible/playbooks/prerequisites.yml
  ansible-playbook \
    -i $KUBASH_ANSIBLE_HOSTS \
    $KUBASH_DIR/submodules/openshift-ansible/playbooks/deploy_cluster.yml
}

do_coreos_initialization () {
  CNI_VERSION="v0.7.5"
  CRICTL_VERSION="v1.12.0"
  #RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
  RELEASE=$KUBERNETES_VERSION
  CORETMP=$KUBASH_DIR/tmp/$RELEASE
  mkdir -p $CORETMP
  cd $CORETMP

  do_command_in_parallel_on_os 'coreos' "mkdir -p /opt/cni/bin"
  do_command_in_parallel_on_os 'coreos' "mkdir -p /etc/kubernetes/pki"
  if [[ -f "$CORETMPcni-plugins-amd64-${CNI_VERSION}.tgz" ]]; then
    squawk 23 "File already retreived skipping $CORETMP/cni-plugins-amd64-${CNI_VERSION}.tgz"
  else
    wget -c "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-amd64-${CNI_VERSION}.tgz"
  fi
  copy_in_parallel_to_os "coreos" $CORETMP/cni-plugins-amd64-${CNI_VERSION}.tgz /tmp/
  #rm $CORETMP/cni-plugins-amd64-${CNI_VERSION}.tgz
  do_command_in_parallel_on_os "coreos" "tar -C /opt/cni/bin -xzf /tmp/cni-plugins-amd64-${CNI_VERSION}.tgz"
  do_command_in_parallel_on_os "coreos" "rm -f /tmp/cni-plugins-amd64-${CNI_VERSION}.tgz"

  do_command_in_parallel_on_os "coreos" "mkdir -p /opt/bin"

  if [[ -f "$CORETMP/kubeadm" ]]; then
    squawk 23 "kubeadm files already retreived skipping "
  else
    #curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${RELEASE}/bin/linux/amd64/{kubeadm,kubelet,kubectl}
    wget --max-redirect=20 -c https://storage.googleapis.com/kubernetes-release/release/${RELEASE}/bin/linux/amd64/{kubeadm,kubelet,kubectl}
  fi
  # cd /opt/bin
  copy_in_parallel_to_os "coreos" $CORETMP/kubeadm /tmp/
  do_command_in_parallel_on_os "coreos" "mv /tmp/kubeadm /opt/bin/"
  #rm $CORETMP/kubeadm
  copy_in_parallel_to_os "coreos" $CORETMP/kubelet /tmp/
  do_command_in_parallel_on_os "coreos" "mv /tmp/kubelet /opt/bin/"
  #rm $CORETMP/kubelet
  copy_in_parallel_to_os "coreos" $CORETMP/kubectl /tmp/
  do_command_in_parallel_on_os "coreos" "mv /tmp/kubectl /opt/bin/"
  #rm $CORETMP/kubectl
  do_command_in_parallel_on_os "coreos" "cd /opt/bin; chmod +x {kubeadm,kubelet,kubectl}"

  if [[ -e "$CORETMP/kubelet.service" ]]; then
    squawk 9 "$CORETMP/kubelet.service already retrieved"
  else
    squawk 9 "wget -c https://raw.githubusercontent.com/kubernetes/kubernetes/${RELEASE}/build/debs/kubelet.service"
    wget -c https://raw.githubusercontent.com/kubernetes/kubernetes/${RELEASE}/build/debs/kubelet.service
    sed -i 's:/usr/bin:/opt/bin:g' $CORETMP/kubelet.service
  fi
  copy_in_parallel_to_os "coreos" $CORETMP/kubelet.service /tmp/kubelet.service
  do_command_in_parallel_on_os "coreos" "mv /tmp/kubelet.service /etc/systemd/system/kubelet.service"
  rm $CORETMP/kubelet.service
  do_command_in_parallel_on_os "coreos" "mkdir -p /etc/systemd/system/kubelet.service.d"
  if [[ -e "$CORETMP/10-kubeadm.conf" ]]; then
    squawk 9 "$CORETMP/10-kubeadm.conf already retrieved"
  else
    wget -c "https://raw.githubusercontent.com/kubernetes/kubernetes/${RELEASE}/build/debs/10-kubeadm.conf"
    sed -i 's:/usr/bin:/opt/bin:g' $CORETMP/10-kubeadm.conf
  fi
  copy_in_parallel_to_os "coreos" $CORETMP/10-kubeadm.conf /tmp/10-kubeadm.conf
  do_command_in_parallel_on_os "coreos" " mv /tmp/10-kubeadm.conf /etc/systemd/system/kubelet.service.d/10-kubeadm.conf"
  rm $CORETMP/10-kubeadm.conf

  do_command_in_parallel_on_os "coreos" " systemctl restart docker.service ; systemctl enable docker.service"

  #do_command_in_parallel_on_os "coreos" "systemctl unmask kubelet.service ; systemctl restart kubelet.service ; systemctl enable kubelet.service"
  do_command_in_parallel_on_os "coreos" "systemctl restart kubelet.service ; systemctl enable kubelet.service"

  #rmdir $CORETMP
}
