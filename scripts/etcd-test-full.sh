#!/bin/bash
USER=root
my_KUBE_CIDR="10.244.0.0/16"
# check and ensure that args were given
if [ ! $# -eq 3 ]; then
  # Print usage
  echo 'Error! wrong number of arguments, this script expects three hosts'
  echo 'usage:'
  echo "$0 host0 host1 host2"
  exit 1
fi

ETCDHOSTS=($@)
NAMES=("0" "1")

#ETCDHOSTS=(${HOST0} ${HOST1} ${HOST2})
for i in "${!ETCDHOSTS[@]}"; do
  HOST=${ETCDHOSTS[$i]}
  NAMES[$i]="infra${i}"
  echo 'NAMES[$i]'
  echo ${NAMES[$i]} $HOST
  sleep 5
  #NAMES=("infra0" "infra1" "infra2")
  #THIS_NAMES="infra${i} ${THIS_NAMES}"
  THIS_NAMES="${THIS_NAMES} infra${i}"
  # Create temp directories to store files that will end up on other hosts.
  echo mkdir -p /tmp/${HOST}/
  mkdir -p /tmp/${HOST}/

# config file is not ready yet: https://github.com/kubernetes/kubernetes/issues/70745
#ExecStart=/usr/bin/kubelet  --allow-privileged=true
#ExecStart=/usr/bin/kubelet --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml
#ExecStart=/usr/bin/kubelet --config=/var/lib/kubelet/config.yaml

  # break indentation
  command2run='cat << EOF > /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
[Service]
ExecStart=
ExecStart=/usr/bin/kubelet --address=127.0.0.1 --pod-manifest-path=/etc/kubernetes/manifests --allow-privileged=true
Restart=always
EOF'
  # unbreak indentation

  echo "ssh ${USER}@${HOST} $command2run"
  ssh ${USER}@${HOST} "$command2run"

  # break indentation
  #command2run='cat << EOF > /var/lib/kubelet/config.yaml
#kind: KubeletConfiguration
#apiVersion: kubelet.config.k8s.io/v1beta1
#address: 127.0.0.1
#staticpodpath: /etc/kubernetes/manifests
#EOF'
  # unbreak indentation
  #echo "ssh ${USER}@${HOST} $command2run"
  #ssh ${USER}@${HOST} "$command2run"
done
#NAMES=("${THIS_NAMES}")

for i in "${!ETCDHOSTS[@]}"; do
  HOST=${ETCDHOSTS[$i]}
  NAME=${NAMES[$i]}
  cat << EOF > /tmp/${HOST}/kubeadmcfg.yaml
apiVersion: "kubeadm.k8s.io/v1alpha3"
kind: ClusterConfiguration
etcd:
    local:
        serverCertSANs:
        - "${HOST}"
        peerCertSANs:
        - "${HOST}"
        extraArgs:
            initial-cluster: infra0=https://${ETCDHOSTS[0]}:2380,infra1=https://${ETCDHOSTS[1]}:2380,infra2=https://${ETCDHOSTS[2]}:2380
            initial-cluster-state: new
            name: ${NAME}
            listen-peer-urls: https://${HOST}:2380
            listen-client-urls: https://${HOST}:2379
            advertise-client-urls: https://${HOST}:2379
            initial-advertise-peer-urls: https://${HOST}:2380
EOF
  cat << EOF > /tmp/${HOST}/kubeadmcfg-external.yaml
apiVersion: kubeadm.k8s.io/v1alpha3
kind: ClusterConfiguration
apiServerCertSANs:
- "127.0.0.1"
- "${ETCDHOSTS[0]}"
- "${ETCDHOSTS[1]}"
controlPlaneEndpoint: "${ETCDHOSTS[1]}"
etcd:
  external:
      endpoints:
      - https://${ETCDHOSTS[0]}:2379
      - https://${ETCDHOSTS[1]}:2379
      - https://${ETCDHOSTS[2]}:2379
      caFile: /etc/kubernetes/pki/etcd/ca.crt
      certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
      keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key
networking:
  podSubnet: $my_KUBE_CIDR
EOF
  command2run='systemctl daemon-reload'
  echo "ssh ${USER}@${HOST} $command2run"
  ssh ${USER}@${HOST} "$command2run"
  command2run='systemctl restart kubelet'
  echo "ssh ${USER}@${HOST} $command2run"
  ssh ${USER}@${HOST} "$command2run"
done

kubeadm alpha phase certs etcd-ca

# host 0
cp -R /etc/kubernetes/pki /tmp/${ETCDHOSTS[0]}/

for i in "${!ETCDHOSTS[@]}"; do
  HOST=${ETCDHOSTS[$i]}
  kubeadm alpha phase certs etcd-server --config=/tmp/${HOST}/kubeadmcfg.yaml
  kubeadm alpha phase certs etcd-peer --config=/tmp/${HOST}/kubeadmcfg.yaml
  kubeadm alpha phase certs etcd-healthcheck-client --config=/tmp/${HOST}/kubeadmcfg.yaml
  kubeadm alpha phase certs apiserver-etcd-client --config=/tmp/${HOST}/kubeadmcfg.yaml
  rsync -a /etc/kubernetes/pki /tmp/${HOST}/
  # cleanup non-reusable certificates
  find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete
  # clean up certs that should not be copied off this host
  find /tmp/${HOST} -name ca.key -type f -delete
done

for i in "${!ETCDHOSTS[@]}"; do
  HOST=${ETCDHOSTS[$i]}
  echo "scp -r /tmp/${HOST}/* ${USER}@${HOST}:"
  scp -r /tmp/${HOST}/* ${USER}@${HOST}:
  echo "ssh ${USER}@${HOST} sudo chown -R root:root pki"
  ssh ${USER}@${HOST} "sudo chown -R root:root pki"
  #ssh ${USER}@${HOST} "sudo mv -f pki /etc/kubernetes/"
  echo "ssh ${USER}@${HOST} sudo rsync -a pki /etc/kubernetes/"
  ssh ${USER}@${HOST} "sudo rsync -a pki /etc/kubernetes/"
  echo "ssh ${USER}@${HOST} kubeadm alpha phase etcd local --config=/root/kubeadmcfg.yaml"
  ssh ${USER}@${HOST} "kubeadm alpha phase etcd local --config=/root/kubeadmcfg.yaml"
done
for i in "${!ETCDHOSTS[@]}"; do
  HOST=${ETCDHOSTS[$i]}
  command2run='ls -alh /root'
  echo "ssh ${USER}@${HOST} $command2run"
  ssh ${USER}@${HOST} "$command2run"
  command2run='ls -Ralh /etc/kubernetes/pki'
  echo "ssh ${USER}@${HOST} $command2run"
  ssh ${USER}@${HOST} "$command2run"
done

command2run="kubeadm config images pull"
echo "$command2run"
#ssh ${USER}@${ETCDHOSTS[0]} "$command2run"
#ssh ${USER}@${ETCDHOSTS[1]} "$command2run"
#ssh ${USER}@${ETCDHOSTS[2]} "$command2run"
sleep 33

command2run="docker run --rm  \
  --net host \
  -v /etc/kubernetes:/etc/kubernetes quay.io/coreos/etcd:v3.2.18 etcdctl \
  --cert-file /etc/kubernetes/pki/etcd/peer.crt \
  --key-file /etc/kubernetes/pki/etcd/peer.key \
  --ca-file /etc/kubernetes/pki/etcd/ca.crt \
  --endpoints https://${ETCDHOSTS[0]}:2379 cluster-health"

echo 'To test etcd run this commmand'
echo "$command2run"
echo "ssh ${USER}@${ETCDHOSTS[0]} $command2run"
ssh ${USER}@${ETCDHOSTS[0]} "$command2run"

for i in "${!ETCDHOSTS[@]}"; do
  HOST=${ETCDHOSTS[$i]}
  command2run='systemctl daemon-reload'
  #echo "ssh ${USER}@${HOST} $command2run"
  #ssh ${USER}@${HOST} "$command2run"
  command2run='systemctl stop kubelet'
  #echo "ssh ${USER}@${HOST} $command2run"
  #ssh ${USER}@${HOST} "$command2run"
done

sleep 11

command2run="kubeadm init  --ignore-preflight-errors=FileAvailable--etc-kubernetes-manifests-etcd.yaml,ExternalEtcdVersion --config /root/kubeadmcfg-external.yaml"
#echo "$command2run"
#ssh ${USER}@${ETCDHOSTS[0]} "$command2run"
