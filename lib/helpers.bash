#!/bin/bash
#ELASTIC_VERS='7.0.0-alpha1'
#ELASTIC_VERS='7.2.0'
#ELASTIC_VERS='7.4.0'
#ELASTIC_VERS='7.5.2'
#ELASTIC_VERS='7.8.0'
#ELASTIC_VERS='7.9.3'
#ELASTIC_VERS='7.10.0'
ELASTIC_VERS='7.12.1'
ELASTIC_OPERATOR_VERS='1.3.0'
THIS_NAMESPACE=$(cat .name-space)
THIS_CLUSTER=$(cat .cluster-name)

setup_secrets () {
  cd $thisDIR
  kubectl create secret generic acme-account --from-literal=ACME_EMAIL=coopadmin@webhosting.coop
  kubectl create -f monitaur-secret-htpasswd
  kubectl create secret generic monitaur-auth --from-file monitaur-auth
}

install_ldap () {
  cd $thisDIR/osixia-openldap
  kubectl apply -f ldap-secret.yaml
  kubectl apply -f ldap-statefulset.yaml
  ~/.kubash/w8s/generic.w8 ldap-0 $THIS_NAMESPACE
  kubectl apply -f ldap-service.yaml
  cd $thisDIR
}

install_grafana () {
  helm install \
    --name grafana \
    stable/grafana    \
    --namespace $THIS_NAMESPACE \
    --set admin.userdKey="monitaur" \
    --set admin.passwordKey="bass88" \
    --set persistence.storageClassName="openebs-cstor-monitaur-grafana" \
    --set persistence.size=5Gi
}

install_fluentd () {
  ## Install Fluentd
  cd $thisDIR
  helm install \
    --name monitaur-fluentd \
    kiwigrid/fluentd-elasticsearch \
    --namespace $THIS_NAMESPACE \
    -f fluentd-values.yaml

  ~/.kubash/w8s/generic.w8 monitaur-fluentd-fluentd-elasticsearch $THIS_NAMESPACE
  kubectl apply -f fluentd-svc.yaml
  kubectl apply -f fluentd-proxy.yaml
}

install_efk_secrets () {
  cd $thisDIR
  kubectl create secret generic aws-s3-keys --from-file=access-key-id=./.aws_access_key --from-file=access-secret-key=./.aws_secret_key
  kubectl create secret generic gcs-cred --from-file=gcs-json-cred=./gcs-json-cred.json
}

install_efk_opendistro () {
  install_efk_secrets
  cd ~/.kubash/submodules/opendistro-build/helm/opendistro-es
  echo helm install ${THIS_CLUSTER}-opendistro --values=$thisDIR/opendistro-values.yaml . 
  helm install ${THIS_CLUSTER}-opendistro --values=$thisDIR/opendistro-values.yaml . 
  cd $thisDIR
}

install_efk_opensearch () {
  install_efk_secrets
  cd ~/.kubash/submodules/opensearch-devops/Helm/opensearch
  echo helm install ${THIS_CLUSTER}-opensearch --values=$thisDIR/opensearch-values.yaml . 
  helm install ${THIS_CLUSTER}-opensearch --values=$thisDIR/opensearch-values.yaml . 
  cd $thisDIR
}

install_efk_opensearch_dashboards () {
  cd ~/.kubash/submodules/opensearch-devops/Helm/opensearch-dashboards
  echo helm install ${THIS_CLUSTER}-opensearch-dashboards --values=$thisDIR/opensearch-dashboard-values.yaml . 
  helm install ${THIS_CLUSTER}-opensearch-dashboards --values=$thisDIR/opensearch-dashboard-values.yaml . 
  cd $thisDIR
}

install_efk_all_in_one () {
# This is the new way which is not working yet, reverting
# https://medium.com/@raphaeldelio/deploy-the-elastic-stack-in-kubernetes-with-the-elastic-cloud-on-kubernetes-eck-b51f667828f9
# https://medium.com/@raphaeldelio/how-to-backup-elasticsearch-on-kubernetes-with-amazon-s3-and-kibana-b282771e4da2
# https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-deploy-eck.html
   install_efk_secrets
   kubectl apply -f https://download.elastic.co/downloads/eck/$ELASTIC_OPERATOR_VERS/all-in-one.yaml
   ~/.kubash/w8s/generic.w8 elastic-operator elastic-system
   sleep 2
   kubectl apply -f elasticsearch.yaml
   sleep 300
   ~/.kubash/w8s/generic.w8 elasticsearch-es-default-0 default
   ~/.kubash/w8s/generic.w8 elasticsearch-es-default-1 default
   ~/.kubash/w8s/generic.w8 elasticsearch-es-default-2 default
   local SEED1=$(uuidgen -r)
   local myresult=$(echo $SEED1 | sha512sum | base64 | head -c 32)
   echo $myresult>>.kibana-encrypted-key
   kubectl create secret generic kibana-saved-objects-encrypted-key --from-literal=xpack.encryptedSavedObjects.encryptionKey="$myresult"
   kubectl apply -f kibana.yaml
   ~/.kubash/w8s/generic.w8 kibana-kb default
}

template_efk () {
  # chart.monitaur.net
  helm repo add elastic https://helm.elastic.co
  helm repo add kiwigrid https://kiwigrid.github.io
  helm repo update
  cd $thisDIR
  # namespace: oltorf
  ## Bring up ES
  helm fetch \
    --version "$ELASTIC_VERS" \
    elastic/elasticsearch
  tar xf elasticsearch-${ELASTIC_VERS}.tgz


  helm template \
    --name elasticsearch \
    --namespace $THIS_NAMESPACE \
    --set resources.requests.memory='2Gi' \
    --set resources.limits.memory='3Gi' \
    --set esJavaOpts='-Xmx2g -Xms2g' \
    --set image='webhostingcoopteam/elasticsearchmod' \
    --set imageTag="$ELASTIC_VERS" \
    --set replicas=3 \
    --set volumeClaimTemplate.storageClassName='openebs-cstor-monitaur-elasticsearch' \
    --set volumeClaimTemplate.resources.requests.storage='10Gi' \
    elasticsearch > elasticsearc.template

  #  --version "$ELASTIC_VERS" \

  ## Install Kibana
  helm fetch \
    --version $ELASTIC_VERS \
    elastic/kibana
  tar xf kibana-${ELASTIC_VERS}.tgz
  helm template \
    --namespace $THIS_NAMESPACE \
    --name kibana \
    kibana > kibana.template

  ## Install Fluentd
  helm fetch \
    kiwigrid/fluentd-elasticsearch
  tar xf fluentd-elasticsearch-*.tgz
  helm template \
    --namespace $THIS_NAMESPACE \
    --name fluentd-elasticsearch \
    fluentd-elasticsearch > fluentd-elasticsearch.template

}

install_efk () {
  # chart.monitaur.net
  helm repo add elastic https://helm.elastic.co
  helm repo add kiwigrid https://kiwigrid.github.io
  helm repo update
  cd $thisDIR
  # namespace: oltorf
  ## Bring up ES
  helm install \
    --name elasticsearch \
    elastic/elasticsearch \
    --namespace $THIS_NAMESPACE \
    --version "$ELASTIC_VERS" \
    --set resources.requests.memory='2Gi' \
    --set resources.limits.memory='3Gi' \
    --set esJavaOpts='-Xmx2g -Xms2g' \
    --set image='webhostingcoopteam/elasticsearchmod' \
    --set imageTag="$ELASTIC_VERS" \
    --set replicas=3 \
    --set volumeClaimTemplate.storageClassName='openebs-cstor-monitaur-elasticsearch' \
    --set volumeClaimTemplate.resources.requests.storage='10Gi'

  ~/.kubash/w8s/generic.w8 elasticsearch-master-0 $THIS_NAMESPACE
  ~/.kubash/w8s/generic.w8 elasticsearch-master-1 $THIS_NAMESPACE
  ~/.kubash/w8s/generic.w8 elasticsearch-master-2 $THIS_NAMESPACE

  sleep 2

  ## Install Kibana
  helm install \
    --namespace $THIS_NAMESPACE \
    --name kibana elastic/kibana \
    --version $ELASTIC_VERS

  ~/.kubash/w8s/generic.w8 kibana-kibana $THIS_NAMESPACE
  kubectl apply -f kibana-proxy.yaml
  ## fluentd
  kubectl apply -f fluentd-elasticsearch-custom
}

do_sc () {
  #kubectl apply -f openebs-monitaur-pool.yaml
  #kubectl apply -f openebs-sc-elastic.yaml

  kubectl apply -f rook-pool.yaml
  kubectl apply -f rook-block-sc.yaml

#  kubectl apply -f sc-mongodb.yaml
 # kubectl apply -f sc-hadoop.yaml
 # kubectl apply -f sc-hadoop-data.yaml
 # kubectl apply -f sc-postgres.yaml
  #kubectl apply -f sc-grafana.yaml
  #kubectl apply -f pvc-elasticsearch.yaml
  sleep 30
}

do_sc_openebs () {
  kubash -n $THIS_CLUSTER openebs
  ~/.kubash/w8s/generic.w8 maya openebs
#  kubectl apply -f openebs-monitaur-pool.yaml
#  kubectl apply -f openebs-sc-elastic.yaml
  kubectl apply -f openebs-localPV.yaml
#  kubectl apply -f openebs-lvm-sc.yaml
  sleep 30
}

do_sc_rook () {
  kubash -n $THIS_CLUSTER rook
  #kubectl apply -f openebs-localPV.yaml
  #kubectl apply -f openebs-lvm-sc.yaml
  #kubectl apply -f rook-sc.yaml
  #kubectl apply -f openebs-monitaur-pool.yaml
  kubectl apply -f rook-block-sc.yaml
  sleep 30
}

do_proxy () {
  cd $thisDIR
  kubectl apply -f elasticsearch-proxy.yaml
  kubectl apply -f fluentd-svc.yaml
  kubectl apply -f fluentd-proxy.yaml
  kubectl apply -f grafana-istio-proxy.yaml
  kubectl apply -f kiali-proxy.yaml
  kubectl apply -f kibana-proxy.yaml
  kubectl apply -f tracing-proxy.yaml
  kubectl apply -f zm-proxy.yaml
  #kubectl apply -f zeppelin-proxy.yaml
  kubectl apply -f nextcloud-proxy.yaml
  kubectl apply -f prometheus-proxy.yaml
}

install_mongodb () {
  helm install \
    --name mongodb \
    stable/mongodb \
    --namespace $THIS_NAMESPACE \
    --set persistence.storageClass="openebs-cstor-monitaur-mongodb" \
    --set volumeClaimTemplate.resources.requests.storage=5Gi
}

install_postgres () {
  cd $thisDIR
  kubectl apply -f postgres.yaml
  ~/.kubash/w8s/generic.w8 postgres $THIS_NAMESPACE
}

install_cassandra () {
  cd $thisDIR
  kubectl apply -f sc-cassandra.yaml
  kubash -n $THIS_CLUSTER rook
  kubectl apply -f rook-cassandra.yaml
}

make_ingress () {
  cd $thisDIR

  kubectl apply -f cerberus.monitaur.net-svc.yaml
  kubectl apply -f zm.oltorf.net-svc.yaml

  echo 'next ./chartmonitaur.sh'
}

install_zeppelin () {
  helm install --name hadoop \
    --name monitaur-hadoop \
    --namespace $THIS_NAMESPACE \
    --set yarn.numNodes=1 \
    --set yarn.nodeManager.resources.requests.memory=4096Mi \
    --set yarn.nodeManager.resources.requests.cpu=2000m \
    --set yarn.nodeManager.resources.limits.memory=8096Mi \
    --set yarn.nodeManager.resources.limits.cpu=4000m \
    --set persistence.nameNode.enabled=true \
    --set persistence.nameNode.storageClass='openebs-cstor-monitaur-hadoop' \
    --set persistence.dataNode.enabled=true \
    --set persistence.dataNode.storageClass='openebs-cstor-monitaur-hadoop-data' \
    stable/hadoop
  cd $thisDIR
  helm install \
    --name monitaur-zeppelin \
    --namespace $THIS_NAMESPACE \
    --set hadoop.useConfigMap=true,hadoop.configMapName=monitaur-hadoop-hadoop \
    stable/zeppelin
    #./zeppelin
}

