#!/usr/bin/env bash

w8_kubedns () {
  squawk 3 "wait on Kube-DNS to become available" -n
  sleep 1

  # while loop
  kubedns_countone=1
  # timeout for 15 minutes
  while [[ $kubedns_countone -lt 151 ]]
  do
    squawk 1 '.' -n
    RESULT=$(kubectl --kubeconfig=$KUBECONFIG get po --namespace kube-system |grep kube-dns|grep Running)
    if [[ "$RESULT" ]]; then
        sleep 3
        squawk 1 '.' -n
        squawk 3 "$RESULT"
        break
    fi
    ((++kubedns_countone))
    sleep 3
  done

  echo "Kube-DNS is now up and running"
  sleep 1
}

w8_kubectl () {
  squawk 3 "Wait on the K8S cluster to become available" -n
  squawk 3 "Errors on the first few tries are normal give it a few minutes to spin up" -n
  sleep 15
  # while loop
  countone_w8_kubectl=1
  countlimit_w8_kubectl=151
  # timeout for 15 minutes
  while [[ "$countone_w8_kubectl" -lt "$countlimit_w8_kubectl" ]]; do
    squawk 1 '.' -n
    if [[ "$VERBOSITY" -gt "11" ]] ; then
      squawk 105 "kubectl --kubeconfig=$KUBECONFIG get pods -n kube-system | grep kube-apiserver"
      kubectl --kubeconfig=$KUBECONFIG get pods -n kube-system | grep kube-apiserver
    fi
    result=$(kubectl --kubeconfig=$KUBECONFIG get pods -n kube-system 2>/dev/null | grep kube-apiserver |grep Running)
    squawk 3 "Result is $result"
    if [[ "$result" ]]; then
      squawk 5 "Result nailed $result"
      ((++countone_w8_kubectl))
      break
    fi
    ((++countone_w8_kubectl))
    squawk 209 "$countone_w8_kubectl"
    if [[ "$countone_w8_kubectl" -ge "$countlimit_w8_kubectl"  ]]; then
      croak 3  'Master is not coming up, investigate, breaking'
    fi
    sleep 5
  done
  squawk 3  "."
  squawk 1 "kubectl commands are now able to interact with the kubernetes cluster"
}

w8_node () {
  node_name=$1
  squawk 3 "Wait on the K8S node $node_name to become available" -n
  sleep 5
  # while loop
  countone_w8_node=1
  countlimit_w8_node=151
  # timeout for 15 minutes
  set +e
  while [[ "$countone_w8_node" -lt "$countlimit_w8_node" ]]; do
    squawk 1 '.' -n
    if [[ "$VERBOSITY" -gt "11" ]] ; then
      squawk 105  "kubectl --kubeconfig=$KUBECONFIG get node $node_name"
      kubectl --kubeconfig=$KUBECONFIG get node $node_name
    fi
    result=$(kubectl --kubeconfig=$KUBECONFIG get node $node_name | grep -v NotReady | grep Ready)
    squawk 133 "Result is $result"
    if [[ "$result" ]]; then
      squawk 5 "Result nailed $result"
      ((++countone_w8_node))
      break
    fi
    ((++countone_w8_node))
    squawk 209 "$countone_w8_node"
    sleep 3
  done
  set -e
  squawk 3  "."
  squawk 3  "kubectl commands are now able to interact with the kubernetes node"
}
