#!/usr/bin/env bash

gke_yaml2cluster () {
  yaml2cluster_tmp=$(mktemp -d)
  echo yaml2cluster
  if [[ -z "$1" ]]; then
    croak 3  'gke_yaml2cluster requires an argument'
  fi
  this_yaml=$1
  this_json=$yaml2cluster_tmp/this.json
  yaml2json $this_yaml > $this_json
  gke_json2cluster $this_json
  rm $this_json
  rm -Rf $yaml2cluster_tmp
}

gke_json2cluster () {
  json2cluster_tmp=$(mktemp -d)
  if [[ -z "$1" ]]; then
    croak 3  'json2cluster requires an argument'
  fi
  this_json=$1

  # csv_version
  # should be a string not an int!
  jq -r '.csv_version | "\(.)" ' \
    $this_json > $json2cluster_tmp/csv_version
  # kubernetes_version
  # should be a string not an int!
  jq -r '.kubernetes_version | "\(.)" ' \
    $this_json > $json2cluster_tmp/kubernetes_version
  jq -r '.project | "\(.)" ' \
    $this_json > $json2cluster_tmp/this_tmp
  gke_project=$(cat $json2cluster_tmp/this_tmp)
  jq -r '.cluster_name | "\(.)" ' \
    $this_json > $json2cluster_tmp/this_tmp
  gke_cluster_name=$(cat $json2cluster_tmp/this_tmp)
  jq -r '.zone | "\(.)" ' \
    $this_json > $json2cluster_tmp/this_tmp
  gke_zone=$(cat $json2cluster_tmp/this_tmp)
  jq -r '.username | "\(.)" ' \
    $this_json > $json2cluster_tmp/this_tmp
  gke_username=$(cat $json2cluster_tmp/this_tmp)
  jq -r '.cluster_version | "\(.)" ' \
    $this_json > $json2cluster_tmp/this_tmp
  gke_cluster_version=$(cat $json2cluster_tmp/this_tmp)
  jq -r '.machine_type | "\(.)" ' \
    $this_json > $json2cluster_tmp/this_tmp
  gke_machine_type=$(cat $json2cluster_tmp/this_tmp)
  jq -r '.image_type | "\(.)" ' \
    $this_json > $json2cluster_tmp/this_tmp
  gke_image_type=$(cat $json2cluster_tmp/this_tmp)
  jq -r '.disk_size | "\(.)" ' \
    $this_json > $json2cluster_tmp/this_tmp
  gke_disk_size=$(cat $json2cluster_tmp/this_tmp)
  jq -r '.scopes | "\(.)" ' \
    $this_json > $json2cluster_tmp/this_tmp
  gke_scopes=$(cat $json2cluster_tmp/this_tmp)
  jq -r '.num_nodes | "\(.)" ' \
    $this_json > $json2cluster_tmp/this_tmp
  gke_num_nodes=$(cat $json2cluster_tmp/this_tmp)
  jq -r '.network | "\(.)" ' \
    $this_json > $json2cluster_tmp/this_tmp
  gke_network=$(cat $json2cluster_tmp/this_tmp)
  jq -r '.subnetwork | "\(.)" ' \
    $this_json > $json2cluster_tmp/this_tmp
  gke_subnetwork=$(cat $json2cluster_tmp/this_tmp)
  jq -r '.additional_opts | "\(.)" ' \
    $this_json > $json2cluster_tmp/this_tmp
  gke_additional_opts=$(cat $json2cluster_tmp/this_tmp)

  echo 'Provisioning on GKE with these attributes'

  echo "gke_project=$gke_project
gke_cluster_name=$gke_cluster_name
gke_zone=$gke_zone
gke_username=$gke_username
gke_cluster_version=$gke_cluster_version
gke_machine_type=$gke_machine_type
gke_image_type=$gke_image_type
gke_disk_size=$gke_disk_size
gke_scopes=$gke_scopes
gke_num_nodes=$gke_num_nodes
gke_network=$gke_network
gke_subnetwork=$gke_subnetwork
gke_additional_opts=$gke_additional_opts
"

  echo -n 'Ctrl-C now to stop if this is not what you intend!'
  echo -n '!'; sleep 1; echo -n '!'; sleep 1; echo -n '!'; sleep 1; echo '!'; sleep 1;
  sleep 2

  gke_gcloud_provision $gke_project $gke_cluster_name $gke_zone $gke_username $gke_cluster_version $gke_machine_type $gke_image_type $gke_disk_size $gke_scopes $gke_num_nodes $gke_network $gke_subnetwork "$gke_additional_opts"
}

gke_gcloud_provision () {
  gke_project=$1
  gke_cluster_name=$2
  gke_zone=$3
  gke_username=$4
  gke_cluster_version=$5
  gke_machine_type=$6
  gke_image_type=$7
  gke_disk_size=$8
  gke_scopes=$9
  gke_num_nodes=${10}
  gke_network=${11}
  gke_subnetwork=${12}
  gke_additional_opts=${13}

  echo "gcloud beta container \
  --project '$gke_project' \
  clusters create '$gke_cluster_name' \
  --zone '$gke_zone' \
  --username '$gke_username' \
  --cluster-version '$gke_cluster_version' \
  --machine-type '$gke_machine_type' \
  --image-type '$gke_image_type' \
  --disk-size '$gke_disk_size' \
  --scopes $gke_scopes \
  --num-nodes '$gke_num_nodes' \
  --network '$gke_network' \
  --subnetwork '$gke_subnetwork' \
  $gke_additional_opts"

  gcloud beta container \
    --project "$gke_project" \
    clusters create "$gke_cluster_name" \
    --zone "$gke_zone" \
    --username "$gke_username" \
    --cluster-version "$gke_cluster_version" \
    --machine-type "$gke_machine_type" \
    --image-type "$gke_image_type" \
    --disk-size "$gke_disk_size" \
    --scopes $gke_scopes \
    --num-nodes "$gke_num_nodes" \
    --network "$gke_network" \
    --subnetwork "$gke_subnetwork" \
    $gke_additional_opts

  sleep 3

  KUBECONFIG=$KUBECONFIG \
  gcloud container \
    clusters \
    --zone $gke_zone \
    get-credentials $gke_cluster_name

  KUBECONFIG=$KUBECONFIG \
  kubectl create clusterrolebinding cluster-admin-binding \
    --clusterrole cluster-admin \
    --user $(gcloud config get-value account)
}

gke-provisioner () {
  squawk 1 "gke-provisioner $@"

  if [[ -z "$1" ]]; then
    croak 3  'gke-provisioner requires an argument'
  fi

  if [[ "${1: -5}" == '.yaml' ]]; then
    squawk 1 "gke_yaml2cluster $1"
    gke_yaml2cluster $1
  elif [ "${1: -4}" = ".yml" ]; then
    squawk 1 "gke_yaml2cluster $1"
    gke_yaml2cluster $1
  elif [ "${1: -5}" = ".json" ]; then
    squawk 1 "gke_json2cluster $1"
    gke_json2cluster $1
  fi
}
