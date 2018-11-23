#!/bin/bash
MASTER_HOST=$1
ETCD_HOST=$2
USER=root
my_KUBE_CIDR="10.244.0.0/16"
# check and ensure that args were given
if [ ! $# -eq 2 ]; then
  # Print usage
  echo 'Error! wrong number of arguments, this script expects two hosts'
  echo 'usage:'
  echo "$0 host1 host2"
  exit 1
fi


command2run="cat << EOF > etcd-pki-files.txt
/etc/kubernetes/pki/etcd/ca.crt
/etc/kubernetes/pki/apiserver-etcd-client.crt
/etc/kubernetes/pki/apiserver-etcd-client.key
/etc/kubernetes/kubeadmcfg-external.yaml
EOF"
ssh ${USER}@${ETCD_HOST} "$command2run"

# create the archive
command2run="tar -czf etcd-pki.tar.gz -T etcd-pki-files.txt"
ssh ${USER}@${ETCD_HOST} "$command2run"
command2run="tar -czf - -T etcd-pki-files.txt"
ssh ${USER}@${ETCD_HOST} "$command2run" | ssh ${USER}@${MASTER_HOST} "cd /; tar zxvf -"
#command2run="cd /; tar zcf - /etc/kubernetes/kubeadmcfg-external.yaml"
#ssh ${USER}@${ETCD_HOST} "$command2run" | ssh ${USER}@${MASTER_HOST} "cd /; tar zxvf -"

command2run="sed -i 's/REPLACE_ME/$MASTER_HOST/g' /etc/kubernetes/kubeadmcfg-external.yaml"
ssh ${USER}@${MASTER_HOST} "$command2run"
command2run="mv /etc/kubernetes/kubeadmcfg-external.yaml /etc/kubernetes/kubeadmcfg.yaml"
ssh ${USER}@${MASTER_HOST} "$command2run"
#command2run="kubeadm init  --ignore-preflight-errors=FileAvailable--etc-kubernetes-manifests-etcd.yaml,ExternalEtcdVersion --config /etc/kubernetes/kubeadmcfg-external.yaml"
command2run="kubeadm init  --ignore-preflight-errors=FileAvailable--etc-kubernetes-manifests-etcd.yaml,ExternalEtcdVersion --config /etc/kubernetes/kubeadmcfg.yaml"
echo "$command2run"
ssh ${USER}@${MASTER_HOST} "$command2run"
