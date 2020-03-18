#!/usr/bin/env bash
do_istio () {
    #KUBECONFIG=$KUBECONFIG \
    #kubectl apply -f $KUBASH_DIR/templates/trustworthy-jwt.yaml
    # Install istio with certmanager
    # https://istio.io/docs/examples/advanced-gateways/ingress-certmgr/
    if [ -z $LETSENCRYPT_EMAIL ]; then
      echo "Type the email that you want to use for lets encrypt, followed by [ENTER]:"
      read LETSENCRYPT_EMAIL
    fi
    if [ -z $LOAD_BALANCER_IP ]; then
      LOAD_BALANCER_IP_SET=""
    else
      LOAD_BALANCER_IP_SET="--set values.gateways.istio-ingressgateway.loadBalancerIP=$LOAD_BALANCER_IP"
    fi
    KUBECONFIG=$KUBECONFIG \
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    # Install Cert-manager
    helm install \
      --kubeconfig $KUBECONFIG \
      --name cert-manager \
      --namespace cert-manager \
      --version v0.13.0 \
      jetstack/cert-manager
    KUBECONFIG=$KUBECONFIG \
    kubectl get pods --namespace cert-manager
    # Install Istio
    KUBECONFIG=$KUBECONFIG \
    istioctl manifest apply \
      --wait \
      --set profile=sds \
      --set values.kiali.enabled=true \
      --set values.grafana.enabled=true \
      --set values.tracing.enabled=true \
      --set values.prometheus.enabled=true \
      --set values.certmanager.enabled=true \
      --set values.gateways.istio-ingressgateway.sds.enabled=true \
      --set values.global.k8sIngress.enabled=true \
      --set values.global.k8sIngress.enableHttps=true \
      --set values.global.k8sIngress.gatewayName=ingressgateway \
      $LOAD_BALANCER_IP_SET \
      --set "values.kiali.dashboard.jaegerURL=http://jaeger-query:16686" \
      --set "values.kiali.dashboard.grafanaURL=http://grafana:3000"
    KUBECONFIG=$KUBECONFIG \
    kubectl label namespace default --overwrite istio-injection=enabled
}
