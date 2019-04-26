#!/usr/bin/env bash
write_ansible_kubespray_hosts () {
  squawk 1 " Make a hosts file for ansible"
  cp -av $KUBASH_DIR/submodules/kubespray/inventory/sample $KUBASH_CLUSTER_DIR/inventory
  # Make a fresh hosts file
  slurpy="$(grep -v '^#' $KUBASH_HOSTS_CSV)"
  if [[ -e "$KUBASH_KUBESPRAY_HOSTS" ]]; then
    horizontal_rule
    rm $KUBASH_KUBESPRAY_HOSTS
    touch $KUBASH_KUBESPRAY_HOSTS
  else
    touch $KUBASH_KUBESPRAY_HOSTS
  fi
  # Write all hosts to inventory for id
  set_csv_columns
  echo '[all]'  >> $KUBASH_KUBESPRAY_HOSTS
  while IFS="," read -r $csv_columns
  do
    echo "$K8S_node ip=$K8S_ip1 etcd_member_name=$K8S_node ansible_ssh_host=$K8S_ip1 ansible_ssh_port=$K8S_sshPort ansible_user=$K8S_provisionerUser" >> $KUBASH_KUBESPRAY_HOSTS
  done <<< "$slurpy"

  echo '' >> $KUBASH_KUBESPRAY_HOSTS

  echo '[kube-node]' >> $KUBASH_KUBESPRAY_HOSTS
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "node" ]]; then
      echo "$K8S_node" >> $KUBASH_KUBESPRAY_HOSTS
    fi
  done <<< "$slurpy"

  echo '' >> $KUBASH_KUBESPRAY_HOSTS

  echo '[kube-node:vars]' >> $KUBASH_KUBESPRAY_HOSTS
  echo 'ansible_ssh_extra_args="-o StrictHostKeyChecking=no"' >> $KUBASH_KUBESPRAY_HOSTS

  echo '' >> $KUBASH_KUBESPRAY_HOSTS

  echo '[calico-rr]' >> $KUBASH_KUBESPRAY_HOSTS
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "master" ]]; then
      echo "$K8S_node" >> $KUBASH_KUBESPRAY_HOSTS
    elif [[ "$K8S_role" == "primary_master" ]]; then
      echo "$K8S_node" >> $KUBASH_KUBESPRAY_HOSTS
    fi
  done <<< "$slurpy"

  echo '' >> $KUBASH_KUBESPRAY_HOSTS
  echo '[kube-master]' >> $KUBASH_KUBESPRAY_HOSTS
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" == "master" ]]; then
      echo "$K8S_node" >> $KUBASH_KUBESPRAY_HOSTS
    elif [[ "$K8S_role" == "primary_master" ]]; then
      echo "$K8S_node" >> $KUBASH_KUBESPRAY_HOSTS
    fi
  done <<< "$slurpy"

  echo '' >> $KUBASH_KUBESPRAY_HOSTS

  echo '[kube-master:vars]' >> $KUBASH_KUBESPRAY_HOSTS
  echo 'ansible_ssh_extra_args="-o StrictHostKeyChecking=no"' >> $KUBASH_KUBESPRAY_HOSTS

  echo '' >> $KUBASH_KUBESPRAY_HOSTS

  echo '[etcd]'  >> $KUBASH_KUBESPRAY_HOSTS
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" = "etcd"  || "$K8S_role" == "primary_etcd" ]]; then
      echo "$K8S_node" >> $KUBASH_KUBESPRAY_HOSTS
    elif [[ "$MASTERS_AS_ETCD" == "true" ]]; then
      if [[ "$K8S_role" == "master" || "$K8S_role" == "primary_master" ]]; then
        echo "$K8S_node" >> $KUBASH_KUBESPRAY_HOSTS
      fi
    fi
  done <<< "$slurpy"

  echo '' >> $KUBASH_KUBESPRAY_HOSTS

  echo '[vault]'  >> $KUBASH_KUBESPRAY_HOSTS
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" = "etcd"  || "$K8S_role" == "primary_etcd" ]]; then
      echo "$K8S_node" >> $KUBASH_KUBESPRAY_HOSTS
    elif [[ "$K8S_role" == "master" || "$K8S_role" == "primary_master" ]]; then
      if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
        echo "$K8S_node" >> $KUBASH_KUBESPRAY_HOSTS
      fi
    fi
  done <<< "$slurpy"

  echo '' >> $KUBASH_KUBESPRAY_HOSTS

  echo '[ingress]'  >> $KUBASH_KUBESPRAY_HOSTS
  while IFS="," read -r $csv_columns
  do
    if [[ "$K8S_role" = "ingress" ]]; then
      echo "$K8S_node" >> $KUBASH_KUBESPRAY_HOSTS
    fi
  done <<< "$slurpy"

  echo '' >> $KUBASH_KUBESPRAY_HOSTS

  echo '[k8s-cluster:children]' >> $KUBASH_KUBESPRAY_HOSTS
  echo 'kube-node' >> $KUBASH_KUBESPRAY_HOSTS
  echo 'kube-master' >> $KUBASH_KUBESPRAY_HOSTS
}
