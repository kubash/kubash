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
    KUBASH_ISTIO_PROFILE = $KUBASH_CLUSTER_DIR/istio_profile.yml
    if [[ ! -f $KUBASH_ISTIO_PROFILE ]]; then
     istioctl profile dump demo > $KUBASH_ISTIO_PROFILE
    fi
    KUBECONFIG=$KUBECONFIG \
    istioctl manifest apply -f $KUBASH_ISTIO_PROFILE
    KUBECONFIG=$KUBECONFIG \
    kubectl label namespace default --overwrite istio-injection=enabled
}
