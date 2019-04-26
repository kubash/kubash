#!/usr/bin/env bash
# set default fall-through variables
# if set in the environment these variables will fall-through and retain their value
# otherwise use the defaults here
: ${KUBE_VERSION:='v1.14.0'}
: ${KUBE_MAJOR_VER:=1}
: ${KUBE_MINOR_VER:=14}
: ${KUBASH_CLUSTER_NAME=default}
: ${KUBASH_HISTORY:=$KUBASH_DIR/.kubash_history}
: ${KUBASH_HISTORY_LIMIT:=5000}
: ${KUBASH_BIN:=$KUBASH_DIR/bin}
: ${KUBASH_LIB:=$KUBASH_DIR/lib}
: ${KUBASH_CLUSTERS_DIR:=$KUBASH_DIR/clusters}
: ${KUBASH_CLUSTER_DIR:=$KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME}
: ${KUBASH_CSV_VER_FILE:=$KUBASH_CLUSTER_DIR/csv_version}
: ${KUBASH_CLUSTER_CONFIG:=$KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/config}
: ${KUBASH_HOSTS_CSV:=$KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/hosts.csv}
: ${KUBASH_ANSIBLE_HOSTS:=$KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/hosts}
: ${KUBASH_KUBESPRAY_HOSTS:=$KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/inventory/hosts.ini}
: ${KUBASH_PROVISION_CSV:=$KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/provision.csv}
: ${KUBASH_USERS_CSV:=$KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/users.csv}
: ${KUBASH_INGRESS_NAME:='kubashingress'}
: ${KUBASH_OPENEBS_NAME:='kubashopenebs'}
: ${KUBASH_OIDC_AUTH:='false'}
#: ${KUBEADMIN_IGNORE_PREFLIGHT_CHECKS:='--ignore-preflight-errors cri'}
: ${KUBEADMIN_IGNORE_PREFLIGHT_CHECKS:='--ignore-preflight-errors=FileAvailable--etc-kubernetes-manifests-etcd.yaml,ExternalEtcdVersion,cri'}
: ${VERBOSITY:=0}
: ${KVM_builderBasePath:=/var/lib/libvirt/images}
: ${KVM_builderHost:=localhost}
: ${KVM_builderPort:=22}
: ${KVM_builderUser:=coopadmin}
: ${KVM_builderTMP:=$KVM_builderBasePath/kubashtmp}
: ${KVM_builderDir:=$KVM_builderBasePath/kubashbuilds}
: ${KVM_BASE_IMG:=kubash.qcow2}
: ${KVM_RAM:=4096}
: ${KVM_CPU:=2}
: ${KVM_NET:='default'}
: ${PSEUDO:=sudo}
: ${K8S_user:=root}
: ${K8S_SU_USER:=coopadmin}
: ${K8S_NET:=calico}
: ${K8S_provisionerPort:=22}
: ${K8S_SU_PATH:='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin'}
: ${my_DOMAIN:=example.com}
: ${GOPATH:=~/.go}
: ${KUTIME:="/usr/bin/time -v"}
: ${PARALLEL_JOBS:=5}
: ${PARALLEL:="parallel"}
: ${OPENSHIFT_REGION:=lab}
: ${OPENSHIFT_ZONE:=baremetal}
: ${MASTERS_AS_ETCD:='true'}
: ${BROADCAST_TO_NETWORK:='10.0.23.0/24'}
: ${INTERFACE_NET:='eth0'}
: ${DO_KEEPALIVED:='false'}
: ${DO_CRICTL:='true'}
: ${ETCD_VERSION:=v3.2.7}
: ${ETCD_TLS:='true'}
: ${KUBASH_RSYNC_OPTS:='-L -H -aze'}
: ${CALICO_VER:=v3.3}
: ${CALICO_URL:=https://docs.projectcalico.org/$CALICO_VER/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml}
: ${CALICO_RBAC_URL:=https://docs.projectcalico.org/$CALICO_VER/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml}
: ${FLANNEL_URL:=https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml}
: ${USE_TRAEFIK_DAEMON_SET:='true'}
: ${USE_TRAEFIK_RBAC:='true'}
: ${VOYAGER_PROVIDER:='metallb'}
: ${VOYAGER_BY_HELM:= "false"}
: ${VOYAGER_VERSION:='9.0.0'}
: ${VOYAGER_ADMISSIONWEBHOOK:='--set apiserver.enableAdmissionWebhook=true'}
: ${LINKERD_URL:='https://raw.githubusercontent.com/linkerd/linkerd-examples/master/k8s-daemonset/k8s/linkerd-ingress-controller.yml'}
: ${TAB_1:='  '}
: ${TAB_2:='    '}
: ${TAB_3:='      '}
: ${TAB_4:='        '}

net_set () {
  # Set networking defaults
  if [[ -e "$KUBASH_CLUSTER_DIR/net_set" ]]; then
    K8S_NET=$(cat $KUBASH_CLUSTER_DIR/net_set)
  fi
  if [[ "$K8S_NET" == "calico" ]]; then
    my_KUBE_CIDR="192.168.0.0/16"
  elif [[ "$K8S_NET" == "flannel" ]]; then
    my_KUBE_CIDR="10.244.0.0/16"
  else
    horizontal_rule
    croak 3 'unknown pod network'
  fi
}

net_set

export KUBECONFIG=$KUBASH_CLUSTER_CONFIG
# Rasion d etre
RAISON=false

# global vars
ANSWER_YES=no
print_help=no


# includes
. $KUBASH_LIB/parse_opts.bash
. $KUBASH_LIB/utils.bash
. $KUBASH_LIB/squawk.bash
. $KUBASH_LIB/croak.bash
. $KUBASH_LIB/usage.bash
. $KUBASH_LIB/kcsv.bash
. $KUBASH_LIB/storage.bash
. $KUBASH_LIB/ping.bash
. $KUBASH_LIB/w8.bash
. $KUBASH_LIB/kvm.bash
. $KUBASH_LIB/ingress.bash
. $KUBASH_LIB/net.bash
. $KUBASH_LIB/packer.bash
. $KUBASH_LIB/kinit.bash
. $KUBASH_LIB/yaml.bash
. $KUBASH_LIB/vbox.bash
. $KUBASH_LIB/gke.bash
. $KUBASH_LIB/qemu.bash
. $KUBASH_LIB/kattic.bash
. $KUBASH_LIB/provision.bash
. $KUBASH_LIB/interactive.bash
. $KUBASH_LIB/kubeadm2ha.bash
. $KUBASH_LIB/openshift.bash
. $KUBASH_LIB/kubespray.bash
. $KUBASH_LIB/ansible.bash
