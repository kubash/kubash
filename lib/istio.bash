#!/usr/bin/env bash
do_istio () {
  squawk 3 "do_istio $@ "

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: default-secret
  annotations:
    kubernetes.io/service-account.name: default
type: kubernetes.io/service-account-token
EOF


    squawk 10 "KUBECONFIG=$KUBECONFIG \
    istioctl install \
      --set profile=$ISTIO_PROFILE
    "
    KUBECONFIG=$KUBECONFIG \
    istioctl install \
      --set profile=$ISTIO_PROFILE
      # deprecated
      #--set "values.kiali.dashboard.jaegerURL=http://jaeger-query:16686" \
      #--set "values.global.tracer.zipkin.address=jaeger-collector:9411" \
      #--set "values.kiali.dashboard.grafanaURL=http://grafana:3000"
      #--set values.kiali.enabled=true \
      #--set values.tracing.enabled=true \

    squawk 10 "KUBECONFIG=$KUBECONFIG kubectl label namespace default --overwrite istio-injection=enabled"
    KUBECONFIG=$KUBECONFIG \
    kubectl label namespace default --overwrite istio-injection=enabled

    squawk 3 'https://istio.io/latest/docs/setup/getting-started/'

    squawk 10 "KUBECONFIG=$KUBECONFIG kubectl apply -n istio-system -f $KUBASH_DIR/submodules/istio/samples/addons/"
    KUBECONFIG=$KUBECONFIG \
    kubectl apply -n istio-system -f $KUBASH_DIR/submodules/istio/samples/addons/
}
