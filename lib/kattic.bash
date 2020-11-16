#!/usr/bin/env bash

demo () {
  do_postgres
  do_rabbitmq
  do_percona
  do_jupyter
  do_mongodb
  do_jenkins
  do_kafka
  do_redis
  do_minio
}

do_refresh () {
  cd $KUBASH_DIR
  rm -f bin/kubectl; make kubectl
  rm -f bin/helm; make helm
}

do_redis () {
  cd $KUBASH_DIR/submodules/openebs/k8s/demo/redis
  kubectl --kubeconfig=$KUBECONFIG apply -f \
   redis-statefulset.yml
}

do_postgres () {
  cd $KUBASH_DIR/submodules/openebs/k8s/demo/crunchy-postgres
  KUBECONFIG=$KUBECONFIG bash run.sh
}

do_rabbitmq () {
  cd $KUBASH_DIR/submodules/openebs/k8s/demo/rabbitmq
  KUBECONFIG=$KUBECONFIG bash run.sh
}

do_percona () {
  cd $KUBASH_DIR/submodules/openebs/k8s/demo/percona
  kubectl --kubeconfig=$KUBECONFIG apply -f \
   demo-percona-mysql-pvc.yaml
}

do_jupyter () {
  cd $KUBASH_DIR/submodules/openebs/k8s/demo/jupyter
  kubectl --kubeconfig=$KUBECONFIG apply -f \
   demo-jupyter-openebs.yaml
}

do_mongodb () {
  cd $KUBASH_DIR/submodules/openebs/k8s/demo/mongodb
  kubectl --kubeconfig=$KUBECONFIG apply -f \
   mongo-statefulset.yml
}

do_jenkins () {
  cd $KUBASH_DIR/submodules/openebs/k8s/demo/jenkins
  kubectl --kubeconfig=$KUBECONFIG apply -f \
   jenkins.yml
}

do_minio () {
  cd $KUBASH_DIR/submodules/openebs/k8s/demo/minio
  kubectl --kubeconfig=$KUBECONFIG apply -f \
   minio.yaml
}

do_kafka () {
  squawk 1 " do_kafka"
  KUBECONFIG=$KUBECONFIG \
  helm \
    repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator

  KUBECONFIG=$KUBECONFIG \
  helm install \
    my-kafka \
    incubator/kafka \
    --set persistence.storageClass=openebs-kafka
}

do_searchlight () {
  squawk 1 " do_searchlight"
  kubectl --kubeconfig=$KUBECONFIG apply -f \
    $KUBASH_DIR/templates/searchlight.yaml
}

do_dashboard () {
  squawk 1 " do_dashboard"
  kubectl --kubeconfig=$KUBECONFIG \
    apply -f \
    https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
}

do_tiller () {
  squawk 1 " do_tiller"
  #kubectl --kubeconfig=$KUBECONFIG create serviceaccount tiller --namespace kube-system
  kubectl --kubeconfig=$KUBECONFIG create -f $KUBASH_DIR/tiller/rbac-tiller-config.yaml
  sleep 5
  KUBECONFIG=$KUBECONFIG \
   helm init --service-account tiller
  KUBECONFIG=$KUBECONFIG \
  $KUBASH_DIR/w8s/tiller.w8
}

helm_three () {
  helmthreeTMP=$(mktemp -d)
  cd $helmthreeTMP
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
  chmod 700 get_helm.sh
  ./get_helm.sh
  cd
  rm -Rf $helmthreeTMP
}

inst_kubedb_helm () {
  KUBECONFIG=$KUBECONFIG \
  helm repo add appscode https://charts.appscode.com/stable/
  KUBECONFIG=$KUBECONFIG \
  helm repo update
  KUBECONFIG=$KUBECONFIG \
  helm install \
    kubedb-operator \
    appscode/kubedb \
    --namespace kube-system \
    --version 0.11.0
  KUBECONFIG=$KUBECONFIG \
  $KUBASH_DIR/w8s/generic.w8 kubedb-operator kube-system
  # It seems we still need to wait further
  sleep 45
  KUBECONFIG=$KUBECONFIG \
  helm install \
    kubedb-catalog \
    appscode/kubedb-catalog \
    --version 0.11.0 \
    --namespace kube-system
}

dotfiles_install () {
  squawk 1 ' Adjusting dotfiles'
  touch $HOME/.zshrc
  touch $HOME/.bashrc
  # make a bin dir in $HOME and add it to path
  chkdir $KUBASH_BIN
  LINE_TO_ADD="$(printf "export PATH=%s:\$PATH" $KUBASH_BIN)"
  TARGET_FILE_FOR_ADD=$HOME/.bashrc
  check_if_line_exists || add_line_to
  TARGET_FILE_FOR_ADD=$HOME/.zshrc
  check_if_line_exists || add_line_to

  LINE_TO_ADD="export GOPATH=$GOPATH"
  TARGET_FILE_FOR_ADD=$HOME/.bashrc
  check_if_line_exists || add_line_to
  TARGET_FILE_FOR_ADD=$HOME/.zshrc
  check_if_line_exists || add_line_to
}

do_grab () {
  squawk 1 " do_grab"
  do_grab_master_count=0
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "primary_master" ]]; then
      if [[ "$do_grab_master_count" -lt "1" ]]; then
        master_grab_kube_config $K8S_node $K8S_ip1 $K8S_provisionerUser $K8S_sshPort
      fi
      ((++do_grab_master_count))
    fi
  done < $KUBASH_HOSTS_CSV
}

do_etcd () {
  squawk 3 " do_etcd"
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
  write_kubeadmcfg_yaml

  countprimarymaster=0
  set_csv_columns
  # First find the primary etcd master
  while IFS="," read -r $csv_columns
  do
    if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
      if [[ "$K8S_role" == "primary_master"  ]]; then
        if [[ "$countprimarymaster" -eq "0" ]]; then
          ((++countprimarymaster))
          prep_init_etcd $K8S_provisionerUser $K8S_ip1 $K8S_node $K8S_sshPort
          # save these values for clusterwide usage
          #kubash -n $KUBASH_CLUSTER_NAME --verbosity=$VERBOSITY prepetcd $K8S_provisionerUser $K8S_ip1 $K8S_node $K8S_sshPort
        else
          croak 3  'there should only be one primary master'
        fi
      fi
    else
      if [[ "$K8S_role" == "primary_etcd"  ]]; then
        if [[ "$countprimarymaster" -eq "0" ]]; then
          ((++countprimarymaster))
          prep_init_etcd $K8S_provisionerUser $K8S_ip1 $K8S_node $K8S_sshPort
          # save these values for clusterwide usage
          #kubash -n $KUBASH_CLUSTER_NAME --verbosity=$VERBOSITY prepetcd $K8S_provisionerUser $K8S_ip1 $K8S_node $K8S_sshPort
        else
          croak 3  'there should only be one primary etcd'
        fi
      fi
    fi
  done <<< "$kubash_hosts_csv_slurped"

  prepTMP=$(mktemp -d)
  touch $prepTMP/hopper
  # Then prep the other etcd hosts
  while IFS="," read -r $csv_columns
  do
    #squawk 3 "kubash -n $KUBASH_CLUSTER_NAME --verbosity=$VERBOSITY prepetcd $K8S_provisionerUser $K8S_ip1 $K8S_node $K8S_sshPort"
    #echo     "kubash -n $KUBASH_CLUSTER_NAME --verbosity=$VERBOSITY prepetcd $K8S_provisionerUser $K8S_ip1 $K8S_node $K8S_sshPort" >> $prepTMP/hopper
    if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
      #if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' || "$K8S_role" == 'primary_etcd' ]]; then
      #if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_etcd' ]]; then
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_etcd' ]]; then
          #squawk 19 "$K8S_node $K8S_role $K8S_cpuCount $K8S_Memory $K8S_network1 $K8S_mac1 $K8S_ip1 $K8S_provisionerHost $K8S_provisionerUser $K8S_sshPort $K8S_provisionerBasePath $K8S_os $K8S_virt $K8S_network2 $K8S_mac2 $K8S_ip2 $K8S_network3 $K8S_mac3 $K8S_ip3"
          squawk 3 "kubash -n $KUBASH_CLUSTER_NAME --verbosity=$VERBOSITY prepetcd $K8S_provisionerUser $K8S_ip1 $K8S_node $K8S_sshPort"
          echo     "kubash -n $KUBASH_CLUSTER_NAME --verbosity=$VERBOSITY prepetcd $K8S_provisionerUser $K8S_ip1 $K8S_node $K8S_sshPort" >> $prepTMP/hopper
      fi
    else
      #if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' || "$K8S_role" == 'primary_etcd' ]]; then
      #if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'primary_etcd' ]]; then
      #if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' ]]; then
      if [[ "$K8S_role" == 'etcd' || "$K8S_role" == 'master' || "$K8S_role" == 'primary_master' ]]; then
          squawk 3 "kubash -n $KUBASH_CLUSTER_NAME --verbosity=$VERBOSITY prepetcd $K8S_provisionerUser $K8S_ip1 $K8S_node $K8S_sshPort"
          echo     "kubash -n $KUBASH_CLUSTER_NAME --verbosity=$VERBOSITY prepetcd $K8S_provisionerUser $K8S_ip1 $K8S_node $K8S_sshPort" >> $prepTMP/hopper
      fi
    fi
  done <<< "$kubash_hosts_csv_slurped"
  if [[ "$VERBOSITY" -gt "9" ]] ; then
    cat $prepTMP/hopper
  fi
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    #$PARALLEL  -j $PARALLEL_JOBS -- < $prepTMP/hopper
    bash $prepTMP/hopper
  else
    bash $prepTMP/hopper
  fi
  rm -Rf $prepTMP

  countprimarymaster=0
  set_csv_columns
  # First find the primary etcd master
  while IFS="," read -r $csv_columns
  do
    if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
      if [[ "$K8S_role" == "primary_master"  ]]; then
        if [[ "$countprimarymaster" -eq "0" ]]; then
          ((++countprimarymaster))
          kubash -n $KUBASH_CLUSTER_NAME --verbosity=$VERBOSITY prepetcd $K8S_provisionerUser $K8S_ip1 $K8S_node $K8S_sshPort
          finalize_etcd_gen_certs $K8S_sshPort $K8S_provisionerUser $K8S_ip1
        else
          croak 3  'there should only be one primary master'
        fi
      fi
    else
      if [[ "$K8S_role" == "primary_etcd"  ]]; then
        if [[ "$countprimarymaster" -eq "0" ]]; then
          ((++countprimarymaster))
          kubash -n $KUBASH_CLUSTER_NAME --verbosity=$VERBOSITY prepetcd $K8S_provisionerUser $K8S_ip1 $K8S_node $K8S_sshPort
          finalize_etcd_gen_certs $K8S_sshPort $K8S_provisionerUser $K8S_ip1
        else
          croak 3  'there should only be one primary etcd'
        fi
      fi
    fi
  done <<< "$kubash_hosts_csv_slurped"

  squawk 75 "create the manifests"
  command2run="kubeadm alpha phase etcd local --config=/etc/kubernetes/kubeadmcfg.yaml"
  if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
    do_command_in_parallel_on_role "primary_master"          "$command2run"
    do_command_in_parallel_on_role "primary_etcd"            "$command2run"
    do_command_in_parallel_on_role "master"                  "$command2run"
    do_command_in_parallel_on_role "etcd"                    "$command2run"
  else
    do_command_in_parallel_on_role "primary_etcd"            "$command2run"
    do_command_in_parallel_on_role "etcd"                    "$command2run"
  fi
  squawk 5 'sleep 33'
  sleep 33
}

do_primary_master () {
  squawk 3 " do_primary_master"
  do_master_count=0

  if [[ -z "$kubash_hosts_csv_slurped" ]]; then
    hosts_csv_slurp
  fi
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "primary_master" ]]; then
      if [[ "$do_master_count" -lt "1" ]]; then
        squawk 9 "master_init_join $K8S_node $K8S_ip1 $K8S_provisionerUser $K8S_sshPort"
        master_init_join $K8S_node $K8S_ip1 $K8S_SU_USER $K8S_sshPort
      else
  echo 'There should only be one init master! Skipping this master'
        echo "master_init_join $K8S_node $K8S_ip1 $K8S_SU_USER $K8S_sshPort"
      fi
      ((++do_master_count))
    fi
  done <<< "$kubash_hosts_csv_slurped"
}

do_masters () {
  squawk 3 " do_masters"

  # hijack
  do_masters_in_parallel
}

do_scale_up_kube_dns () {
  squawk 3 "do_scale_up_kube_dns"
  do_scale_up_kube_dns=0

  if [[ -z "$kubash_hosts_csv_slurped" ]]; then
    hosts_csv_slurp
  fi
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "master" || "$K8S_role" == "primary_master" ]]; then
    ((++do_scale_up_kube_dns))
    fi
  done <<< "$kubash_hosts_csv_slurped"

  kubectl scale --replicas=$do_scale_up_kube_dns -n kube-system  deployment/kube-dns
}

do_masters_in_parallel () {
  squawk 3 " do_masters_in_parallel"
  do_master_count=0


  do_master_tmp=$(mktemp -d)
  touch $do_master_tmp/hopper
  touch $do_master_tmp/hopper2
  if [[ -z "$kubash_hosts_csv_slurped" ]]; then
    hosts_csv_slurp
  fi
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    # get major minor vers
    if [[ "$K8S_role" == "primary_master" ]]; then
      get_major_minor_kube_version $K8S_user $K8S_ip1  $K8S_node $K8S_sshPort
      break
    fi
  done
  #command2run='sudo  rm /etc/kubernetes/pki/apiserver.crt'
  #do_command_in_parallel_on_role "master" "$command2run"
  if [[ -e "$KUBASH_CLUSTER_DIR/endpoints.line" ]]; then
    if [[ $KUBE_MAJOR_VER -eq 1 ]]; then
      squawk 20 'Major Version 1'
      if [[ $KUBE_MINOR_VER -lt 9 ]]; then
        squawk 9 "$KUBE_MAJOR_VER.$KUBE_MINOR_VER is too old may not ever be supported"
        exit 1
      elif [[ $KUBE_MINOR_VER -gt 18 ]]; then
        squawk 9 "$KUBE_MAJOR_VER.$KUBE_MINOR_VER is too new and is not supported yet"
        exit 1
      elif [[ $KUBE_MINOR_VER -eq 12 ]]; then
        squawk 12 "$KUBE_MAJOR_VER.$KUBE_MINOR_VER supported"
        kubeadmin_config_tmp=$(mktemp)
        my_master_ip=$my_master_ip \
        KUBERNETES_VERSION=$( cat $KUBASH_CLUSTER_DIR/kubernetes_version) \
        load_balancer_ip=$( cat $KUBASH_CLUSTER_DIR/kube_master1) \
        my_KUBE_CIDR=$my_KUBE_CIDR \
        ENDPOINTS_LINES=$( cat $KUBASH_CLUSTER_DIR/${K8S_node}endpoints.line ) \
        envsubst  < $KUBASH_DIR/templates/kubeadm-config-1.12.yaml \
          > $kubeadmin_config_tmp
      elif [[ $KUBE_MINOR_VER -gt 15 ]]; then
        squawk 12 "$KUBE_MAJOR_VER.$KUBE_MINOR_VER supported"
        kubeadmin_config_tmp=$(mktemp)
        my_master_ip=$my_master_ip \
        KUBERNETES_VERSION=$( cat $KUBASH_CLUSTER_DIR/kubernetes_version) \
        load_balancer_ip=$( cat $KUBASH_CLUSTER_DIR/kube_master1) \
        my_KUBE_CIDR=$my_KUBE_CIDR \
        ENDPOINTS_LINES=$( cat $KUBASH_CLUSTER_DIR/${K8S_node}endpoints.line ) \
        envsubst  < $KUBASH_DIR/templates/kubeadm-config-1.16.yaml \
          > $kubeadmin_config_tmp
      fi
    elif [[ $MAJOR_VER -eq 0 ]]; then
      croak 3 'Major Version 0 unsupported'
    else
      croak 3 'Major Version Unknown'
    fi
    squawk 5 "copy_in_parallel_to_role master '$kubeadmin_config_tmp' '/tmp/config.yaml'"
    copy_in_parallel_to_role master "$kubeadmin_config_tmp" "/tmp/config.yaml"
    rm $kubeadmin_config_tmp
  fi
  command2run='systemctl stop kubectl'
  do_command_in_parallel_on_role "master" "$command2run"
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "master" ]]; then
      if [[ -e "$KUBASH_CLUSTER_DIR/endpoints.line" ]]; then
        my_KUBE_INIT="PATH=$K8S_SU_PATH $PSEUDO kubeadm init $KUBEADMIN_IGNORE_PREFLIGHT_CHECKS --config=/tmp/config.yaml"
        squawk 5 "$my_KUBE_INIT"
        echo "ssh -n $K8S_SU_USER@$K8S_ip1 '$my_KUBE_INIT'" >> $do_master_tmp/hopper
      else
        my_KUBE_INIT="PATH=$K8S_SU_PATH $PSEUDO kubeadm init $KUBEADMIN_IGNORE_PREFLIGHT_CHECKS --pod-network-cidr=$my_KUBE_CIDR"
        squawk 5 "$my_KUBE_INIT"
        echo "ssh -n $K8S_SU_USER@$K8S_ip1 '$my_KUBE_INIT'" >> $do_master_tmp/hopper
      fi
    fi
  done <<< "$kubash_hosts_csv_slurped"
  command2run='systemctl start kubectl'
  do_command_in_parallel_on_role "master" "$command2run"
  if [[ "$VERBOSITY" -gt "9" ]] ; then
    cat $do_master_tmp/hopper
  fi
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    $PARALLEL  -j $PARALLEL_JOBS -- < $do_master_tmp/hopper
  else
    bash $do_master_tmp/hopper
  fi
  rm -Rf $do_master_tmp
  if [[ -e "$KUBASH_CLUSTER_DIR/endpoints.line" ]]; then
    do_command_in_parallel_on_role "master" "rm -f /tmp/config.yaml"
  fi
  #do_scale_up_kube_dns
}

do_provision_test () {
  squawk 3 " do_provision_test $@"
  if [[ -z "$kubash_provision_csv_slurped" ]]; then
    provision_csv_slurp
  fi
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    echo "K8S_node=$K8S_node
K8S_role=$K8S_role
K8S_cpuCount=$K8S_cpuCount
K8S_Memory=$K8S_Memory
K8S_sshPort=$K8S_sshPort
K8S_network1=$K8S_network1
K8S_mac1=$K8S_mac1
K8S_ip1=$K8S_ip1
K8S_routingprefix1=$K8S_routingprefix1
K8S_subnetmask1=$K8S_subnetmask1
K8S_broadcast1=$K8S_broadcast1
K8S_gateway1=$K8S_gateway1
K8S_provisionerHost=$K8S_provisionerHost
K8S_provisionerUser=$K8S_provisionerUser
K8S_provisionerPort=$K8S_provisionerPort
K8S_provisionerBasePath=$K8S_provisionerBasePath
K8S_os=$K8S_os
K8S_virt=$K8S_virt
K8S_network2=$K8S_network2
K8S_mac2=$K8S_mac2
K8S_ip2=$K8S_ip2
K8S_routingprefix2=$K8S_routingprefix2
K8S_subnetmask2=$K8S_subnetmask2
K8S_broadcast2=$K8S_broadcast2
K8S_gateway2=$K8S_gateway2
K8S_network3=$K8S_network3
K8S_mac3=$K8S_mac3
K8S_ip3=$K8S_ip3
K8S_routingprefix3=$K8S_routingprefix3
K8S_subnetmask3=$K8S_subnetmask3
K8S_broadcast3=$K8S_broadcast3
K8S_gateway3=$K8S_gateway3
K8S_iscsitarget=$K8S_iscsitarget
K8S_iscsichapusername=$K8S_iscsichapusername
K8S_iscsichappassword=$K8S_iscsichappassword
K8S_iscsihost=$K8S_iscsihost"
  done <<< "$kubash_provision_csv_slurped"
}

do_test () {
  squawk 3 " do_test $@"
  if [[ -z "$kubash_hosts_csv_slurped" ]]; then
    hosts_csv_slurp
  fi
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    echo "K8S_node=$K8S_node
K8S_role=$K8S_role
K8S_cpuCount=$K8S_cpuCount
K8S_Memory=$K8S_Memory
K8S_sshPort=$K8S_sshPort
K8S_network1=$K8S_network1
K8S_mac1=$K8S_mac1
K8S_ip1=$K8S_ip1
K8S_routingprefix1=$K8S_routingprefix1
K8S_subnetmask1=$K8S_subnetmask1
K8S_broadcast1=$K8S_broadcast1
K8S_gateway1=$K8S_gateway1
K8S_provisionerHost=$K8S_provisionerHost
K8S_provisionerUser=$K8S_provisionerUser
K8S_provisionerPort=$K8S_provisionerPort
K8S_provisionerBasePath=$K8S_provisionerBasePath
K8S_os=$K8S_os
K8S_virt=$K8S_virt
K8S_network2=$K8S_network2
K8S_mac2=$K8S_mac2
K8S_ip2=$K8S_ip2
K8S_routingprefix2=$K8S_routingprefix2
K8S_subnetmask2=$K8S_subnetmask2
K8S_broadcast2=$K8S_broadcast2
K8S_gateway2=$K8S_gateway2
K8S_network3=$K8S_network3
K8S_mac3=$K8S_mac3
K8S_ip3=$K8S_ip3
K8S_routingprefix3=$K8S_routingprefix3
K8S_subnetmask3=$K8S_subnetmask3
K8S_broadcast3=$K8S_broadcast3
K8S_gateway3=$K8S_gateway3
K8S_iscsitarget=$K8S_iscsitarget
K8S_iscsichapusername=$K8S_iscsichapusername
K8S_iscsichappassword=$K8S_iscsichappassword
K8S_iscsihost=$K8S_iscsihost"
  done <<< "$kubash_hosts_csv_slurped"
}

prep () {
  squawk 5 " prep"
  set_csv_columns
  hosts_csv_slurp
  while IFS="," read -r $csv_columns
  do
    preppy $K8S_node $K8S_ip1 $K8S_sshPort
  done <<< "$kubash_hosts_csv_slurped"
}

preppy () {
  squawk 7 "preppy $@"
  node_name=$1
  node_ip=$2
  node_port=$3
  #removestalekeys $node_ip
  #ssh-keyscan -p $node_port $node_ip >> ~/.ssh/known_hosts
  scanner $node_ip $node_port
}

do_decom () {
  if [[ "$ANSWER_YES" == "yes" ]]; then
    decom_kvm
    rm -f $KUBASH_HOSTS_CSV
    rm -f $KUBASH_ANSIBLE_HOSTS
    rm -f $KUBASH_CLUSTER_CONFIG
  else
    read -p "This will destroy all VMs defined in the $KUBASH_HOSTS_CSV. Are you sure? [y/N] " -n 1 -r
    echo    # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
      decom_kvm
      rm -f $KUBASH_HOSTS_CSV
      rm -f $KUBASH_ANSIBLE_HOSTS
      rm -f $KUBASH_CLUSTER_CONFIG
    fi
  fi
}

do_metallb () {
    if [[ METALLB_INSTALLATION_METHOD = 'helm' ]]; then
      echo "This method is deprecated by upstream"
      exit 1
      KUBECONFIG=$KUBECONFIG \
      helm install \
        metallb \
        stable/metallb
    else
      kubectl --kubeconfig=$KUBECONFIG apply -f \
	https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/manifests/namespace.yaml
      kubectl --kubeconfig=$KUBECONFIG apply -f \
	https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/manifests/metallb.yaml
	# On first install only
      kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
    fi
}

do_efk () {
    cd $KUBASH_DIR/submodules/openebs/k8s/demo/efk
    kubectl --kubeconfig=$KUBECONFIG apply -f \
      es
    kubectl --kubeconfig=$KUBECONFIG apply -f \
      fluentd
    kubectl --kubeconfig=$KUBECONFIG apply -f \
      kibana
}

do_rook () {
    # Ceph
    #kubectl --kubeconfig=$KUBECONFIG apply -f \
      #https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/common.yaml
    #kubectl --kubeconfig=$KUBECONFIG apply -f \
      #https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/operator.yaml
    #kubectl --kubeconfig=$KUBECONFIG apply -f \
      #https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/cluster.yaml
    #kubectl --kubeconfig=$KUBECONFIG apply -f \
      #https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/toolbox.yaml
    # Ceph
    kubectl --kubeconfig=$KUBECONFIG apply -f \
      $KUBASH_DIR/submodules/rook/cluster/examples/kubernetes/ceph/common.yaml
    kubectl --kubeconfig=$KUBECONFIG apply -f \
      $KUBASH_DIR/submodules/rook/cluster/examples/kubernetes/ceph/operator.yaml
    $KUBASH_DIR/w8s/generic.w8 rook-ceph-operator rook-ceph
    $KUBASH_DIR/w8s/generic.w8 rook-discover rook-ceph
    kubectl --kubeconfig=$KUBECONFIG apply -f \
      $KUBASH_DIR/submodules/rook/cluster/examples/kubernetes/ceph/cluster.yaml
    $KUBASH_DIR/w8s/generic.w8 csi-rbdplugin rook-ceph
    $KUBASH_DIR/w8s/generic.w8 rook-ceph-mon rook-ceph
    $KUBASH_DIR/w8s/generic.w8 rook-ceph-crashcollector rook-ceph
    $KUBASH_DIR/w8s/generic.w8 csi-cephfsplugin-provisioner rook-ceph
    kubectl --kubeconfig=$KUBECONFIG apply -f \
      $KUBASH_DIR/submodules/rook/cluster/examples/kubernetes/ceph/pool.yaml
    kubectl --kubeconfig=$KUBECONFIG apply -f \
      $KUBASH_DIR/submodules/rook/cluster/examples/kubernetes/ceph/toolbox.yaml

    # cassandra
    kubectl --kubeconfig=$KUBECONFIG apply -f \
      https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/cassandra/operator.yaml
}

do_openebs () {
    if [[ OPENEBS_INSTALLATION_METHOD = 'helm' ]]; then
      kubectl create ns openebs
      helm repo add openebs https://openebs.github.io/charts
      helm repo update
      kubash_context
      KUBECONFIG=$KUBECONFIG \
      helm install \
        $KUBASH_OPENEBS_NAME \
        --namespace openebs \
        openebs/openebs
    else
      kubectl --kubeconfig=$KUBECONFIG apply -f https://openebs.github.io/charts/openebs-operator.yaml
    fi
    kubectl --kubeconfig=$KUBECONFIG create -f https://raw.githubusercontent.com/openebs/openebs/master/k8s/openebs-storageclasses.yaml
}

activate_monitoring () {
  # Prometheus
  cd $KUBASH_DIR/submodules/openebs/k8s/openebs-monitoring/configs
  kubectl --kubeconfig=$KUBECONFIG create -f \
    prometheus-config.yaml
  kubectl --kubeconfig=$KUBECONFIG create -f \
    prometheus-env.yaml
  kubectl --kubeconfig=$KUBECONFIG create -f \
    prometheus-alert-rules.yaml
  kubectl --kubeconfig=$KUBECONFIG create -f \
    alertmanager-templates.yaml
  kubectl --kubeconfig=$KUBECONFIG create -f \
    alertmanager-config.yaml
  cd $KUBASH_DIR/submodules/openebs/k8s/openebs-monitoring
  kubectl --kubeconfig=$KUBECONFIG create -f \
    prometheus-operator.yaml
  kubectl --kubeconfig=$KUBECONFIG create -f \
    alertmanager.yaml
  kubectl --kubeconfig=$KUBECONFIG create -f \
    grafana-operator.yaml
}
