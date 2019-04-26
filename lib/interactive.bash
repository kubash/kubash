#!/usr/bin/env bash

kubash_interactive () {
  horizontal_rule
  echo "Interactive Kubash Shell Enter 'help' for help, 'kh' for kubectl help or 'quit' to quit"
  echo "working with the $KUBASH_CLUSTER_NAME kubash cluster, or set with 'clustername'"
  set +e

  while true
  do
    myinput=$(rlwrap -f $KUBASH_DIR/.kubash_completions -s $KUBASH_HISTORY_LIMIT -S 'K8$ ' -H $KUBASH_HISTORY -D2 head -n1)
    read command args <<< $myinput
    squawk 29 "$command $args"
    case $command
    in
      quit|exit)             exit 0                       ;;
      help|\?)               interactive_usage            ;;
      khelp|kh)               kubectl_interactive_usage   ;;
      verbosity)             set_verbosity $args          ;;
      v)                increase_verbosity $args          ;;
      switch|use|n|cluster|name) set_name  $args          ;;
      k|kubectl) kubectl_passthru $args                   ;;
      h|helm) helm_passthru $args                         ;;
      g|get) kubectl_passthru get $args                   ;;
      l|list) helm_passthru list                          ;;
      d|describe) kubectl_passthru describe $args         ;;
      keti) kubectl_passthru exec -ti $args               ;;
      kgn) kubectl_passthru get nodes $args               ;;
      kgpa) kubectl_passthru get pods --all-namespaces $args | grep -v '^pvc-' ;;
      kgp) kubectl_passthru get pods $args | grep -v '^pvc-' ;;
      kgpvc) kubectl_passthru get pods $args | grep '^pvc-' ;;
      klp) kubectl_passthru logs pods $args               ;;
      kep) kubectl_passthru logs pods $args               ;;
      kdp) kubectl_passthru describe pods $args           ;;
      kdelp) kubectl_passthru delete pods $args           ;;
      kgs) kubectl_passthru get svc $args                 ;;
      kes) kubectl_passthru edit svc $args                ;;
      kds) kubectl_passthru describe svc $args            ;;
      kdels) kubectl_passthru delete svc $args            ;;
      kgsec) kubectl_passthru get secret $args            ;;
      kdsec) kubectl_passthru decribe secret $args        ;;
      kdelsec) kubectl_passthru delete secret $args       ;;
      kgd) kubectl_passthru get deployment $args          ;;
      ked) kubectl_passthru edit deployment $args         ;;
      kei) kubectl_passthru edit ingress.voyager.appscode.com $args ;;
      kdd) kubectl_passthru describe deployment $args     ;;
      kdeld) kubectl_passthru delete deployment $args     ;;
      ksd) kubectl_passthru scale deployment $args        ;;
      krsd) kubectl_passthru rollout status deployment $args ;;
      kgrs) kubectl_passthru get rs $args                 ;;
      krh) kubectl_passthru get rollout history $args     ;;
      kru) kubectl_passthru get rollout undo $args        ;;
      *) interactive_results=$(kubash -n $KUBASH_CLUSTER_NAME $command $args) ;;
    esac
    echo "$interactive_results"
  done
  set -e
}

kubectl_passthru () {
    squawk 5 "kubectl --kubeconfig=$KUBASH_CLUSTER_DIR/config $@"
    kubectl --kubeconfig=$KUBASH_CLUSTER_DIR/config $@
}

helm_passthru () {
    squawk 5 "KUBECONFIG=$KUBASH_CLUSTER_DIR/config helm $@"
    KUBECONFIG=$KUBASH_CLUSTER_DIR/config helm $@
}
