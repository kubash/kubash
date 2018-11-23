#!/bin/bash
#export CP0_IP=10.0.0.7
#export CP0_HOSTNAME=cp0
#export CP1_IP=10.0.0.8
#export CP1_HOSTNAME=cp1
export CP0_IP=$1
export CP0_HOSTNAME=$2
export CP1_IP=$3
export CP1_HOSTNAME=$4
export KUBECONFIG=/etc/kubernetes/admin.conf
mkdir -p ~/.kube
cp -v /etc/kubernetes/admin.conf ~/.kube/config

kubeadm alpha phase certs all --config /etc/kubernetes/kubeadmcfg.yaml
kubeadm alpha phase kubelet config write-to-disk --config /etc/kubernetes/kubeadmcfg.yaml
kubeadm alpha phase kubelet write-env-file --config /etc/kubernetes/kubeadmcfg.yaml
kubeadm alpha phase kubeconfig kubelet --config /etc/kubernetes/kubeadmcfg.yaml
systemctl restart kubelet
kubeadm alpha phase etcd local --config /etc/kubernetes/kubeadmcfg.yaml
echo "kubectl --kubeconfig=/etc/kubernetes/admin.conf exec -n kube-system etcd-${CP0_HOSTNAME} -- etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.crt --cert-file /etc/kubernetes/pki/etcd/peer.crt --key-file /etc/kubernetes/pki/etcd/peer.key --endpoints=https://${CP0_IP}:2379 member add ${CP1_HOSTNAME} https://${CP1_IP}:2380"
sleep 66
kubectl --kubeconfig=/etc/kubernetes/admin.conf exec -n kube-system etcd-${CP0_HOSTNAME} -- etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.crt --cert-file /etc/kubernetes/pki/etcd/peer.crt --key-file /etc/kubernetes/pki/etcd/peer.key --endpoints=https://${CP0_IP}:2379 member add ${CP1_HOSTNAME} https://${CP1_IP}:2380
sleep 66
#rm /etc/kubernetes/admin.conf
#rm /etc/kubernetes/scheduler.conf
#rm /etc/kubernetes/controller-manager.conf
kubeadm alpha phase etcd local --config /etc/kubernetes/kubeadmcfg.yaml
kubeadm alpha phase kubeconfig all --config /etc/kubernetes/kubeadmcfg.yaml
kubeadm alpha phase controlplane all --config  /etc/kubernetes/kubeadmcfg.yaml
kubeadm alpha phase kubelet config annotate-cri --config /etc/kubernetes/kubeadmcfg.yaml
kubeadm alpha phase mark-master --config /etc/kubernetes/kubeadmcfg.yaml
