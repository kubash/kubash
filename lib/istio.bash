#!/usr/bin/env bash
do_istio () {
    # Install istio with certmanager
    # https://istio.io/docs/examples/advanced-gateways/ingress-certmgr/
    if [ -z $LETSENCRYPT_EMAIL ]; then
      echo "Type the email that you want to use for lets encrypt, followed by [ENTER]:"
      read LETSENCRYPT_EMAIL
    fi
    if [ -z $LOAD_BALANCER_IP ]; then
      LOAD_BALANCER_IP_SET=""
    else
      #LOAD_BALANCER_IP_SET="--set gateways.istio-ilbgateway.loadBalancerIP=$LOAD_BALANCER_IP"
      LOAD_BALANCER_IP_SET="--set gateways.istio-ingressgateway.loadBalancerIP=$LOAD_BALANCER_IP"
    fi
    cd $KUBASH_DIR/submodules/istio/install/kubernetes/helm
    KUBECONFIG=$KUBECONFIG \
    helm install \
      --name=istio-init \
      --namespace=istio-system \
      --set gateways.istio-ingressgateway.sds.enabled=true \
      --set global.k8sIngress.enabled=true \
      --set certmanager.enabled=true \
      --set certmanager.email=$LETSENCRYPT_EMAIL \
      istio-init
    sleep 1
    ISTIO_CRD_COUNT=0
    countzero=0
    while [[ $ISTIO_CRD_COUNT -lt 58 ]]
    do
      ISTIO_CRD_COUNT=$(kubectl get crds | grep 'istio.io\|certmanager.k8s.io' | wc -l)
      if [[ $countzero > 15 ]]; then
        echo "ISTIO_CRD_COUNT=$ISTIO_CRD_COUNT"
      fi
      sleep 1
      ((++countzero))
    done
    KUBECONFIG=$KUBECONFIG \
    helm install \
      --name=istio \
      --namespace=istio-system \
      --set gateways.istio-ingressgateway.sds.enabled=true \
      $LOAD_BALANCER_IP_SET \
      --set global.k8sIngress.enabled=true \
      --set global.k8sIngress.enableHttps=true \
      --set global.k8sIngress.gatewayName=ingressgateway \
      --set certmanager.enabled=true \
      --set certmanager.email=$LETSENCRYPT_EMAIL \
      istio
    KUBECONFIG=$KUBECONFIG \
    kubectl label namespace default --overwrite istio-injection=enabled
}
