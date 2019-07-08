#!/usr/bin/env bash

do_nginx_ingress () {
  INGRESS_NAME=$1
  KUBECONFIG=$KUBECONFIG \
    helm install \
    stable/nginx-ingress \
    --name $INGRESS_NAME \
    --set rbac.create=true
}

taint_ingress () {
  squawk 1 " taint_ingress $@"
  count_ingress=0
  for ingress_node in "$@"
  do
    squawk 5 "kubectl --kubeconfig=$KUBECONFIG taint --overwrite node $ingress_node IngressOnly=true:NoSchedule"
    kubectl --kubeconfig=$KUBECONFIG taint --overwrite node $ingress_node IngressOnly=true:NoSchedule
    squawk 5 "kubectl --kubeconfig=$KUBECONFIG label --overwrite node $ingress_node ingress=true"
    kubectl --kubeconfig=$KUBECONFIG label --overwrite node $ingress_node ingress=true
    ((++count_ingress))
  done
  if [[ $count_ingress -eq 0 ]]; then
    croak 3  'No ingress nodes found!'
  fi
}

taint_all_ingress () {
  squawk 1 " taint_all_ingress $@"
  count_all_ingress=0
  nodes_to_taint=' '
  while IFS="," read -r $csv_columns
  do
    squawk 185 "ROLE $K8S_role $K8S_user $K8S_ip1 $K8S_sshPort"
    if [[ "$K8S_role" = "ingress" ]]; then
      squawk 5 "ROLE $K8S_role $K8S_user $K8S_ip1 $K8S_sshPort"
      squawk 121 "nodes_to_taint $K8S_node $nodes_to_taint"
      new_nodes_to_taint="$K8S_node $nodes_to_taint"
      nodes_to_taint="$new_nodes_to_taint"
      ((++count_all_ingress))
    fi
  done <<< "$kubash_hosts_csv_slurped"
  echo "count_all_ingress $count_all_ingress"
  if [[ $count_all_ingress -eq 0 ]]; then
    squawk 150 "slurpy -----> $(echo $kubash_hosts_csv_slurped)"
    croak 3  'No ingress nodes found!!!'
  else
    squawk 185 "ROLE $K8S_role $K8S_user $K8S_ip1 $K8S_sshPort"
    squawk 101 "taint these nodes_to_taint=$K8S_node $nodes_to_taint"
    taint_ingress $nodes_to_taint
  fi
}

mark_ingress () {
  squawk 1 " mark_ingress $@"
  count_ingress=0
  for ingress_node in "$@"
  do
    squawk 5 "kubectl --kubeconfig=$KUBECONFIG label --overwrite node $ingress_node ingress=true"
    kubectl --kubeconfig=$KUBECONFIG label --overwrite node $ingress_node ingress=true
    ((++count_ingress))
  done
  if [[ $count_ingress -eq 0 ]]; then
    croak 3  'No ingress nodes found!'
  fi
}

mark_all_ingress () {
  squawk 1 " mark_all_ingress $@"
  count_all_ingress=0
  nodes_to_mark=' '
  while IFS="," read -r $csv_columns
  do
    squawk 185 "ROLE $K8S_role $K8S_user $K8S_ip1 $K8S_sshPort"
    if [[ "$K8S_role" = "ingress" ]]; then
      squawk 5 "ROLE $K8S_role $K8S_user $K8S_ip1 $K8S_sshPort"
      squawk 121 "nodes_to_mark $K8S_node $nodes_to_mark"
      new_nodes_to_mark="$K8S_node $nodes_to_mark"
      nodes_to_mark="$new_nodes_to_mark"
      ((++count_all_ingress))
    fi
  done <<< "$kubash_hosts_csv_slurped"
  echo "count_all_ingress $count_all_ingress"
  if [[ $count_all_ingress -eq 0 ]]; then
    squawk 150 "slurpy -----> $(echo $kubash_hosts_csv_slurped)"
    croak 3  'No ingress nodes found!!!'
  else
    squawk 185 "ROLE $K8S_role $K8S_user $K8S_ip1 $K8S_sshPort"
    squawk 101 "mark these nodes_to_mark=$K8S_node $nodes_to_mark"
    mark_ingress $nodes_to_mark
  fi
}

do_voyager () {
  squawk 1 " do_voyager"
  taint_all_ingress
  if [ "$VOYAGER_BY_HELM" = "stable" ]; then
  KUBECONFIG=$KUBECONFIG \
  helm install stable/voyager --name voyager \
    --set cloudProvider=$VOYAGER_PROVIDER \
    --set apiserver.ca="$(onessl get kube-ca)" \
    $VOYAGER_ADMISSIONWEBHOOK
  elif [ "$VOYAGER_BY_HELM" = "appscode" ]; then
  KUBECONFIG=$KUBECONFIG \
  helm repo add appscode https://charts.appscode.com/stable/
  helm repo update
  helm install appscode/voyager \
    --name voyager-operator \
    --version $VOYAGER_VERSION \
    --namespace kube-system \
    --set cloudProvider=$VOYAGER_PROVIDER \
    --set apiserver.ca="$(onessl get kube-ca)" \
    $VOYAGER_ADMISSIONWEBHOOK
  else
    KUBECONFIG=$KUBECONFIG \
    curl -fsSL \
    https://raw.githubusercontent.com/appscode/voyager/$VOYAGER_VERSION/hack/deploy/voyager.sh \
        | bash -s -- --provider=$VOYAGER_PROVIDER --rbac
  fi
}

do_linkerd () {
  squawk 1 " do_linkerd"
  kubectl --kubeconfig=$KUBECONFIG \
    create ns l5d-system
  kubectl --kubeconfig=$KUBECONFIG \
    -n l5d-system \
    apply -f \
    $LINKERD_URL
  squawk 1 "kubectl create ns l5d-system"
  squawk 1 "kubectl apply -f https://raw.githubusercontent.com/linkerd/linkerd-examples/master/k8s-daemonset/k8s/linkerd-ingress-controller.yml -n l5d-system"
  squawk 1 "visit this page: https://buoyant.io/2017/04/06/a-service-mesh-for-kubernetes-part-viii-linkerd-as-an-ingress-controller/"
}

do_traefik () {
  squawk 1 " do_traefik"
  if [[ $USE_TRAEFIK_RBAC == 'true' ]]; then
    kubectl --kubeconfig=$KUBECONFIG apply -f \
    $KUBASH_DIR/templates/traefik-rbac.yaml
  fi

  if [[ $USE_TRAEFIK_DAEMON_SET == 'true' ]]; then
    TRAEFIK_URL=$KUBASH_DIR/templates/traefik-ds.yaml
  else
    TRAEFIK_URL=$KUBASH_DIR/templates/traefik-deployment.yaml
  fi
  kubectl --kubeconfig=$KUBECONFIG apply -f \
    $TRAEFIK_URL
}
