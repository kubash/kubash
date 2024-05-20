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

    KUBECONFIG=$KUBECONFIG \
    helm repo add istio https://istio-release.storage.googleapis.com/charts
    KUBECONFIG=$KUBECONFIG \
    helm repo update
    KUBECONFIG=$KUBECONFIG \
    kubectl create namespace istio-system

    DEPRECATED_COMMON_ARGS="--namespace=istio-system \
      $LOAD_BALANCER_IP_SET \
      --set kiali.enabled=true \
      --set grafana.enabled=true \
      --set tracing.enabled=true \
      --set prometheus.enabled=true \
      --set certmanager.enabled=true \
      --set certmanager.email=$LETSENCRYPT_EMAIL \
      --set global.k8sIngress.enabled=true \
      --set global.k8sIngress.enableHttps=true \
      --set gateways.istio-ingressgateway.nodeSelector.ingress=true \
      --set gateways.istio-ingressgateway.type=$ISTIO_GATEWAY_TYPE \
      --set gateways.istio-ingressgateway.sds.enabled=true \
      --set global.k8sIngress.gatewayName=ingressgateway \
      --set 'kiali.dashboard.grafanaURL=http://grafana:3000' \
      --set 'kiali.dashboard.jaegerURL=http://jaeger-query:16686"

    BASE_ARGS="--set global.istioNamespace='istio-system' \
      --set global.istiod.enalbleAnalytics=true"

    COMMON_ARGS="--namespace=istio-system"

    KUBECONFIG=$KUBECONFIG \
    helm install istio-base istio/base -n istio-system \
      $BASE_ARGS \
      $COMMON_ARGS

    KUBECONFIG=$KUBECONFIG \
    helm install istiod istio/istiod -n istio-system --wait \
      $COMMON_ARGS

    KUBECONFIG=$KUBECONFIG \
    kubectl label namespace default --overwrite istio-injection=enabled

    KUBECONFIG=$KUBECONFIG \
    kubectl create namespace istio-ingress
    KUBECONFIG=$KUBECONFIG \
    kubectl label namespace istio-ingress istio-injection=enabled
    KUBECONFIG=$KUBECONFIG \
    helm install istio-ingress istio/gateway -n istio-ingress --wait
}

demo_istio () {
  PRE_CWD=$(pwd)
  istioctl install --set profile=demo -y
  kubectl label namespace default istio-injection=enabled
  cd $KUBASH_DIR/submodules/istio
  kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
  kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
  export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
  export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
  export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
  echo "$GATEWAY_URL"
  echo "http://$GATEWAY_URL/productpage"
  kubectl apply -f samples/addons
  kubectl rollout status deployment/kiali -n istio-system
  echo "Info: https://istio.io/latest/docs/setup/getting-started/"
  cd ${PRE_CWD}
}
