#!/bin/bash
USER=root
my_KUBE_CIDR="10.244.0.0/16"

ETCDHOSTS=($@)

for i in "${!ETCDHOSTS[@]}"; do
  HOST=${ETCDHOSTS[$i]}

  # break indentation
  command2run='cat << EOF > /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
[Service]
ExecStart=
ExecStart=/usr/bin/kubelet --config=/var/lib/kubelet/config.yaml
Restart=always
EOF'
  # unbreak indentation

  echo "ssh ${USER}@${HOST} $command2run"
  ssh ${USER}@${HOST} "$command2run"

  # break indentation
  command2run='cat << EOF > /var/lib/kubelet/config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: 127.0.0.1
staticPodPath: /etc/kubernetes/manifests
EOF'
  # unbreak indentation
  echo "ssh ${USER}@${HOST} $command2run"
  ssh ${USER}@${HOST} "$command2run"
  command2run='systemctl daemon-reload'
  echo "ssh ${USER}@${HOST} $command2run"
  ssh ${USER}@${HOST} "$command2run"
  command2run='systemctl restart kubelet'
  echo "ssh ${USER}@${HOST} $command2run"
  ssh ${USER}@${HOST} "$command2run"
done