#!/usr/bin/env bash

mkconsul_consulk8s () {
  if [[  -f $thisDir/consul-values.yaml ]]; then
    consul-k8s install -auto-approve=true \
      -f $thisDir/consul-values.yaml . 
  else
    echo "Create $thisDir/consul-values.yaml first and then retry"
    exit 1
  fi
}

mkconsul_helmmethod () {
  if [[  -f $thisDir/consul-values.yaml ]]; then
      squawk 20 "I found $thisDir/consul-values.yaml"
      squawk 20 "Using that as our values file."
  else
    echo "Create $thisDir/consul-values.yaml first and then retry"
    exit 1
  fi
  do_hashicorp
  helm install \
    -f $thisDir/consul-values.yaml \
    consul hashicorp/consul \
    --create-namespace -n consul --version "$CONSUL_VERSION"
}

do_consul () {
  if [[ "$CONSUL_METHOD" == 'helm' ]]; then
    mkconsul_helmmethod
  else
    mkconsul_consulk8s
  fi

  kubectl get pods --namespace consul --selector app=consul
}
