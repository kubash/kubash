#!/usr/bin/env bash

write_ansible_kubeadm2ha_hosts () {
  squawk 1 " Make a hosts file for kubeadm2ha ansible"
  # Make a fresh hosts file
  slurpy="$(grep -v '^#' $KUBASH_HOSTS_CSV)"
  if [[ -e "$KUBASH_ANSIBLE_HOSTS" ]]; then
    horizontal_rule
    rm $KUBASH_ANSIBLE_HOSTS
    touch $KUBASH_ANSIBLE_HOSTS
  else
    touch $KUBASH_ANSIBLE_HOSTS
  fi
  # Write all hosts to inventory for id
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    echo "$K8S_node ansible_ssh_host=$K8S_ip1 ansible_ssh_port=$K8S_sshPort ansible_user=$K8S_provisionerUser" >> $KUBASH_ANSIBLE_HOSTS
  done <<< "$slurpy"

  echo '' >> $KUBASH_ANSIBLE_HOSTS

  echo '[primary-master]'  >> $KUBASH_ANSIBLE_HOSTS
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "primary_master" ]]; then
      echo "$K8S_node" >> $KUBASH_ANSIBLE_HOSTS
    fi
  done <<< "$slurpy"
  echo '' >> $KUBASH_ANSIBLE_HOSTS
  echo '[secondary-masters]'  >> $KUBASH_ANSIBLE_HOSTS
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "master" ]]; then
      echo "$K8S_node" >> $KUBASH_ANSIBLE_HOSTS
    fi
  done <<< "$slurpy"
  echo '' >> $KUBASH_ANSIBLE_HOSTS
  echo '[masters]'  >> $KUBASH_ANSIBLE_HOSTS
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "master" ]]; then
      echo "$K8S_node" >> $KUBASH_ANSIBLE_HOSTS
    elif [[ "$K8S_role" == "primary_master" ]]; then
      echo "$K8S_node" >> $KUBASH_ANSIBLE_HOSTS
    fi
  done <<< "$slurpy"

  echo '' >> $KUBASH_ANSIBLE_HOSTS

  echo '[etcd]'  >> $KUBASH_ANSIBLE_HOSTS
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" = "etcd" ]]; then
      echo "$K8S_node" >> $KUBASH_ANSIBLE_HOSTS
    elif [[ "$K8S_role" == "master" || "$K8S_role" == "primary_master" ]]; then
      if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
        echo "$K8S_node" >> $KUBASH_ANSIBLE_HOSTS
      fi
    fi
  done <<< "$slurpy"

  echo '' >> $KUBASH_ANSIBLE_HOSTS

  echo '' >> $KUBASH_ANSIBLE_HOSTS

  echo '[minions]'  >> $KUBASH_ANSIBLE_HOSTS
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "node" ]]; then
      echo "$K8S_node $openshift_labels" >> $KUBASH_ANSIBLE_HOSTS
    fi
  done <<< "$slurpy"

  echo '' >> $KUBASH_ANSIBLE_HOSTS

  echo '[nodes]'  >> $KUBASH_ANSIBLE_HOSTS
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "node" ]]; then
      echo "$K8S_node $openshift_labels" >> $KUBASH_ANSIBLE_HOSTS
    elif [[ "$K8S_role" == "master" || "$K8S_role" == "primary_master" ]]; then
      echo "$K8S_node $openshift_labels" >> $KUBASH_ANSIBLE_HOSTS
    fi
  done <<< "$slurpy"

  echo '' >> $KUBASH_ANSIBLE_HOSTS

  echo '[nginx]'  >> $KUBASH_ANSIBLE_HOSTS
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" = "ingress" ]]; then
      echo "$K8S_node" >> $KUBASH_ANSIBLE_HOSTS
    fi
  done <<< "$slurpy"

  echo '' >> $KUBASH_ANSIBLE_HOSTS

  echo '[nfs-server]'  >> $KUBASH_ANSIBLE_HOSTS
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" = "nfs-server" ]]; then
      echo "$K8S_node" >> $KUBASH_ANSIBLE_HOSTS
    fi
  done <<< "$slurpy"

  echo '' >> $KUBASH_ANSIBLE_HOSTS

  cat $KUBASH_DIR/templates/my-cluster.inventory.tail >> $KUBASH_ANSIBLE_HOSTS
}
