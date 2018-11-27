#!/bin/bash
# check and ensure that args were given
if [ ! $# -eq 6 ]; then
  # Print usage
  echo 'Error! wrong number of arguments, this script expects five hosts'
  echo 'usage:'
  echo "$0 masterHost1 masterHost2 etcdHost1 etcdHost2 etcdHost3 nodeHost"
  exit 1
fi
MASTER_HOST=$1
MASTER_HOST2=$2
ETCD_HOST1=$3
ETCD_HOST2=$4
ETCD_HOST3=$5
NODE_HOST=$6
USER=root
my_KUBE_CIDR="10.244.0.0/16"
finalize_master_tmp=$(mktemp -d)

finalize_master () {
# break indentation
  command2run="cat << EOF > etcd-pki-files.txt
/etc/kubernetes/pki/etcd/ca.crt
/etc/kubernetes/pki/apiserver-etcd-client.crt
/etc/kubernetes/pki/apiserver-etcd-client.key
/etc/kubernetes/kubeadmcfg-external.yaml
EOF"
  ssh ${USER}@${ETCD_HOST1} "$command2run"
# unbreak indentation

  # create the archive
  command2run="tar -czf etcd-pki.tar.gz -T etcd-pki-files.txt"
  ssh ${USER}@${ETCD_HOST1} "$command2run"
  command2run="tar -czf - -T etcd-pki-files.txt"
  ssh ${USER}@${ETCD_HOST1} "$command2run" | ssh ${USER}@${MASTER_HOST} "cd /; tar zxvf -"

  command2run="sed -i 's/REPLACE_ME/$MASTER_HOST/g' /etc/kubernetes/kubeadmcfg-external.yaml"
  ssh ${USER}@${MASTER_HOST} "$command2run"
  command2run="mv /etc/kubernetes/kubeadmcfg-external.yaml /etc/kubernetes/kubeadmcfg.yaml"
  ssh ${USER}@${MASTER_HOST} "$command2run"

  my_KUBE_INIT="kubeadm init  --ignore-preflight-errors=FileAvailable--etc-kubernetes-manifests-etcd.yaml,ExternalEtcdVersion --config /etc/kubernetes/kubeadmcfg.yaml"
  my_grep='kubeadm join .* --token'
  ssh -n ${USER}@${MASTER_HOST} "$my_KUBE_INIT" 2>&1 | tee $finalize_master_tmp/${MASTER_HOST}-rawresults.k8s
  run_join=$(cat $finalize_master_tmp/${MASTER_HOST}-rawresults.k8s | grep -P -- "$my_grep")
  join_token=$(cat $finalize_master_tmp/${MASTER_HOST}-rawresults.k8s \
    | grep -P -- "$my_grep" \
    | sed 's/\(.*\)--token\ \(\S*\)\ --discovery-token-ca-cert-hash\ .*/\2/')
  if [[ -z "$run_join" ]]; then
    echo 'kubeadm init failed!'
    exit 1
  else
    echo $run_join > $finalize_master_tmp/join.sh
    echo $run_join > $finalize_master_tmp/node_join.sh
    sed -i 's/$/ --experimental-control-plane/' $finalize_master_tmp/join.sh
    sed -i 's/$/ --ignore-preflight-errors=FileAvailable--etc-kubernetes-pki-ca.crt/' $finalize_master_tmp/node_join.sh
    echo $join_token > $finalize_master_tmp/join_token
  fi
}

etcd_setup () {
  # check and ensure that args were given
  if [ ! $# -eq 3 ]; then
    # Print usage
    echo 'Error! wrong number of arguments, this function expects three hosts'
    echo 'usage:'
    echo "$0 host0 host1 host2"
    exit 1
  fi

  ETCDHOSTS=($@)
  NAMES=("0" "1")

  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    NAMES[$i]="infra${i}"
    echo 'NAMES[$i]'
    echo ${NAMES[$i]} $HOST
    sleep 5
    THIS_NAMES="${THIS_NAMES} infra${i}"
    # Create temp directories to store files that will end up on other hosts.
    echo mkdir -p /tmp/${HOST}/
    mkdir -p /tmp/${HOST}/

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
  done


  #NAMES=("${THIS_NAMES}")

  for i in "${!ETCDHOSTS[@]}"; do
    HOST=${ETCDHOSTS[$i]}
    NAME=${NAMES[$i]}
# break indentation
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
- "${ETCDHOSTS[2]}"
- "REPLACE_ME"
controlPlaneEndpoint: "REPLACE_ME:6443"
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
# break indentation
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
    scp -r /tmp/${HOST}/* ${USER}@${HOST}:/etc/kubernetes/
    echo "ssh ${USER}@${HOST} sudo chown -R root:root /etc/kubernetes/pki"
    ssh ${USER}@${HOST} "sudo chown -R root:root /etc/kubernetes/pki"
    echo "ssh ${USER}@${HOST} kubeadm alpha phase etcd local --config=/etc/kubernetes/kubeadmcfg.yaml"
    ssh ${USER}@${HOST} "kubeadm alpha phase etcd local --config=/etc/kubernetes/kubeadmcfg.yaml"
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

  sleep 11

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
}

join_master () {
  # push certs to node
# break indentation
  command2run="cat << EOF > etcd-pki-files.txt
/etc/kubernetes/pki/ca.crt
/etc/kubernetes/pki/ca.key
/etc/kubernetes/pki/sa.key
/etc/kubernetes/pki/sa.pub
/etc/kubernetes/pki/front-proxy-ca.crt
/etc/kubernetes/pki/front-proxy-ca.key
EOF"
  ssh ${USER}@${MASTER_HOST} "$command2run"
# unbreak indentation
  command2run="tar -czf etcd-pki.tar.gz -T etcd-pki-files.txt"
  ssh ${USER}@${MASTER_HOST} "$command2run"
  command2run="tar -czf - -T etcd-pki-files.txt"
  ssh ${USER}@${MASTER_HOST} "$command2run" | ssh ${USER}@${MASTER_HOST2} "cd /; tar zxvf -"

  #join the master
  join_cmd=$(cat $finalize_master_tmp/join.sh)
  ssh ${USER}@${MASTER_HOST2} "$join_cmd"
}

join_node () {
  # push certs to node
# break indentation
  command2run="cat << EOF > etcd-pki-files.txt
/etc/kubernetes/pki/ca.crt
/etc/kubernetes/pki/ca.key
/etc/kubernetes/pki/sa.key
/etc/kubernetes/pki/sa.pub
/etc/kubernetes/pki/front-proxy-ca.crt
/etc/kubernetes/pki/front-proxy-ca.key
EOF"
  ssh ${USER}@${MASTER_HOST} "$command2run"
# unbreak indentation
  command2run="tar -czf etcd-pki.tar.gz -T etcd-pki-files.txt"
  ssh ${USER}@${MASTER_HOST} "$command2run"
  command2run="tar -czf - -T etcd-pki-files.txt"
  ssh ${USER}@${MASTER_HOST} "$command2run" | ssh ${USER}@${NODE_HOST} "cd /; tar zxvf -"

  #join the node
  join_cmd=$(cat $finalize_master_tmp/node_join.sh)
  ssh ${USER}@${NODE_HOST} "$join_cmd"
}

main () {
  etcd_setup $ETCD_HOST1 $ETCD_HOST2 $ETCD_HOST3
  finalize_master
  join_node
}

main $@
