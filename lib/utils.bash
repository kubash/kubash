#!/usr/bin/env bash

horizontal_rule () {
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
}

# Check if a command exists
check_cmd () {
  if ! test_cmd_loc="$(type -p "$1")" || [[ -z "$test_cmd_loc" ]]; then
    horizontal_rule
    echo "$1 was not found in your path!"
    croak 3  "To proceed please install $1 to your path and try again!"
  fi
}

check_cmd mktemp

# Check if a file exists and is writable
check_file () {
  if [[ -w "$1" ]]; then
    croak 3  "$1 was not writable!"
  fi
}

chkdir () {
  if [[ ! -w "$1" ]] ; then
    sudo mkdir -p $1
    sudo chown $USER $1
  fi
  if [[ ! -w "$1" ]] ; then
    echo "Cannot write to $1, please check your permissions"
    exit 2
  fi
}

killtmp () {
  cd
  rm -Rf $TMP
}

# these vars are used by the following functions
LINE_TO_ADD=''
TARGET_FILE_FOR_ADD=$HOME/.profile

check_if_line_exists()
{
  squawk 7 " Checking for '$LINE_TO_ADD'  in $TARGET_FILE_FOR_ADD"
  grep -qsFx "$LINE_TO_ADD" $TARGET_FILE_FOR_ADD
}

add_line_to()
{
  squawk 105 " Adding '$LINE_TO_ADD'  to $TARGET_FILE_FOR_ADD"
  TARGET_FILE=$TARGET_FILE_FOR_ADD
    [[ -w "$TARGET_FILE" ]] || TARGET_FILE=$TARGET_FILE_FOR_ADD
    printf "%s\n" "$LINE_TO_ADD" >> "$TARGET_FILE"
}

genmac () {
  # Generate a mac address
  hexchars="0123456789ABCDEF"
  : ${DEFAULT_MAC_ADDRESS_BLOCK:=52:54:00}

  if [[ ! -z "$1" ]]; then
    DEFAULT_MAC_ADDRESS_BLOCK=$1
  fi

  end=$( for i in {1..6} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/:\1/g' )

  echo "$DEFAULT_MAC_ADDRESS_BLOCK$end" >&3
}

set_verbosity () {
  if ! [[ "$1" =~ ^[0-9]+$ ]]; then
    VERBOSITY=0
  else
    VERBOSITY=$1
  fi
  squawk 5 " verbosity is now $VERBOSITY"
}

increase_verbosity () {
  ((++VERBOSITY))
  squawk 5 " verbosity is now $VERBOSITY"
}

set_name () {
  squawk 9 "set_name $1"
  squawk 8 "Kubash will now work with the $1 cluster"
  export KUBASH_CLUSTER_NAME="$1"
  export KUBASH_CLUSTER_DIR=$KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME
  export KUBASH_CLUSTER_CONFIG=$KUBASH_CLUSTER_DIR/config
  export KUBECONFIG=$KUBASH_CLUSTER_CONFIG
  export KUBASH_HOSTS_CSV=$KUBASH_CLUSTER_DIR/hosts.csv
  export KUBASH_ANSIBLE_HOSTS=$KUBASH_CLUSTER_DIR/hosts
  export KUBASH_KUBESPRAY_HOSTS=$KUBASH_CLUSTER_DIR/inventory/hosts.ini
  export KUBASH_PROVISION_CSV=$KUBASH_CLUSTER_DIR/provision.csv
  export KUBASH_USERS_CSV=$KUBASH_CLUSTER_DIR/users.csv
  export KUBASH_CSV_VER_FILE=$KUBASH_CLUSTER_DIR/csv_version
  if [[ -f "$KUBASH_CLUSTER_DIR/kubernetes_version" ]]; then
    export KUBERNETES_VERSION=$( cat $KUBASH_CLUSTER_DIR/kubernetes_version)
  fi
  net_set
  if [[ -e $KUBASH_CLUSTER_DIR/csv_version ]]; then
    set_csv_columns
    if [[ -e $KUBASH_CLUSTER_DIR/provision.csv ]]; then
      provision_csv_slurp
      squawk 160 "slurpy -----> $(echo $kubash_provision_csv_slurped)"
    fi
    if [[ -e $KUBASH_CLUSTER_DIR/hosts.csv ]]; then
      hosts_csv_slurp
      squawk 150 "slurpy -----> $(echo $kubash_hosts_csv_slurped)"
      while IFS="," read -r $csv_columns
      do
        if [[ "$K8S_role" == 'etcd' ]]; then
          export MASTERS_AS_ETCD="false"
        elif [[ "$K8S_role" == "primary_master" ]]; then
          get_major_minor_kube_version $K8S_user $K8S_ip1  $K8S_node $K8S_sshPort
        fi
      done <<< "$kubash_hosts_csv_slurped"
    fi
  fi
}

rolero () {
  squawk 2 "rolero $@"
  node_name=$1
  NODE_ROLE=$2

  result=$(kubectl --kubeconfig=$KUBECONFIG label --overwrite node $node_name node-role.kubernetes.io/$NODE_ROLE=)
  squawk 4 "Result = $result"
}

checks () {
  squawk 5 " checks"
  check_cmd git
  check_cmd nc
  check_cmd ssh
  check_cmd rsync
  check_cmd ansible
  check_cmd curl
  check_cmd nmap
  check_cmd uname
  check_cmd envsubst
  check_cmd ct
  check_cmd jinja2
  check_cmd yaml2json
  check_cmd jq
  check_cmd rlwrap
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    check_cmd parallel
  fi
  check_cmd 'grep'
  check_cmd 'sed'
}

grant () {
  user_role=$3
  grant_tmp=$(mktemp)
  USERNAME_OF_ADMIN=$1 \
  EMAIL_ADDRESS_OF_ADMIN=$2 \
  envsubst < $KUBASH_DIR/templates/$user_role-role \
    > $grant_tmp
  kubectl --kubeconfig=$KUBECONFIG apply -f $grant_tmp
  rm $grant_tmp
}

grant_users () {
  grant_users_tmp_para=$(mktemp -d --suffix='.para.tmp' 2>/dev/null || mktemp -d -t '.para.tmp')
  touch $grant_users_tmp_para/hopper
  slurpy="$(grep -v '^#' $KUBASH_USERS_CSV)"
  # user_csv_columns="user_email user_role"
  set_csv_columns
  while IFS="," read -r $user_csv_columns
  do
    squawk 9 "user_name=$user_name user_email=$user_email user_role=$user_role"
    echo "kubash -n $KUBASH_CLUSTER_NAME grant $user_name $user_email $user_role" >> $grant_users_tmp_para/hopper
  done <<< "$slurpy"

  if [[ "$VERBOSITY" -gt "9" ]] ; then
    cat $grant_users_tmp_para/hopper
  fi
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    $PARALLEL  -j $PARALLEL_JOBS -- < $grant_users_tmp_para/hopper
  else
    bash $grant_users_tmp_para/hopper
  fi
  rm -Rf $grant_users_tmp_para
}

get_major_minor_kube_version () {
  squawk 10 "get_major_minor_kube_version user=$1 host=$2 name=$3 port=$4"
  this_user=$1
  this_host=$2
  this_name=$3
  this_port=$4
  #command2run="kubeadm version 2>/dev/null |sed \'s/^.*Major:\"\([1234567890]*\)\", Minor:\"\([1234567890]*\)\", GitVersion:.*$/\1,\2/\'"
  squawk 101 "get_major_minor_kube_version set command"
  set +e
  command2run="kubeadm version 2>/dev/null"
  #command2run="kubeadm version 2>/dev/null |sed \'s/^.*Major:\"\([1234567890]*\)\", Minor:\"\([1234567890]*\)\", GitVersion:.*$/\1,\2/\'"
  #TEST_KUBEADM_VER=`sudo_command $this_port $this_user $this_host "$command2run"`
  TEST_KUBEADM_VER_STEP_1=$(ssh -p $this_port $this_user@$this_host "$command2run")
  #TEST_KUBEADM_VER_STEP_1=$(sudo_command $this_port $this_user $this_host "$command2run")
  squawk 101 "get_major_minor_kube_version step 1 output=$TEST_KUBEADM_VER_STEP_1"
  TEST_KUBEADM_VER_STEP_2=$(echo $TEST_KUBEADM_VER_STEP_1 | grep -v -P '^#')
  squawk 101 "get_major_minor_kube_version step 2 output=$TEST_KUBEADM_VER_STEP_2"
  TEST_KUBEADM_VER=$(echo $TEST_KUBEADM_VER_STEP_2 | sed 's/^.*Major:\"\([1234567890]*\)\", Minor:\"\([1234567890]*\)\", GitVersion:.*$/\1,\2/' )
  squawk 101 "get_major_minor_kube_version step 3 output=$TEST_KUBEADM_VER"
  squawk 101 "get_major_minor_kube_version exports"
  export KUBE_MAJOR_VER=$(echo $TEST_KUBEADM_VER|cut -f1 -d,)
  export KUBE_MINOR_VER=$(echo $TEST_KUBEADM_VER|cut -f2 -d,)
  squawk 185 "kube major: $KUBE_MAJOR_VER kube minor: $KUBE_MINOR_VER"
  set -e
}

kubash_context () {
  KUBECONFIG=$KUBECONFIG \
  kubectl config set-context kubash \
  --user=kubernetes-admin \
  --cluster=$KUBASH_CLUSTER_NAME
  KUBECONFIG=$KUBECONFIG \
  kubectl config use-context kubash
}

removestalekeys () {
  squawk 1 " removestalekeys $@"
  node_ip=$1
  ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$node_ip"
}

remove_vagrant_user () {
  remove_vagrant_user_tmp_para=$(mktemp -d)
  squawk 2 ' Remove vagrant user from all hosts using ssh'
  touch $remove_vagrant_user_tmp_para/hopper
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    squawk 1 "$K8S_ip1"
    squawk 3 "$K8S_user"
    squawk 3 "$K8S_os"
    if [[ "$K8S_os" == 'coreos' ]]; then
      squawk 9 'coreos so skipping'
    else
      REMMY="userdel -fr vagrant"
      squawk 6 "ssh -n -p $K8S_sshPort $K8S_user@$K8S_ip1 \"$REMMY\""
      echo "ssh -n -p $K8S_sshPort $K8S_user@$K8S_ip1 \"$REMMY\""\
        >> $remove_vagrant_user_tmp_para/hopper
    fi
  done < $KUBASH_HOSTS_CSV

  if [[ "$VERBOSITY" -gt "9" ]] ; then
    cat $remove_vagrant_user_tmp_para/hopper
  fi

  set +e #some of the new builds have been erroring out as vagrant has been removed already, softening
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    $PARALLEL  -j $PARALLEL_JOBS -- < $remove_vagrant_user_tmp_para/hopper
  else
    bash $remove_vagrant_user_tmp_para/hopper
  fi
  set -e # End softening

  rm -Rf $remove_vagrant_user_tmp_para
}

hostname_in_parallel () {
  hostname_tmp_para=$(mktemp -d --suffix='.para.tmp')
  squawk 2 ' Hostnaming all hosts using ssh'
  if [[ -z "$kubash_hosts_csv_slurped" ]]; then
    hosts_csv_slurp
  fi
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    my_HOST=$K8S_node
    my_IP=$K8S_ip1
    my_PORT=$K8S_sshPort
    my_USER=$K8S_provisionerUser
    command2run="ssh -n -p $my_PORT $my_USER@$my_IP '$PSEUDO hostname $my_HOST && echo $my_HOST | $PSEUDO tee /etc/hostname && echo \"127.0.1.1 $my_HOST.$my_DOMAIN $my_HOST  \" | $PSEUDO tee -a /etc/hosts'"
    squawk 5 "$command2run"
    echo "$command2run" \
      >> $hostname_tmp_para/hopper
  done <<< "$kubash_hosts_csv_slurped"

  if [[ "$VERBOSITY" -gt "9" ]] ; then
    cat $hostname_tmp_para/hopper
  fi
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    $PARALLEL  -j $PARALLEL_JOBS -- < $hostname_tmp_para/hopper
  else
    bash $hostname_tmp_para/hopper
  fi
  rm -Rf $hostname_tmp_para
}

set_ip_files () {
  # First find the primary etcd master
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "primary_master"  ]]; then
      if [[ "$countprimarymaster" -eq "0" ]]; then
        # save these values for clusterwide usage
        echo $K8S_ip1 > $KUBASH_CLUSTER_DIR/kube_primary
        echo $K8S_sshPort > $KUBASH_CLUSTER_DIR/kube_primary_port
        echo $K8S_provisionerUser > $KUBASH_CLUSTER_DIR/kube_primary_user
      else
        croak 3  'there should only be one primary master'
      fi
      ((++countprimarymaster))
    elif [[ "$K8S_role" == "primary_etcd"  ]]; then
      if [[ "$countprimaryetcd" -eq "0" ]]; then
        # save these values for clusterwide usage
        echo $K8S_ip1 > $KUBASH_CLUSTER_DIR/kube_primary_etcd
        echo $K8S_sshPort > $KUBASH_CLUSTER_DIR/kube_primary_etcd_port
        echo $K8S_provisionerUser > $KUBASH_CLUSTER_DIR/kube_primary_etcd_user
      else
        croak 3  'there should only be one primary etcd'
      fi
      ((++countprimaryetcd))
    elif [[ "$K8S_role" == "master"  ]]; then
      echo $K8S_ip1 > $KUBASH_CLUSTER_DIR/kube_master${countmaster}
      echo $K8S_sshPort > $KUBASH_CLUSTER_DIR/kube_master${countmaster}_port
      echo $K8S_provisionerUser > $KUBASH_CLUSTER_DIR/kube_master${countmaster}_user
      ((++countmaster))
    elif [[ "$K8S_role" == "etcd"  ]]; then
      echo $K8S_ip1 > $KUBASH_CLUSTER_DIR/kube_etcd${countetcd}
      echo $K8S_sshPort > $KUBASH_CLUSTER_DIR/kube_etcd${countetcd}_port
      echo $K8S_provisionerUser > $KUBASH_CLUSTER_DIR/kube_etcd${countetcd}_user
      ((++countetcd))
    fi
  done <<< "$kubash_hosts_csv_slurped"
}

do_command_in_parallel () {
  do_command_tmp_para=$(mktemp -d)
  command2run=$1
  touch $do_command_tmp_para/hopper
  squawk 3 " do_command_in_parallel $@"
  if [[ -z "$kubash_hosts_csv_slurped" ]]; then
    squawk 219 'slurp empty'
    hosts_csv_slurp
  else
    squawk 219 "host slurp $(echo $kubash_hosts_csv_slurped)"
  fi
  countzero_do_nodes=0
  squawk 120 'Start while loop'
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    ((++countzero_do_nodes))
    squawk 219 " count $countzero_do_nodes"
    squawk 205 "ssh -n -p $K8S_sshPort $K8S_SU_USER@$K8S_ip1 \"sudo bash -l -c '$command2run'\""
    echo "ssh -n -p $K8S_sshPort $K8S_SU_USER@$K8S_ip1 \"sudo bash -l -c '$command2run'\""\
        >> $do_command_tmp_para/hopper
  done <<< "$kubash_hosts_csv_slurped"

  if [[ "$VERBOSITY" -gt "9" ]] ; then
    cat $do_command_tmp_para/hopper
  fi
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    $PARALLEL  -j $PARALLEL_JOBS -- < $do_command_tmp_para/hopper
  else
    bash $do_command_tmp_para/hopper
  fi
  rm -Rf $do_command_tmp_para
}

do_command () {
  squawk 3 " do_command $@"
  if [[ ! $# -eq 4 ]]; then
    croak 3  "do_command $@ <--- arguments does not equal 4!!!"
  fi
  do_command_port=$1
  do_command_user=$2
  do_command_host=$3
  command2run=$4
  if [[ "$do_command_host" == "localhost" ]]; then
    squawk 105 "bash -l -c '$command2run'"
    bash -l -c "$command2run"
  else
    squawk 105 "ssh -n -p $do_command_port $do_command_user@$do_command_host \"bash -l -c '$command2run'\""
    ssh -n -p $do_command_port $do_command_user@$do_command_host "bash -l -c '$command2run'"
  fi
}

sudo_command () {
  if [[ ! $# -eq 4 ]]; then
    echo "sudo_command $@"
    printf '%s arguments does not equal 4!!!\nexample usage:\nsudo_command PORT USER HOST COMMAND\ne.g.\nsudo_command 22 root 10.0.0.10 "echo test"' $#
    exit 1
  fi
  squawk 3 " sudo_command '$1' '$2' '$3 '$4'"
  sudo_command_port=$1
  sudo_command_user=$2
  sudo_command_host=$3
  command2run=$4
  if [[ "$sudo_command_host" == "localhost" ]]; then
    squawk 105 "$PSEUDO bash -l -c '$command2run'"
    $PSEUDO bash -l -c "$command2run"
  else
    squawk 105 "ssh -n -p $sudo_command_port $sudo_command_user@$sudo_command_host \"$PSEUDO bash -l -c '$command2run'\""
    ssh -n -p $sudo_command_port $sudo_command_user@$sudo_command_host "$PSEUDO bash -l -c '$command2run'"
  fi
}

copy_known_hosts () {
  squawk 15 'copy known_hosts to all servers'
  copy_in_parallel_to_all ~/.ssh/known_hosts /tmp/known_hosts
  command2run="cp -v /tmp/known_hosts /root/.ssh/known_hosts"
  do_command_in_parallel "$command2run"
  command2run="mv -v /tmp/known_hosts /home/$K8S_SU_USER/.ssh/known_hosts"
  do_command_in_parallel "$command2run"
}

copy_in_parallel_to_all () {
  copy_in_to_all_tmp_para=$(mktemp -d)
  file2copy=$(realpath $1)
  destination=$2
  touch $copy_in_to_all_tmp_para/hopper
  squawk 3 " copy_in_parallel_to_all $@"
  if [[ -z "$kubash_hosts_csv_slurped" ]]; then
    hosts_csv_slurp
  fi
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    squawk 205 "rsync $KUBASH_RSYNC_OPTS 'ssh -p $K8S_sshPort' $file2copy $K8S_SU_USER@$K8S_ip1:$destination"
    echo "rsync $KUBASH_RSYNC_OPTS 'ssh -p $K8S_sshPort' $file2copy $K8S_SU_USER@$K8S_ip1:$destination"\
      >> $copy_in_to_all_tmp_para/hopper
  done <<< "$kubash_hosts_csv_slurped"

  if [[ "$VERBOSITY" -gt "9" ]] ; then
    cat $copy_in_to_all_tmp_para/hopper
  fi
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    $PARALLEL  -j $PARALLEL_JOBS -- < $copy_in_to_all_tmp_para/hopper
  else
    bash $copy_in_to_all_tmp_para/hopper
  fi
  rm -Rf $copy_in_to_all_tmp_para
}

copy_in_parallel_to_role () {
  copy_in_to_role_tmp_para=$(mktemp -d)
  role2copy2=$1
  file2copy=$(realpath $2)
  destination=$3
  touch $copy_in_to_role_tmp_para/hopper
  squawk 3 " copy_in_parallel_to_role $@"
  if [[ -z "$kubash_hosts_csv_slurped" ]]; then
    hosts_csv_slurp
  fi
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "$role2copy2" ]]; then
      squawk 219 " count $countzero_do_nodes"
      squawk 205 "rsync $KUBASH_RSYNC_OPTS 'ssh -p $K8S_sshPort' $file2copy $K8S_SU_USER@$K8S_ip1:$destination"
      echo "rsync $KUBASH_RSYNC_OPTS 'ssh -p $K8S_sshPort' $file2copy $K8S_SU_USER@$K8S_ip1:$destination"\
        >> $copy_in_to_role_tmp_para/hopper
    fi
  done <<< "$kubash_hosts_csv_slurped"

  if [[ "$VERBOSITY" -gt "9" ]] ; then
    cat $copy_in_to_role_tmp_para/hopper
  fi
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    $PARALLEL  -j $PARALLEL_JOBS -- < $copy_in_to_role_tmp_para/hopper
  else
    bash $copy_in_to_role_tmp_para/hopper
  fi
  rm -Rf $copy_in_to_role_tmp_para
}

copy_in_parallel_to_os () {
  copy_in_to_os_tmp_para=$(mktemp -d)
  os2copy2=$1
  file2copy=$(realpath $2)
  destination=$3
  touch $copy_in_to_os_tmp_para/hopper
  squawk 3 " copy_in_parallel_to_os $@"
  if [[ -z "$kubash_hosts_csv_slurped" ]]; then
    hosts_csv_slurp
  fi
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_os" == "$os2copy2" ]]; then
      squawk 219 " count $countzero_do_nodes"
      squawk 205 "rsync $KUBASH_RSYNC_OPTS 'ssh -p $K8S_sshPort' $file2copy $K8S_SU_USER@$K8S_ip1:$destination"
      echo "rsync $KUBASH_RSYNC_OPTS 'ssh -p $K8S_sshPort' $file2copy $K8S_SU_USER@$K8S_ip1:$destination"\
        >> $copy_in_to_os_tmp_para/hopper
    fi
  done <<< "$kubash_hosts_csv_slurped"

  if [[ "$VERBOSITY" -gt "9" ]] ; then
    cat $copy_in_to_os_tmp_para/hopper
  fi
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    $PARALLEL  -j $PARALLEL_JOBS -- < $copy_in_to_os_tmp_para/hopper
  else
    bash $copy_in_to_os_tmp_para/hopper
  fi
  rm -Rf $copy_in_to_os_tmp_para
}

do_command_in_parallel_on_role () {
  do_command_on_role_tmp_para=$(mktemp -d)
  role2runiton=$1
  command2run=$2
  touch $do_command_on_role_tmp_para/hopper
  squawk 3 " do_command_in_parallel_on_role $@"
  if [[ -z "$kubash_hosts_csv_slurped" ]]; then
    hosts_csv_slurp
  fi
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "$role2runiton" ]]; then
      squawk 219 " count $countzero_do_nodes"
      squawk 205 "ssh -n -p $K8S_sshPort $K8S_SU_USER@$K8S_ip1 \"sudo bash -l -c '$command2run'\""
      echo "ssh -n -p $K8S_sshPort $K8S_SU_USER@$K8S_ip1 \"sudo bash -l -c '$command2run'\""\
        >> $do_command_on_role_tmp_para/hopper
    fi
  done <<< "$kubash_hosts_csv_slurped"

  if [[ "$VERBOSITY" -gt "9" ]] ; then
    cat $do_command_on_role_tmp_para/hopper
  fi
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    $PARALLEL  -j $PARALLEL_JOBS -- < $do_command_on_role_tmp_para/hopper
  else
    bash $do_command_on_role_tmp_para/hopper
  fi
  rm -Rf $do_command_on_role_tmp_para
}

do_command_in_parallel_on_os () {
  do_command_on_os_tmp_para=$(mktemp -d)
  os2runiton=$1
  command2run=$2
  touch $do_command_on_os_tmp_para/hopper
  squawk 3 " do_command_in_parallel $@"
  if [[ -z "$kubash_hosts_csv_slurped" ]]; then
    hosts_csv_slurp
  fi
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_os" == "$os2runiton" ]]; then
      squawk 219 " count $countzero_do_nodes"
      squawk 205 "ssh -n -p $K8S_sshPort $K8S_SU_USER@$K8S_ip1 \"sudo bash -l -c '$command2run'\""
      echo "ssh -n -p $K8S_sshPort $K8S_SU_USER@$K8S_ip1 \"sudo bash -l -c '$command2run'\""\
        >> $do_command_on_os_tmp_para/hopper
    fi
  done <<< "$kubash_hosts_csv_slurped"

  if [[ "$VERBOSITY" -gt "9" ]] ; then
    cat $do_command_on_os_tmp_para/hopper
  fi
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    $PARALLEL  -j $PARALLEL_JOBS -- < $do_command_on_os_tmp_para/hopper
  else
    bash $do_command_on_os_tmp_para/hopper
  fi
  rm -Rf $do_command_on_os_tmp_para
}
