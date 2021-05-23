#!/usr/bin/env bash
do_istio () {

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: default-secret
  annotations:
    kubernetes.io/service-account.name: default
type: kubernetes.io/service-account-token
EOF


    KUBECONFIG=$KUBECONFIG \
    istioctl install \
      --set profile=$ISTIO_PROFILE \
      --set "values.kiali.dashboard.jaegerURL=http://jaeger-query:16686" \
      --set "values.global.tracer.zipkin.address=jaeger-collector:9411" \
      --set "values.kiali.dashboard.grafanaURL=http://grafana:3000"
      # deprecated
      #--set values.kiali.enabled=true \
      #--set values.tracing.enabled=true \

    KUBECONFIG=$KUBECONFIG \
    kubectl label namespace default --overwrite istio-injection=enabled
    echo 'https://istio.io/latest/docs/setup/getting-started/'
    kubectl apply -n istio-system -f $KUBASH_DIR/submodules/istio/samples/addons/
}
