#!/usr/bin/env bash

do_vault () {
  if [[ -f $thisDir/vault-values.yaml ]]; then
    do_hashicorp
    helm install \
      -n default \
      -f $thisDir/vault-values.yaml \
      vault hashicorp/vault
    $KUBASH_DIR/w8s/generic.w8 vault-0 default
    kubectl exec vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > $thisDir/cluster-keys.json
    VAULT_UNSEAL_KEY=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[]")
    CLUSTER_ROOT_TOKEN=$(cat cluster-keys.json | jq -r ".root_token")
    kubectl exec vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY
    kubectl exec vault-0 -- vault login $CLUSTER_ROOT_TOKEN
    kubectl exec vault-1 -- vault operator unseal $VAULT_UNSEAL_KEY
    kubectl exec vault-2 -- vault operator unseal $VAULT_UNSEAL_KEY
    kubectl get pods
  else
    croak 0 "Create $thisDir/vault-values.yaml then retry"
  fi
}
