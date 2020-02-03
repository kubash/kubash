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
    helm repo add jetstack https://charts.jetstack.io
    #helm repo add istio.io https://storage.googleapis.com/istio-release/releases/1.4.3/charts/
    helm repo update
    helm install \
      --name cert-manager \
      --namespace cert-manager \
      --version v0.13.0 \
      jetstack/cert-manager
    kubectl get pods --namespace cert-manager
    KUBECONFIG=$KUBECONFIG \
    istioctl manifest apply \
      --set profile=sds \
      --set values.kiali.enabled=true \
      --set values.grafana.enabled=true \
      --set values.tracing.enabled=true \
      --set "values.kiali.dashboard.jaegerURL=http://jaeger-query:16686" \
      --set "values.kiali.dashboard.grafanaURL=http://grafana:3000"
      # --set values.prometheus.enabled=true \
      # --set values.certmanager.enabled=true \
    #cd $KUBASH_DIR/submodules/istio/install/kubernetes/helm
    #KUBECONFIG=$KUBECONFIG \
    #helm install \
      #--name=istio-init \
      #--namespace=istio-system \
      #--set gateways.istio-ingressgateway.sds.enabled=true \
      #--set global.k8sIngress.enabled=true \
      #--set certmanager.enabled=true \
      #--set certmanager.email=$LETSENCRYPT_EMAIL \
      #istio-init
    sleep 1
    ISTIO_CRD_COUNT=0
    countzero=0
    while [[ $ISTIO_CRD_COUNT -lt 28 ]]
    do
      ISTIO_CRD_COUNT=$(kubectl get crds | grep 'istio.io\|certmanager.k8s.io' | wc -l)
      if [[ $countzero > 15 ]]; then
        echo "ISTIO_CRD_COUNT=$ISTIO_CRD_COUNT"
      fi
      sleep 1
      ((++countzero))
    done
    #helm repo add istio.io https://storage.googleapis.com/istio-release/releases/1.1.7/charts/
    #KUBECONFIG=$KUBECONFIG \
    #helm install \
      #--name=istio \
      #--namespace=istio-system \
      #$LOAD_BALANCER_IP_SET \
      #--set kiali.enabled=true \
      #--set grafana.enabled=true \
      #--set tracing.enabled=true \
      #--set prometheus.enabled=true \
      #--set certmanager.enabled=true \
      #--set certmanager.email=$LETSENCRYPT_EMAIL \
      #--set global.k8sIngress.enabled=true \
      #--set global.k8sIngress.enableHttps=true \
      #--set gateways.istio-ingressgateway.nodeSelector.ingress=true \
      #--set gateways.istio-ingressgateway.type=$ISTIO_GATEWAY_TYPE \
      #--set gateways.istio-ingressgateway.sds.enabled=true \
      #--set global.k8sIngress.gatewayName=ingressgateway \
      #--set "kiali.dashboard.grafanaURL=http://grafana:3000" \
      #--set "kiali.dashboard.jaegerURL=http://jaeger-query:16686" \
      #istio
    KUBECONFIG=$KUBECONFIG \
    kubectl label namespace default --overwrite istio-injection=enabled
}
