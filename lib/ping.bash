#!/usr/bin/env bash

ping_in_parallel () {
  ping_tmp_para=$(mktemp -d --suffix='.para.tmp')
  squawk 2 ' Pinging all hosts using ssh'
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    squawk 103 "ping $K8S_user@$K8S_ip1"
    #MY_ECHO="this_hostname=\"$(hostname| tr -d '\n')\" this_date=\"$(date| tr -d '\n')\" echo '$K8S_ip1 $K8S_provisionerUser pong $this_hostname $this_date'" 
    #MY_ECHO="echo -e -n "PONG\t";hostname|tr -d  '\n';echo -e -n "\t";date +%s|tr -d '\n';echo -e -n '$K8S_ip1';echo -e -n "\t";uname -a" 
    #MY_PING=$(ping -c1 $K8S_ip1|tail -n1|cut -f4 -d' '|cut -d'/' -f1|tr -d '\n')
    #MY_ECHO="date +%s|tr -d '\n';echo -n ' $K8S_ip1';echo -n ' PONG ';hostname|tr -d  '\n';echo -n ' ';echo -e -n ' ';uname -a"
    MY_ECHO="get_major_minor_kube_version $K8S_user $K8S_ip1  $K8S_node $K8S_sshPort"
    squawk 5 "ssh -n -p $K8S_sshPort $K8S_provisionerUser@$K8S_ip1 \"$MY_ECHO\""
    get_major_minor_kube_version $K8S_user $K8S_ip1  $K8S_node $K8S_sshPort
    #get_major_minor_kube_version $K8S_user $K8S_ip1  $K8S_node $K8S_sshPort
    squawk 5 "Minor= $KUBE_MINOR_VER"
    #sleep 2
    echo "ssh -n -p $K8S_sshPort $K8S_provisionerUser@$K8S_ip1 \"$MY_ECHO\""\
        >> $ping_tmp_para/hopper
  done < $KUBASH_HOSTS_CSV

  if [[ "$VERBOSITY" -gt "9" ]] ; then
    cat $ping_tmp_para/hopper
  fi
  if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    $PARALLEL  -j $PARALLEL_JOBS -- < $ping_tmp_para/hopper
  else
    bash $ping_tmp_para/hopper
  fi
  rm -Rf $ping_tmp_para
}

ping () {
  squawk 2 ' Pinging all hosts using ssh'
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    squawk 1 "$K8S_ip1"
    squawk 3 "$K8S_user"
    if [[ "$VERBOSITY" -gt 10 ]]; then
      ssh -n -p $K8S_sshPort $K8S_user@$K8S_ip1 'echo pong'
      squawk 3 "$K8S_provisionerUser"
      ssh -n -p $K8S_sshPort $K8S_provisionerUser@$K8S_ip1 'echo pong'
    else
      ssh -n -p $K8S_sshPort $K8S_user@$K8S_ip1 'touch /tmp/sshpingtest-kubash'
      ssh -n -p $K8S_sshPort $K8S_provisionerUser@$K8S_ip1 'touch /tmp/sshpingtest-kubash'
    fi
  done < $KUBASH_HOSTS_CSV
}

ansible-ping () {
  squawk 1 ' Pinging all hosts using Ansible'
  ansible -i $KUBASH_ANSIBLE_HOSTS -m ping all
}
