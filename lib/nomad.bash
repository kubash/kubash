#!/usr/bin/env bash

get_hashi_ips () {
  $KUBASH_DIR/w8s/genericService.w8 consul-internal-load-balancer  default
  $KUBASH_DIR/w8s/genericService.w8 nomad default
  $KUBASH_DIR/w8s/genericService.w8 vault default
  sleep 1

  CONSUL_INTERNAL_IP=$(kubectl get svc consul-internal-load-balancer \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

  NOMAD_EXTERNAL_IP=$(kubectl get svc nomad \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

  VAULT_EXTERNAL_IP=$(kubectl get svc vault \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
}

init_nomad_dir () {
  if [[ ! -d $NOMAD_ON_KUBERNETES ]]; then
    cp -a ~/.kubash/submodules/nomad-on-kubernetes $KUBASH_CLUSTER_DIR/
  elif [[ -d $NOMAD_ON_KUBERNETES ]]; then
    squawk 3 "WARN: $KUBASH_CLUSTER_DIR exists using it! Clear this directory if you want to reinitialize."
  else
    croak 3 "ERROR: $KUBASH_CLUSTER_DIR is not a writeable directory!"
  fi
}

init_hashi_keys () {
  NOMAD_ON_KUBERNETES="$KUBASH_CLUSTER_DIR/nomad-on-kubernetes"
  cd $NOMAD_ON_KUBERNETES
  if [[ -f  $NOMAD_ON_KUBERNETES/vault-combined.pem ]]; then
    echo 'certs already made'
  else
    # certs
    # cd $TMP
    cfssl gencert -initca ca/ca-csr.json | cfssljson -bare ca
    # vault
    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca/ca-config.json \
      -hostname="consul,consul.${NAMESPACE}.svc.cluster.local,localhost,server.dc1.consul,127.0.0.1,${CONSUL_INTERNAL_IP}" \
      -profile=default \
      ca/consul-csr.json | cfssljson -bare consul
    # consul
    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca/ca-config.json \
      -hostname="vault,vault.${NAMESPACE}.svc.cluster.local,localhost,vault.dc1.consul,vault.service.consul,127.0.0.1,${VAULT_EXTERNAL_IP}" \
      -profile=default \
      ca/vault-csr.json | cfssljson -bare vault
    cat vault.pem ca.pem > vault-combined.pem
    # nomad
    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca/ca-config.json \
      -hostname="localhost,client.global.nomad,nomad,nomad.${NAMESPACE}.svc.cluster.local,global.nomad,server.global.nomad,127.0.0.1,${NOMAD_EXTERNAL_IP}" \
      -profile=default \
      ca/nomad-csr.json | cfssljson -bare nomad
  fi

  if [[ -f  $NOMAD_ON_KUBERNETES/.gossip_encryption_key ]]; then
    echo 'key already made'
    GOSSIP_ENCRYPTION_KEY=$(cat $NOMAD_ON_KUBERNETES/.gossip_encryption_key)
  else
    GOSSIP_ENCRYPTION_KEY=$(consul keygen)
    echo $GOSSIP_ENCRYPTION_KEY > $NOMAD_ON_KUBERNETES/.gossip_encryption_key
  fi
  if [[ ! -f $KUBASH_CLUSTER_DIR/.consul.secret.created ]]; then
    kubectl create secret generic consul \
      --from-literal="gossip-encryption-key=${GOSSIP_ENCRYPTION_KEY}" \
      --from-file=ca.pem \
      --from-file=consul.pem \
      --from-file=consul-key.pem
    date -I >> $KUBASH_CLUSTER_DIR/.consul.secret.created
  fi

  if [[ ! -f $KUBASH_CLUSTER_DIR/.vault.secret.created ]]; then
    kubectl create secret generic vault \
      --from-file=ca.pem \
      --from-file=vault.pem=vault-combined.pem \
      --from-file=vault-key.pem
    date -I >> $KUBASH_CLUSTER_DIR/.vault.secret.created
  fi

  if [[ ! -f $KUBASH_CLUSTER_DIR/.nomad.secret.created ]]; then
    kubectl create secret generic nomad \
      --from-file=ca.pem \
      --from-file=nomad.pem \
      --from-file=nomad-key.pem
    date -I >> $KUBASH_CLUSTER_DIR/.nomad.secret.created
  fi

  kubectl get secrets
}

provision_nomad_node_worker () {
  NOMAD_ON_KUBERNETES="$KUBASH_CLUSTER_DIR/nomad-on-kubernetes"
  cd $NOMAD_ON_KUBERNETES
  # Provision Node Worker
  # Lot's of cat EOF  in here leaving unindented
  squawk 5 "provision_nomad_node_worker $@"
  THIS_NOMAD_WORKER=$1
  THIS_NOMAD_USER=$2
  THIS_NOMAD_PORT=$3

  squawk 55 "ssh -p $THIS_NOMAD_PORT $THIS_NOMAD_USER@$THIS_NOMAD_WORKER 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -yqq wget unzip'"
  ssh -p $THIS_NOMAD_PORT $THIS_NOMAD_USER@$THIS_NOMAD_WORKER "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -yqq wget unzip"
  #scp $(which nomad) -P $THIS_NOMAD_PORT $THIS_NOMAD_USER@$THIS_NOMAD_WORKER:/usr/local/bin/

  TMP=$(mktemp -d)
  cd $TMP

  pwd
  ls -alh
  squawk 5 "create provisioner.sh"
cat > provisioner.sh <<EOF
## Configure and Start Nomad
mkdir -p /etc/nomad
mkdir -p /etc/nomad/tls
mkdir -p /var/lib/nomad
echo "${CA_CERT}" > /etc/nomad/tls/ca.pem
echo "${NOMAD_CERT}" > /etc/nomad/tls/nomad.pem
echo "${NOMAD_KEY}" > /etc/nomad/tls/nomad-key.pem
EOF

  chmod +x provisioner.sh
  #scp provisioner.sh -P $THIS_NOMAD_PORT $THIS_NOMAD_USER@$THIS_NOMAD_WORKER:/root/provisioner.sh
  tar cf - provisioner.sh|ssh -p $THIS_NOMAD_PORT $THIS_NOMAD_USER@$THIS_NOMAD_WORKER "tar xf - && bash ./provisioner.sh"

  #old style with port
    #http = "${THIS_NOMAD_WORKER}:4646"
    #rpc = "${THIS_NOMAD_WORKER}:4647"

  pwd
  ls -alh
cat > client.hcl <<EOF
advertise {
  http = "${THIS_NOMAD_WORKER}"
  rpc = "${THIS_NOMAD_WORKER}"
  serf = "${THIS_NOMAD_WORKER}"
}

bind_addr = "${THIS_NOMAD_WORKER}"

client {
  enabled = true
  options {
    "driver.raw_exec.enable" = "1"
  }

  server_join {
    retry_join = [ "${NOMAD_EXTERNAL_IP}" ]
    retry_max = 3
    retry_interval = "15s"
  }
}

data_dir = "/var/lib/nomad"
log_level = "DEBUG"

tls {
  ca_file = "/etc/nomad/tls/ca.pem"
  cert_file = "/etc/nomad/tls/nomad.pem"
  http = true
  key_file = "/etc/nomad/tls/nomad-key.pem"
  rpc = true
  verify_https_client = true
}

vault {
  address = "https://${VAULT_EXTERNAL_IP}:8200"
  ca_path = "/etc/nomad/tls/ca.pem"
  cert_file = "/etc/nomad/tls/nomad.pem"
  enabled = true
  key_file = "/etc/nomad/tls/nomad-key.pem"
}
EOF

  pwd
  ls -alh
  echo "scp -P $THIS_NOMAD_PORT client.hcl $THIS_NOMAD_USER@$THIS_NOMAD_WORKER:/etc/nomad/client.hcl"
  squawk 5 "scp -P $THIS_NOMAD_PORT client.hcl $THIS_NOMAD_USER@$THIS_NOMAD_WORKER:/etc/nomad/client.hcl"
  scp -P $THIS_NOMAD_PORT client.hcl $THIS_NOMAD_USER@$THIS_NOMAD_WORKER:/etc/nomad/client.hcl

cat > nomad.service <<'EOF'
[Unit]
Description=Nomad
Documentation=https://nomadproject.io/docs

[Service]
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad/client.hcl
ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

  squawk 5 "scp -P $THIS_NOMAD_PORT nomad.service $THIS_NOMAD_USER@$THIS_NOMAD_WORKER:/etc/systemd/system/nomad.service"
  scp -P $THIS_NOMAD_PORT nomad.service $THIS_NOMAD_USER@$THIS_NOMAD_WORKER:/etc/systemd/system/nomad.service
  rm -Rf $TMP
  #ssh -p $THIS_NOMAD_PORT $THIS_NOMAD_USER@$THIS_NOMAD_WORKER systemctl enable --now nomad
  ssh -p $THIS_NOMAD_PORT $THIS_NOMAD_USER@$THIS_NOMAD_WORKER systemctl enable nomad
  ssh -p $THIS_NOMAD_PORT $THIS_NOMAD_USER@$THIS_NOMAD_WORKER systemctl restart nomad
}

init_nomad_in_kubernetes () {
  NOMAD_ON_KUBERNETES="$KUBASH_CLUSTER_DIR/nomad-on-kubernetes"
  init_nomad_dir
  cd $NOMAD_ON_KUBERNETES
  kubectl apply -f services
  kubectl get services
  get_hashi_ips
  init_hashi_keys


  kubectl apply -f configmaps/consul.yaml
  kubectl apply -f statefulsets/consul.yaml
  ~/.kubash/w8s/generic.w8 consul-0 default
  ~/.kubash/w8s/generic.w8 consul-1 default
  ~/.kubash/w8s/generic.w8 consul-2 default
  kubectl get pods -l app=consul

  # contains EOFS so leaving unindented
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    addonmanager.kubernetes.io/mode: EnsureExists
  name: kube-dns
  namespace: kube-system
data:
  stubDomains: |
    {"consul": ["$(kubectl get svc consul-dns -o jsonpath='{.spec.clusterIP}')"]}
EOF

  # vault
  kubectl apply -f configmaps/vault.yaml
  kubectl apply -f statefulsets/vault.yaml
  ~/.kubash/w8s/generic.w8 vault-0 default
  kubectl get pods -l app=vault
  source vault.env
  if [[ ! -f $KUBASH_CLUSTER_DIR/.vault.init ]]; then
    vault operator init &> $NOMAD_ON_KUBERNETES/unseal_keys
    sleep 1
    vault operator unseal $(grep 'Unseal Key 1' $NOMAD_ON_KUBERNETES/unseal_keys|awk '{print $4}')
    sleep 1
    vault operator unseal $(grep 'Unseal Key 2' $NOMAD_ON_KUBERNETES/unseal_keys|awk '{print $4}')
    sleep 1
    vault operator unseal $(grep 'Unseal Key 3' $NOMAD_ON_KUBERNETES/unseal_keys|awk '{print $4}')
    sleep 3
    vault login $(grep 'Initial Root Token' $NOMAD_ON_KUBERNETES/unseal_keys|awk '{print $4}')
    vault policy write nomad-server nomad-server-policy.hcl
    vault write /auth/token/roles/nomad-cluster @nomad-cluster-role.json
    date -I >> $KUBASH_CLUSTER_DIR/.vault.init
  fi
  vault status

  # nomad
  if [[ ! -f $NOMAD_ON_KUBERNETES/.nomad-vault-token ]]; then
    NOMAD_VAULT_TOKEN=$(vault token create \
      -policy nomad-server \
      -period 72h \
      -orphan \
      -format json | tee $NOMAD_ON_KUBERNETES/.nomad-vault-token | jq -r '.auth.client_token')
  fi

  if [[ ! -f $KUBASH_CLUSTER_DIR/.nomad.secret2.created ]]; then
    kubectl create secret generic nomad \
      --from-file=ca.pem \
      --from-file=nomad.pem \
      --from-file=nomad-key.pem \
      --from-literal=vault-token=${NOMAD_VAULT_TOKEN} -o yaml --dry-run=client | \
      kubectl replace -f -
    date -I >> $KUBASH_CLUSTER_DIR/.nomad.secret2.created
  fi

  kubectl describe secret nomad

  kubectl apply -f configmaps/nomad.yaml

  kubectl apply -f statefulsets/nomad.yaml
  ~/.kubash/w8s/generic.w8 nomad-0 default
  ~/.kubash/w8s/generic.w8 nomad-1 default
  ~/.kubash/w8s/generic.w8 nomad-2 default
  kubectl get pods -l app=nomad
  sleep 3
  source nomad.env
  nomad server members
  nomad_nodes
}

nomad_nodes () {
  #get_hashi_ips
  #NOMAD_VAULT_TOKEN=$(cat $NOMAD_ON_KUBERNETES/.nomad-vault-token | jq -r '.auth.client_token')

  #cd $NOMAD_ON_KUBERNETES
  #source $NOMAD_ON_KUBERNETES/nomad.env

  CA_CERT=$(cat ca.pem)
  #EXTERNAL_IP=$(hostname -I|tr ' ' '\n'|grep '10.0.23'|tail -n1)
  #GOSSIP_ENCRYPTION_KEY=$(cat $NOMAD_ON_KUBERNETES/.gossip_encryption_key)
  NOMAD_CERT=$(cat nomad.pem)
  NOMAD_KEY=$(cat nomad-key.pem)

  if [[ -z "$kubash_hosts_csv_slurped" ]]; then
    hosts_csv_slurp
  fi
  countzero_do_nodes=0
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    squawk 93 "starting count $countzero_do_nodes"
    if [[ "$K8S_role" == "nomad_worker" ]]; then
      if [[ ! -f "$KUBASH_CLUSTER_DIR/${K8S_node}.nomad" ]]; then
        provision_nomad_node_worker $K8S_ip1 $K8S_user $K8S_sshPort
        date -I >> "$KUBASH_CLUSTER_DIR/${K8S_node}.nomad"
      else
        squawk 2 "WARNING: $KUBASH_CLUSTER_DIR/${K8S_node}.nomad already exists skipping"
      fi
    else
      squawk 91 " K8S_role NOT nomad worker"
      squawk 91 " K8S_role $K8S_role $K8S_ip1 $K8S_user $K8S_sshPort"
    fi
    ((++countzero_do_nodes))
    squawk 3 "ending count $countzero_do_nodes"
  done <<< "$kubash_hosts_csv_slurped"
}
