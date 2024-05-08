#!/usr/bin/env bash
check_default () {
  if [[ -f $1 ]]; then
    printf "Adding default file %s\n" $1
    . $1
  fi
}

find_defaults () {
  check_default /etc/kubash/kubash_defaults
  check_default ~/.kubash/.kubash_defaults
  check_default ~/.kubash_defaults
}

find_defaults
# set default fall-through variables
# if set in the environment these variables will fall-through and retain their value
# otherwise use the defaults here
# i.e. to change the istio profile
# you would export that variable before
# executing kubash
# e.g.
# export ISTIO_PROFILE=preview && kubash ...
# it is best to export it as kubash is re-entrant
#: ${KUBERNETES_VERSION:='v1.15.3'}
#: ${KUBE_MAJOR_VER:=1}
#: ${KUBE_MINOR_VER:=15}
: ${NAMESPACE:=default}
: ${KUBASH_CLUSTER_NAME:=default}
: ${KUBASH_HISTORY:=$KUBASH_DIR/.kubash_history}
: ${KUBASH_HISTORY_LIMIT:=5000}
: ${KUBASH_BIN:=$KUBASH_DIR/bin}
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
: ${REGISTRY_MIRROR:=https://registry-1.docker.io}
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
: ${K8S_SU_PATH:='/opt/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin'}
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
: ${K8S_lvm_vg:="lvmpv-vg"}
: ${KUBASH_RSYNC_OPTS:='-L -H -aze'}
: ${CALICO_VER:=v3.3}
: ${CALICO_URL:=https://docs.projectcalico.org/$CALICO_VER/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml}
: ${CALICO_RBAC_URL:=https://docs.projectcalico.org/$CALICO_VER/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml}
: ${FLANNEL_URL:=https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml}
: ${USE_TRAEFIK_DAEMON_SET:='true'}
: ${USE_TRAEFIK_RBAC:='true'}
: ${VOYAGER_PROVIDER:='metallb'}
: ${VOYAGER_VERSION:='v12.0.0'}
: ${METALLB_VERSION:='v0.13.6'}
: ${OPENSEARCH_INSTALL_METHOD:='helm'}
: ${OPENSEARCH_DEPLOYMENT_NAME:='opensearch'}
: ${PERCONA_NAMESPACE:='pxc'}
: ${PERCONA_STORAGE_REQ:='20Gi'}
: ${PERCONA_BACKUP_ENABLED:='false'}
: ${VOYAGER_ADMISSIONWEBHOOK:='--set apiserver.enableValidatingWebhook=true'}
: ${LINKERD_URL:='https://raw.githubusercontent.com/linkerd/linkerd-examples/master/k8s-daemonset/k8s/linkerd-ingress-controller.yml'}
: ${ISTIO_GATEWAY_TYPE=LoadBalancer}
: ${ISTIO_PROFILE=default}
: ${TAB_1:='  '}
: ${TAB_2:='    '}
: ${TAB_3:='      '}
: ${TAB_4:='        '}
# https://www.jamescoyle.net/how-to/2060-qcow2-physical-size-with-different-preallocation-settings
# can be any of off,metadata,falloc,full
: ${QEMU_PREALLOCATION:='off'}
: ${CERT_MANAGER_VERSION:='1.0.4'}
: ${CONSUL_VERSION:='0.39.0'}
: ${CONSUL_METHOD:='helm'}
: ${CONSUL_VERSION:='0.39.0'}
: ${KUBEGRES_VERSION:='v1.16'}
: ${POSTGRES_IMAGE_TAG:='postgres:15-alpine'}
: ${POSTGRES_REPLICA_COUNT:=3}
: ${POSTGRES_DB_SIZE:='200Mi'}

# CSV vars
JQ_INTERPRETER_1_0_0='.hosts[] | "\(.hostname),\(.role),\(.cpuCount),\(.Memory),\(.sshPort),\(.network1.network),\(.network1.mac),\(.network1.ip),\(.provisioner.Host),\(.provisioner.User),\(.provisioner.Port),\(.provisioner.BasePath),\(.os),\(.virt),\(.network2.network),\(.network2.mac),\(.network2.ip),\(.network3.network),\(.network3.mac),\(.network3.ip)"' \
JQ_INTERPRETER_2_0_0='.hosts[] | "\(.hostname),\(.role),\(.cpuCount),\(.Memory),\(.sshPort),\(.network1.network),\(.network1.mac),\(.network1.ip),\(.network1.routingprefix),\(.network1.subnetmask),\(.network1.broadcast),\(.network1.gateway),\(.provisioner.Host),\(.provisioner.User),\(.provisioner.Port),\(.provisioner.BasePath),\(.os),\(.virt),\(.network2.network),\(.network2.mac),\(.network2.ip),\(.network2.routingprefix),\(.network2.subnetmask),\(.network2.broadcast),\(.network2.gateway),\(.network3.network),\(.network3.mac),\(.network3.ip),\(.network3.routingprefix),\(.network3.subnetmask),\(.network3.broadcast),\(.network3.gateway)"' \
JQ_INTERPRETER_3_0_0='.hosts[] | "\(.hostname),\(.role),\(.cpuCount),\(.Memory),\(.sshPort),\(.network1.network),\(.network1.mac),\(.network1.ip),\(.network1.routingprefix),\(.network1.subnetmask),\(.network1.broadcast),\(.network1.gateway),\(.provisioner.Host),\(.provisioner.User),\(.provisioner.Port),\(.provisioner.BasePath),\(.os),\(.virt),\(.network2.network),\(.network2.mac),\(.network2.ip),\(.network2.routingprefix),\(.network2.subnetmask),\(.network2.broadcast),\(.network2.gateway),\(.network3.network),\(.network3.mac),\(.network3.ip),\(.network3.routingprefix),\(.network3.subnetmask),\(.network3.broadcast),\(.network3.gateway),\(.iscsi.target),\(.iscsi.chap_username),\(.iscsi.chap_password),\(.iscsi.host)"'
JQ_INTERPRETER_4_0_0='.hosts[] | "\(.hostname),\(.role),\(.cpuCount),\(.Memory),\(.sshPort),\(.network1.network),\(.network1.mac),\(.network1.ip),\(.network1.routingprefix),\(.network1.subnetmask),\(.network1.broadcast),\(.network1.gateway),\(.provisioner.Host),\(.provisioner.User),\(.provisioner.Port),\(.provisioner.BasePath),\(.os),\(.virt),\(.network2.network),\(.network2.mac),\(.network2.ip),\(.network2.routingprefix),\(.network2.subnetmask),\(.network2.broadcast),\(.network2.gateway),\(.network3.network),\(.network3.mac),\(.network3.ip),\(.network3.routingprefix),\(.network3.subnetmask),\(.network3.broadcast),\(.network3.gateway),\(.iscsi.target),\(.iscsi.chap_username),\(.iscsi.chap_password),\(.iscsi.host),\(.storage.path),\(.storage.type),\(.storage.size)"'
JQ_INTERPRETER_5_0_0='.hosts[] | "\(.hostname),\(.role),\(.cpuCount),\(.Memory),\(.sshPort),\(.network1.network),\(.network1.mac),\(.network1.ip),\(.network1.routingprefix),\(.network1.subnetmask),\(.network1.broadcast),\(.network1.gateway),\(.provisioner.Host),\(.provisioner.User),\(.provisioner.Port),\(.provisioner.BasePath),\(.os),\(.kvm_os_variant),\(.virt),\(.network2.network),\(.network2.mac),\(.network2.ip),\(.network2.routingprefix),\(.network2.subnetmask),\(.network2.broadcast),\(.network2.gateway),\(.network3.network),\(.network3.mac),\(.network3.ip),\(.network3.routingprefix),\(.network3.subnetmask),\(.network3.broadcast),\(.network3.gateway),\(.iscsi.target),\(.iscsi.chap_username),\(.iscsi.chap_password),\(.iscsi.host),\(.storage.path),\(.storage.type),\(.storage.size),\(.storage.target),\(.storage.targetpath),\(.storage.uuid)"'
JQ_INTERPRETER_6_0_0='.hosts[] | "\(.hostname),\(.role),\(.cpuCount),\(.Memory),\(.sshPort),\(.network1.network),\(.network1.mac),\(.network1.ip),\(.network1.routingprefix),\(.network1.subnetmask),\(.network1.broadcast),\(.network1.gateway),\(.provisioner.Host),\(.provisioner.User),\(.provisioner.Port),\(.provisioner.BasePath),\(.os),\(.kvm_os_variant),\(.virt),\(.network2.network),\(.network2.mac),\(.network2.ip),\(.network2.routingprefix),\(.network2.subnetmask),\(.network2.broadcast),\(.network2.gateway),\(.network3.network),\(.network3.mac),\(.network3.ip),\(.network3.routingprefix),\(.network3.subnetmask),\(.network3.broadcast),\(.network3.gateway),\(.iscsi.target),\(.iscsi.chap_username),\(.iscsi.chap_password),\(.iscsi.host),\(.storage.path),\(.storage.type),\(.storage.size),\(.storage.target),\(.storage.targetpath),\(.storage.uuid),\(.storage1.path),\(.storage1.type),\(.storage1.size),\(.storage1.target),\(.storage1.targetpath),\(.storage1.uuid),\(.storage2.path),\(.storage2.type),\(.storage2.size),\(.storage2.target),\(.storage2.targetpath),\(.storage2.uuid),\(.storage3.path),\(.storage3.type),\(.storage3.size),\(.storage3.target),\(.storage3.targetpath),\(.storage3.uuid)"'

CSV_COLUMNS_1_0_0="K8S_node K8S_role K8S_cpuCount K8S_Memory K8S_sshPort K8S_network1 K8S_mac1 K8S_ip1 K8S_provisionerHost K8S_provisionerUser K8S_provisionerPort K8S_provisionerBasePath K8S_os K8S_virt K8S_network2 K8S_mac2 K8S_ip2 K8S_network3 K8S_mac3 K8S_ip3"
CSV_COLUMNS_2_0_0="K8S_node K8S_role K8S_cpuCount K8S_Memory K8S_sshPort K8S_network1 K8S_mac1 K8S_ip1 K8S_routingprefix1 K8S_subnetmask1 K8S_broadcast1 K8S_gateway1 K8S_provisionerHost K8S_provisionerUser K8S_provisionerPort K8S_provisionerBasePath K8S_os K8S_virt K8S_network2 K8S_mac2 K8S_ip2 K8S_routingprefix2 K8S_subnetmask2 K8S_broadcast2 K8S_gateway2 K8S_network3 K8S_mac3 K8S_ip3 K8S_routingprefix3 K8S_subnetmask3 K8S_broadcast3 K8S_gateway3"
CSV_COLUMNS_3_0_0="K8S_node K8S_role K8S_cpuCount K8S_Memory K8S_sshPort K8S_network1 K8S_mac1 K8S_ip1 K8S_routingprefix1 K8S_subnetmask1 K8S_broadcast1 K8S_gateway1 K8S_provisionerHost K8S_provisionerUser K8S_provisionerPort K8S_provisionerBasePath K8S_os K8S_virt K8S_network2 K8S_mac2 K8S_ip2 K8S_routingprefix2 K8S_subnetmask2 K8S_broadcast2 K8S_gateway2 K8S_network3 K8S_mac3 K8S_ip3 K8S_routingprefix3 K8S_subnetmask3 K8S_broadcast3 K8S_gateway3 K8S_iscsitarget K8S_iscsichapusername K8S_iscsichappassword K8S_iscsihost"
CSV_COLUMNS_4_0_0="K8S_node K8S_role K8S_cpuCount K8S_Memory K8S_sshPort K8S_network1 K8S_mac1 K8S_ip1 K8S_routingprefix1 K8S_subnetmask1 K8S_broadcast1 K8S_gateway1 K8S_provisionerHost K8S_provisionerUser K8S_provisionerPort K8S_provisionerBasePath K8S_os K8S_virt K8S_network2 K8S_mac2 K8S_ip2 K8S_routingprefix2 K8S_subnetmask2 K8S_broadcast2 K8S_gateway2 K8S_network3 K8S_mac3 K8S_ip3 K8S_routingprefix3 K8S_subnetmask3 K8S_broadcast3 K8S_gateway3 K8S_iscsitarget K8S_iscsichapusername K8S_iscsichappassword K8S_iscsihost K8S_storagePath K8S_storageType K8S_storageSize"
CSV_COLUMNS_5_0_0="K8S_node K8S_role K8S_cpuCount K8S_Memory K8S_sshPort K8S_network1 K8S_mac1 K8S_ip1 K8S_routingprefix1 K8S_subnetmask1 K8S_broadcast1 K8S_gateway1 K8S_provisionerHost K8S_provisionerUser K8S_provisionerPort K8S_provisionerBasePath K8S_os K8S_kvm_os_variant K8S_virt K8S_network2 K8S_mac2 K8S_ip2 K8S_routingprefix2 K8S_subnetmask2 K8S_broadcast2 K8S_gateway2 K8S_network3 K8S_mac3 K8S_ip3 K8S_routingprefix3 K8S_subnetmask3 K8S_broadcast3 K8S_gateway3 K8S_iscsitarget K8S_iscsichapusername K8S_iscsichappassword K8S_iscsihost K8S_storagePath K8S_storageType K8S_storageSize K8S_storageTarget K8S_storageMountPath K8S_storageUUID"
CSV_COLUMNS_6_0_0="K8S_node K8S_role K8S_cpuCount K8S_Memory K8S_sshPort K8S_network1 K8S_mac1 K8S_ip1 K8S_routingprefix1 K8S_subnetmask1 K8S_broadcast1 K8S_gateway1 K8S_provisionerHost K8S_provisionerUser K8S_provisionerPort K8S_provisionerBasePath K8S_os K8S_kvm_os_variant K8S_virt K8S_network2 K8S_mac2 K8S_ip2 K8S_routingprefix2 K8S_subnetmask2 K8S_broadcast2 K8S_gateway2 K8S_network3 K8S_mac3 K8S_ip3 K8S_routingprefix3 K8S_subnetmask3 K8S_broadcast3 K8S_gateway3 K8S_iscsitarget K8S_iscsichapusername K8S_iscsichappassword K8S_iscsihost K8S_storagePath K8S_storageType K8S_storageSize K8S_storageTarget K8S_storageMountPath K8S_storageUUID K8S_storagePath1 K8S_storageType1 K8S_storageSize1 K8S_storageTarget1 K8S_storageMountPath1 K8S_storageUUID1 K8S_storagePath2 K8S_storageType2 K8S_storageSize2 K8S_storageTarget2 K8S_storageMountPath2 K8S_storageUUID2 K8S_storagePath3 K8S_storageType3 K8S_storageSize3 K8S_storageTarget3 K8S_storageMountPath3 K8S_storageUUID3"

# uniq hosts was the same 1.0.0 - 4.0.0
uniq_hosts_list_columns_1_0_0="K8S_provisionerHost K8S_provisionerUser K8S_provisionerPort K8S_provisionerBasePath K8S_os K8S_virt"
uniq_hosts_list_columns_5_0_0="K8S_provisionerHost K8S_provisionerUser K8S_provisionerPort K8S_provisionerBasePath K8S_os K8S_kvm_os_variant K8S_virt"
uniq_hosts_list_columns_6_0_0="K8S_provisionerHost K8S_provisionerUser K8S_provisionerPort K8S_provisionerBasePath K8S_os K8S_kvm_os_variant K8S_virt"
