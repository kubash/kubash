default:
	@echo 'Welcome to the kubash Makefile'

# Reactionetes Makefile
# define various versions
$(eval CT_VERSION := "v0.9.0")
$(eval CNI_VERSION := "v0.8.5")
$(eval NVM_VERSION := "v0.35.3")
$(eval PACKER_VERSION := "1.7.0")
$(eval CRICTL_VERSION := "v1.18.0")

# Install location
$(eval KUBASH_DIR := $(HOME)/.kubash)
$(eval KUBASH_BIN := $(KUBASH_DIR)/bin)
$(eval GOPATH := $(HOME)/.go)

# Namespaces
$(eval KUBASH_NAMESPACE := kubash)
$(eval MONITORING_NAMESPACE := monitoring)

# Minikube settings
$(eval MINIKUBE_CPU := 2)
$(eval MINIKUBE_MEMORY := 3333)
$(eval MINIKUBE_DRIVER := virtualbox)
$(eval MY_KUBE_VERSION := v1.9.4)
$(eval CHANGE_MINIKUBE_NONE_USER := true)
$(eval KUBECONFIG := $(HOME)/.kube/config)
$(eval MINIKUBE_WANTREPORTERRORPROMPT := false)
$(eval MINIKUBE_WANTUPDATENOTIFICATION := false)
$(eval MINIKUBE_CLUSTER_DOMAIN := cluster.local)

# Gymongonasium settings
$(eval GYMONGO_DB_NAME := gymongonasium)
$(eval GYMONGO_TIME := 33)
$(eval GYMONGO_SLEEP := 5)
$(eval GYMONGO_TABLES := 1)
$(eval GYMONGO_THREADS := 10)
$(eval GYMONGO_SUM_RANGES := 1)
$(eval GYMONGO_RANGE_SIZE := 100)
$(eval GYMONGO_TABLE_SIZE := 10000)

# Prometheus settings
$(eval PROMETHEUS_ALERTMANAGER_ENABLED := true)
$(eval PROMETHEUS_ALERTMANAGER_NAME := pyralertmanager)
$(eval PROMETHEUS_ALERTMANAGER_REPLICAS := 3)
$(eval PROMETHEUS_ALERTMANAGER_PERSISTENTVOLUME_ENABLED := true)
$(eval PROMETHEUS_ALERTMANAGER_PERSISTENTVOLUME_EXISTINGCLAIM := "")
$(eval PROMETHEUS_ALERTMANAGER_PERSISTENTVOLUME_MOUNTPATH := /data)
$(eval PROMETHEUS_ALERTMANAGER_PERSISTENTVOLUME_SIZE := 2Gi)
#$(eval PROMETHEUS_ALERTMANAGER_PERSISTENTVOLUME_STORAGECLASS := "")
$(eval PROMETHEUS_ALERTMANAGER_PERSISTENTVOLUME_SUBPATH := "")

# Helm settings
$(eval HELM_INSTALL_DIR := "$(KUBASH_BIN)")

# Istio
$(eval ISTIO_VERSION := "1.10.0")

# K9S
$(eval K9S_VERSION := "v0.23.10")

$(eval KUBECFG_VERSION := "v0.16.0")
$(eval TERRAFORM_VERSION := "0.15.3")
$(eval KUBEBUILDER_VERS := 2.3.1)
$(eval KIND_VERS := v0.9.0)
$(eval RKE_VERS := v1.0.16)


all: $(KUBASH_BIN)/kush $(KUBASH_BIN)/kzsh $(KUBASH_BIN)/kudash reqs anaconda nvm

reqs: linuxreqs

linuxreqs: kubectl helm minikube jinja2-cli submodules/openebs yaml2json ct

helm: $(KUBASH_BIN)
	@scripts/kubashnstaller helm

$(KUBASH_BIN)/kush:
	echo '#!/usr/bin/env sh' > $(KUBASH_BIN)/kush
	tail -n +2 "$(KUBASH_BIN)/kubash" >> $(KUBASH_BIN)/kush

$(KUBASH_BIN)/kzsh:
	echo '#!/usr/bin/env zsh' > $(KUBASH_BIN)/kzsh
	tail -n +2 "$(KUBASH_BIN)/kubash" >> $(KUBASH_BIN)/kzsh

$(KUBASH_BIN)/kudash:
	echo '#!/usr/bin/env dash' > $(KUBASH_BIN)/kudash
	tail -n +2 "$(KUBASH_BIN)/kubash" >> $(KUBASH_BIN)/kudash

$(KUBASH_BIN)/helm: SHELL:=/bin/bash
$(KUBASH_BIN)/helm:
	@echo 'Installing helm'
	$(eval TMP := $(shell mktemp -d --suffix=HELMTMP))
	curl -fsSL -o $(TMP)/get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
	chmod 700 $(TMP)/get_helm.sh
	cd $(TMP); \
	HELM_INSTALL_DIR=$(HELM_INSTALL_DIR) \
	bash $(TMP)/get_helm.sh
	rm $(TMP)/get_helm.sh
	rmdir $(TMP)

istioctl: $(KUBASH_BIN)
	@scripts/kubashnstaller istioctl

$(KUBASH_BIN)/istioctl:
	@echo 'Installing istioctl'
	$(eval TMP := $(shell mktemp -d --suffix=KUBECTLTMP))
	cd $(TMP) && \
	curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$(ISTIO_VERSION) sh -
	mv $(TMP)/istio-$(ISTIO_VERSION)/bin/istioctl $(KUBASH_DIR)/bin/
	rm -Rf $(TMP)/istio-$(ISTIO_VERSION)
	rmdir $(TMP)

k9s: $(KUBASH_BIN)
	@scripts/kubashnstaller k9s

$(KUBASH_BIN)/k9s:
	@echo 'Installing k9s'
	$(eval TMP := $(shell mktemp -d --suffix=KUBECTLTMP))
	cd $(TMP) && \
	curl -L https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_x86_64.tar.gz |tar zxf -
	mv $(TMP)/k9s $(KUBASH_DIR)/bin/
	rm -Rf $(TMP)

kubectl: $(KUBASH_BIN)
	@scripts/kubashnstaller kubectl

$(KUBASH_BIN)/kubectl:
	@echo 'Installing kubectl'
	$(eval TMP := $(shell mktemp -d --suffix=KUBECTLTMP))
	$(eval KUBECTL_STABLE := $(shell curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt))
	cd $(TMP) \
	&& curl -sLO https://storage.googleapis.com/kubernetes-release/release/$(KUBECTL_STABLE)/bin/linux/amd64/kubectl \
	&& chmod +x kubectl \
	&& sudo mv -v kubectl $(KUBASH_BIN)/
	rmdir $(TMP)

kubedb: $(KUBASH_BIN)
	@scripts/kubashnstaller kubedb

$(KUBASH_BIN)/kubedb:
	@echo 'Installing kubedb'
	$(eval TMP := $(shell mktemp -d --suffix=kubedbTMP))
	cd $(TMP) \
	&& wget -O kubedb https://github.com/kubedb/cli/releases/download/0.11.0/kubedb-linux-amd64 \
	&& chmod +x kubedb \
	&& sudo mv -v kubedb $(KUBASH_BIN)/
	rmdir $(TMP)


$(KUBASH_BIN):
	mkdir -p $(KUBASH_BIN)

minikube: $(KUBASH_BIN)
	@scripts/kubashnstaller minikube

$(KUBASH_BIN)/minikube:
	@echo 'Installing minikube'
	$(eval TMP := $(shell mktemp -d --suffix=MINIKUBETMP))
	mkdir $(HOME)/.kube || true
	touch $(HOME)/.kube/config
	cd $(TMP) \
	&& curl -sLo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube $(KUBASH_BIN)/
	rmdir $(TMP)

vanity:
	curl -i https://git.io -F "url=https://raw.githubusercontent.com/joshuacox/kubash/master/bootstrap" -F "code=kubash"

crictl: $(KUBASH_BIN)
	@scripts/kubashnstaller crictl

$(KUBASH_BIN)/crictl: SHELL:=/bin/bash
$(KUBASH_BIN)/crictl:
	@echo 'Installing cri-tools'
	curl -L "https://github.com/kubernetes-incubator/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz" | tar -C $(KUBASH_BIN) -xz

cni: $(KUBASH_BIN)
	@scripts/kubashnstaller cni

$(KUBASH_BIN)/cni: SHELL:=/bin/bash
$(KUBASH_BIN)/cni:
	@echo 'Installing cni'
	curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-amd64-${CNI_VERSION}.tgz" | tar -C $(KUBASH_BIN) -xz

kompose: $(KUBASH_BIN)
	@scripts/kubashnstaller kompose

$(KUBASH_BIN)/kompose: SHELL:=/bin/bash
$(KUBASH_BIN)/kompose:
	$(eval TMP := $(shell mktemp -d --suffix=MINIKUBETMP))
	cd $(TMP) \
	&& curl -L https://github.com/kubernetes/kompose/releases/download/v1.18.0/kompose-linux-amd64 -o kompose
	install -m511 ${TMP}/kompose $(KUBASH_BIN)/
	rm ${TMP}/kompose
	rmdir ${TMP}

# force this to install as centos has another packer from the cracklib-dicts package
packer: $(KUBASH_BIN) $(KUBASH_BIN)/packer

$(KUBASH_BIN)/packer: SHELL:=/bin/bash
$(KUBASH_BIN)/packer:
	@echo 'Installing packer'
	$(eval TMP := $(shell mktemp -d --suffix=GOTMP))
	cd $(TMP) \
	&& wget -c \
	https://releases.hashicorp.com/packer/$(PACKER_VERSION)/packer_$(PACKER_VERSION)_linux_amd64.zip
	cd $(TMP) \
	&& unzip packer_$(PACKER_VERSION)_linux_amd64.zip
	rm $(TMP)/packer_$(PACKER_VERSION)_linux_amd64.zip
	mv $(TMP)/packer $(KUBASH_BIN)/packer 
	rmdir $(TMP)

go-build-docker:
	@echo 'Installing packer'
	$(eval TMP := $(shell mktemp -d --suffix=GOTMP))
	cd $(TMP) \
	go get github.com/hashicorp/packer
	rmdir $(TMP)


all-examples:
	make example
	cd $(KUBASH_DIR)/clusters; \
	rsync -av example/ openshift; \
	rsync -av example/ kubeadm2ha; \
	rsync -av example/ kubespray; \
	rsync -av example/ centos; \
	rsync -av example/ debian; \
	rsync -av example/ ubuntu; \
	rsync -av example/ coreos; \
	rsync -av example/ kubeadm196; \
	rsync -av example/ ubuntu196;
	sed -i 's/kubeadm/openshift/' $(KUBASH_DIR)/clusters/openshift/provision.csv
	sed -i 's/master0/openshiftm0/' $(KUBASH_DIR)/clusters/openshift/provision.csv
	sed -i 's/node0/openshiftn0/' $(KUBASH_DIR)/clusters/openshift/provision.csv
	sed -i 's/8a/aa/g' $(KUBASH_DIR)/clusters/openshift/provision.csv
	sed -i 's/^my-/openshift-/' $(KUBASH_DIR)/clusters/openshift/provision.csv
	sed -i 's/kubeadm/kubespray/' $(KUBASH_DIR)/clusters/kubespray/provision.csv
	sed -i 's/master0/kubespraym0/' $(KUBASH_DIR)/clusters/kubespray/provision.csv
	sed -i 's/node0/kubesprayn0/' $(KUBASH_DIR)/clusters/kubespray/provision.csv
	sed -i 's/8a/ab/g' $(KUBASH_DIR)/clusters/kubespray/provision.csv
	sed -i 's/^my-/kubespray-/' $(KUBASH_DIR)/clusters/kubespray/provision.csv
	sed -i 's/kubeadm/kubeadm2ha/' $(KUBASH_DIR)/clusters/kubeadm2ha/provision.csv
	sed -i 's/master0/kubeadm2ham0/' $(KUBASH_DIR)/clusters/kubeadm2ha/provision.csv
	sed -i 's/node0/kubeadm2han0/' $(KUBASH_DIR)/clusters/kubeadm2ha/provision.csv
	sed -i 's/8a/ac/g' $(KUBASH_DIR)/clusters/kubeadm2ha/provision.csv
	sed -i 's/^my-/kubeadm2ha-/' $(KUBASH_DIR)/clusters/kubeadm2ha/provision.csv
	sed -i 's/kubeadm/centos/' $(KUBASH_DIR)/clusters/centos/provision.csv
	sed -i 's/master0/centosm0/' $(KUBASH_DIR)/clusters/centos/provision.csv
	sed -i 's/node0/centosn0/' $(KUBASH_DIR)/clusters/centos/provision.csv
	sed -i 's/8a/ad/g' $(KUBASH_DIR)/clusters/centos/provision.csv
	sed -i 's/^my-/centos-/' $(KUBASH_DIR)/clusters/centos/provision.csv
	sed -i 's/kubeadm/debian/' $(KUBASH_DIR)/clusters/debian/provision.csv
	sed -i 's/master0/debianm0/' $(KUBASH_DIR)/clusters/debian/provision.csv
	sed -i 's/node0/debiann0/' $(KUBASH_DIR)/clusters/debian/provision.csv
	sed -i 's/8a/ae/g' $(KUBASH_DIR)/clusters/debian/provision.csv
	sed -i 's/^my-/debian-/' $(KUBASH_DIR)/clusters/debian/provision.csv
	sed -i 's/kubeadm/ubuntu/' $(KUBASH_DIR)/clusters/ubuntu/provision.csv
	sed -i 's/master0/ubuntum0/' $(KUBASH_DIR)/clusters/ubuntu/provision.csv
	sed -i 's/node0/ubuntun0/' $(KUBASH_DIR)/clusters/ubuntu/provision.csv
	sed -i 's/8a/a0/g' $(KUBASH_DIR)/clusters/ubuntu/provision.csv
	sed -i 's/^my-/ubuntu-/' $(KUBASH_DIR)/clusters/ubuntu/provision.csv
	sed -i 's/kubeadm/coreos/' $(KUBASH_DIR)/clusters/coreos/provision.csv
	sed -i 's/master0/coreosm0/' $(KUBASH_DIR)/clusters/coreos/provision.csv
	sed -i 's/node0/coreosn0/' $(KUBASH_DIR)/clusters/coreos/provision.csv
	sed -i 's/8a/a1/g' $(KUBASH_DIR)/clusters/coreos/provision.csv
	sed -i 's/^my-/coreos-/' $(KUBASH_DIR)/clusters/coreos/provision.csv
	sed -i 's/kubeadm/kubeadm196/' $(KUBASH_DIR)/clusters/kubeadm196/provision.csv
	sed -i 's/master0/kubeadm196m0/' $(KUBASH_DIR)/clusters/kubeadm196/provision.csv
	sed -i 's/node0/kubeadm196n0/' $(KUBASH_DIR)/clusters/kubeadm196/provision.csv
	sed -i 's/8a/c0/g' $(KUBASH_DIR)/clusters/kubeadm196/provision.csv
	sed -i 's/kubeadm/ubuntu196/' $(KUBASH_DIR)/clusters/ubuntu196/provision.csv
	sed -i 's/master0/ubuntu196m0/' $(KUBASH_DIR)/clusters/ubuntu196/provision.csv
	sed -i 's/node0/ubuntu196n0/' $(KUBASH_DIR)/clusters/ubuntu196/provision.csv
	sed -i 's/8a/b0/g' $(KUBASH_DIR)/clusters/ubuntu196/provision.csv

example:
	rm -Rf $(KUBASH_DIR)/clusters/example
	$(KUBASH_BIN)/kubash yaml2cluster -n example $(KUBASH_DIR)/examples/example-cluster.yaml

yaml2json:
	npm i -g yaml2json

pax/ubuntu/builds/ubuntu-16.04.libvirt.box:
	TMPDIR=/tiamat/tmp packer build -only=qemu kubash-ubuntu-16.04-amd64.json

oc: $(KUBASH_BIN)
	@scripts/kubashnstaller oc

$(KUBASH_BIN)/oc:
	$(eval TMP := $(shell mktemp -d --suffix=OCTMP))
	cd $(TMP) \
	&& curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/oc/latest/linux/oc.tar.gz | tar zxvf -
	sudo install -v -m511 ${TMP}/oc $(KUBASH_BIN)/oc
	rm -Rf $(TMP)
	

bats: $(KUBASH_BIN)
	@scripts/kubashnstaller bats

$(KUBASH_BIN)/bats:
	$(eval TMP := $(shell mktemp -d --suffix=BATSTMP))
	cd $(TMP) \
	&& git clone --depth=1 https://github.com/sstephenson/bats.git
	ls -lh $(TMP)
	ls -lh $(TMP)/bats
	cd $(TMP)/bats \
	&& sudo ./install.sh /usr/local
	rm -Rf $(TMP)

ci: chown reqs

ci-next: extended_tests monitoring

chown:
	sudo chown -R $(USER) /usr/local
	sudo mkdir -p /etc/kubernetes
	sudo chown -R $(USER) /etc/kubernetes
	sudo mkdir -p /etc/kubernetes
	sudo chown -R $(USER) /etc/kubernetes

autopilot: reqs .minikube.made
	@echo 'Autopilot engaged'

extended_tests:
	kubectl \
		--namespace=$(KUBASH_NAMESPACE) \
		get ep
	make -e dnstest
	./w8s/webpage.w8 $(KUBASH_NAME)
	kubectl \
		--namespace=$(KUBASH_NAMESPACE) \
		get all
	kubectl \
		--namespace=$(KUBASH_NAMESPACE) \
		get ep
	-@ echo 'Memory consumption of all that:'
	free -m

.minikube.made:
	sudo cp -v $(KUBASH_BIN)/minikube /usr/local/bin/
	sudo minikube \
		--kubernetes-version $(MY_KUBE_VERSION) \
		--dns-domain $(MINIKUBE_CLUSTER_DOMAIN) \
		--memory $(MINIKUBE_MEMORY) \
		--cpus $(MINIKUBE_CPU) \
		--vm-driver=$(MINIKUBE_DRIVER) \
		$(MINIKUBE_OPTS) \
		start
	@sh ./w8s/kubectl.w8
	helm init
	@sh ./w8s/tiller.w8
	@sh ./w8s/kube-dns.w8
	date -I > .minikube.made

## Monitoring
monitoring: .monitoring.ns .prometheus.rn

view-monitoring:
		kubectl \
			--namespace=$(MONITORING_NAMESPACE) \
			get pods

### Prometheus
prometheus: .prometheus.rn view-monitoring

# https://itnext.io/kubernetes-monitoring-with-prometheus-in-15-minutes-8e54d1de2e13
.prometheus.rn: .monitoring.ns
	helm repo add coreos https://s3-eu-west-1.amazonaws.com/coreos-charts/stable/
	git submodule update --init
	cd submodules/prometheus-operator \
		&& kubectl apply -f scripts/minikube-rbac.yaml \
		&& helm install --name prometheus-operator \
			--set rbacEnable=true \
			--namespace=$(MONITORING_NAMESPACE) \
			helm/prometheus-operator \
		&& helm install --name prometheus \
			--set serviceMonitorsSelector.app=prometheus \
			--set ruleSelector.app=prometheus \
			--namespace=$(MONITORING_NAMESPACE) \
			helm/prometheus \
		&& helm install --name alertmanager \
			--namespace=$(MONITORING_NAMESPACE) \
			helm/alertmanager \
		&& helm install --name grafana \
			--namespace=$(MONITORING_NAMESPACE) \
			helm/grafana
	cd submodules/prometheus-operator/helm/kube-prometheus \
		&& helm dep update
	cd submodules/prometheus-operator \
		&& helm install --name kube-prometheus \
			--namespace=$(MONITORING_NAMESPACE) \
			helm/kube-prometheus
	@sh ./w8s/generic.w8 prometheus-operator $(MONITORING_NAMESPACE)
	@sh ./w8s/generic.w8 alertmanager-kube-prometheus $(MONITORING_NAMESPACE)
	@sh ./w8s/generic.w8 kube-prometheus-exporter-kube-state $(MONITORING_NAMESPACE)
	@sh ./w8s/generic.w8 kube-prometheus-exporter-node $(MONITORING_NAMESPACE)
	@sh ./w8s/generic.w8 kube-prometheus-grafana $(MONITORING_NAMESPACE)
	@sh ./w8s/generic.w8 prometheus-kube-prometheus $(MONITORING_NAMESPACE)
	-@echo $(PROMETHEUS_NAME) > .prometheus.rn

# Namespaces
.monitoring.ns:
	kubectl create ns monitoring
	date -I > .monitoring.ns

t: tests

tests:
	@echo 'These are the bats tests'
	bats .ci/.tests.bats

fail_tests:
	@echo 'These are tests which fail and can be considered future fixes'
	bats .fails.bats

ct: $(KUBASH_BIN)/ct

$(KUBASH_BIN)/ct:
	$(eval TMP := $(shell mktemp -d --suffix=CTTMP))
	cd $(TMP) \
	&& curl -sL -o ct \
	https://github.com/coreos/container-linux-config-transpiler/releases/download/$(CT_VERSION)/ct-$(CT_VERSION)-x86_64-unknown-linux-gnu \
	&& chmod +x ct \
	&& mv ct $(KUBASH_BIN)/
	rm -Rf $(TMP)

opctl: $(KUBASH_BIN)/opctl

$(KUBASH_BIN)/opctl:
	$(eval TMP := $(shell mktemp -d --suffix=CTTMP))
	cd $(TMP) \
	&& curl -sLO https://github.com/onepanelio/core/releases/latest/download/opctl-linux-amd64 \
	&& chmod +x opctl-linux-amd64 \
	&& mv -v opctl-linux-amd64 $(KUBASH_BIN)/opctl
	rm -Rf $(TMP)

gcloud:
	curl https://sdk.cloud.google.com | bash

submodules/openebs:
	cd submodules; git clone https://github.com/openebs/openebs.git

cfssl:
	sudo curl -s -o $(KUBASH_BIN)/cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
	sudo curl -s -o $(KUBASH_BIN)/cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
	sudo ls -alh $(KUBASH_BIN)/
	sudo chmod +x $(KUBASH_BIN)/cfssl*


anaconda: $(KUBASH_BIN)/Anaconda.sh
	bash $(KUBASH_BIN)/Anaconda.sh

$(KUBASH_BIN)/Anaconda.sh:
	wget -c -O $(KUBASH_BIN)/Anaconda.sh https://repo.continuum.io/archive/Anaconda3-5.1.0-Linux-x86_64.sh

nvm:
	curl --silent -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash

coreos_key:
	$(eval TMP := $(shell mktemp -d --suffix=CKTMP))
	curl -O https://coreos.com/security/image-signing-key/CoreOS_Image_Signing_Key.asc -o $(TMP)/CoreOS_Image_Signing_Key.asc
	gpg --import --keyid-format LONG CoreOS_Image_Signing_Key.asc
	rm -Rf $(TMP)

testy:
	kubash -n testy decommission -y
	rm -Rf ~/.kubash/clusters/testy
	kubash yaml2cluster -n testy ~/.kubash/examples/testy-cluster.yaml
	kubash -n testy -y provision
	kubash -n testy --verbosity=105 etcd_ext


kustomize: $(KUBASH_BIN)/kustomize

$(KUBASH_BIN)/kustomize:
	$(eval TMP := $(shell mktemp -d --suffix=kustomizeTMP))
	cd $(TMP) \
  && curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
	mv -v  $(TMP)/kustomize $(KUBASH_BIN)/
	rm -Rf $(TMP)

kubectl-cert_manager: $(KUBASH_BIN)/kubectl-cert_manager

$(KUBASH_BIN)/kubectl-cert_manager:
	$(eval TMP := $(shell mktemp -d --suffix=CTmgrTMP))
	cd $(TMP) \
	&& curl -L -o kubectl-cert-manager.tar.gz https://github.com/jetstack/cert-manager/releases/download/v1.0.4/kubectl-cert_manager-linux-amd64.tar.gz \
	&& tar xzf kubectl-cert-manager.tar.gz \
	&& sudo mv kubectl-cert_manager $(KUBASH_BIN)/
	rm -Rf $(TMP)

kubeprod: $(KUBASH_BIN)/kubeprod

$(KUBASH_BIN)/kubeprod:
	$(eval BKPR_VERSION := $(shell curl --silent "https://api.github.com/repos/bitnami/kube-prod-runtime/releases/latest" | jq -r '.tag_name'))
	$(eval TMP := $(shell mktemp -d --suffix=prodTMP))
	cd $(TMP) \
	&& curl -LO https://github.com/bitnami/kube-prod-runtime/releases/download/${BKPR_VERSION}/bkpr-${BKPR_VERSION}-linux-amd64.tar.gz \
	&& tar zxf bkpr-${BKPR_VERSION}-linux-amd64.tar.gz \
	&& chmod +x bkpr-${BKPR_VERSION}/kubeprod \
	&& sudo mv -v bkpr-${BKPR_VERSION}/kubeprod $(KUBASH_BIN)/
	rm -Rf $(TMP)

kubecfg: $(KUBASH_BIN)/kubecfg

$(KUBASH_BIN)/kubecfg:
	$(eval TMP := $(shell mktemp -d --suffix=kbTMP))
	cd $(TMP) \
	&& curl -LO https://github.com/bitnami/kubecfg/releases/download/${KUBECFG_VERSION}/kubecfg-linux-amd64
	install -m511 $(TMP)/kubecfg-linux-amd64 $(KUBASH_BIN)/kubecfg
	rm -Rf $(TMP)

terraform: $(KUBASH_BIN)/terraform

$(KUBASH_BIN)/terraform:
	$(eval TMP := $(shell mktemp -d --suffix=terraformTMP))
	cd $(TMP) \
		&& curl -LO https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
		&& unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
	install -m511 $(TMP)/terraform $(KUBASH_BIN)/terraform
	rm -Rf $(TMP)


kubebuilder: $(KUBASH_BIN)/kubebuilder

$(KUBASH_BIN)/kubebuilder:
	# https://book.kubebuilder.io/quick-start.html#installation
	$(eval TMP := $(shell mktemp -d --suffix=kubashTMP))
	#os=$(go env GOOS)
	$(eval os := $(shell go env GOOS))
	#arch=$(go env GOARCH)
	$(eval arch := $(shell go env GOARCH))
	# download kubebuilder and extract it to tmp
	# curl -L https://go.kubebuilder.io/dl/2.3.1/${os}/${arch} | tar -xz -C /tmp/
	curl -L https://go.kubebuilder.io/dl/${KUBEBUILDER_VERS}/${os}/${arch} | tar -xz -C ${TMP}
	# move to a long-term location and put it on your path
	# (you'll need to set the KUBEBUILDER_ASSETS env var if you put it somewhere else)
	#sudo mv /tmp/kubebuilder_${KUBEBUILDER_VERS}_${os}_${arch} /usr/local/kubebuilder
	ls -Ralh ${TMP}/kubebuilder_${KUBEBUILDER_VERS}_${os}_${arch}/
	sudo install -m511 ${TMP}/kubebuilder_${KUBEBUILDER_VERS}_${os}_${arch}/bin/kubebuilder $(KUBASH_BIN)/kubebuilder
	#export PATH=${PATH}:/usr/local/kubebuilder/bin
	rm -Rf $(TMP)

kind: $(KUBASH_BIN)/kind

$(KUBASH_BIN)/kind:
	# https://kind.sigs.k8s.io/docs/user/quick-start/
	$(eval TMP := $(shell mktemp -d --suffix=kubashTMP))
	curl -Lo $(TMP)/kind https://kind.sigs.k8s.io/dl/${KIND_VERS}/kind-linux-amd64
	chmod +x $(TMP)/kind
	sudo install -v -m511 ${TMP}/kind $(KUBASH_BIN)/kind
	rm -Rf $(TMP)

rke: $(KUBASH_BIN)/rke

$(KUBASH_BIN)/rke:
	# https://rke.sigs.k8s.io/docs/user/quick-start/
	$(eval TMP := $(shell mktemp -d --suffix=kubashTMP))
	curl -Lo $(TMP)/rke https://github.com/rancher/rke/releases/download/${RKE_VERS}/rke_linux-amd64
	chmod +x $(TMP)/rke
	sudo install -v -m511 ${TMP}/rke $(KUBASH_BIN)/rke
	rm -Rf $(TMP)

talos: $(KUBASH_BIN)/talos

$(KUBASH_BIN)/talos:
	# https://talos.sigs.k8s.io/docs/user/quick-start/
	$(eval TMP := $(shell mktemp -d --suffix=kubashTMP))
	curl -Lo $(TMP)/talosctl https://github.com/talos-systems/talos/releases/latest/download/talosctl-$(uname -s | tr "[:upper:]" "[:lower:]")-amd64
	chmod +x $(TMP)/talos
	sudo install -v -m511 ${TMP}/talos $(KUBASH_BIN)/talos
	rm -Rf $(TMP)

arkade: $(KUBASH_BIN)/arkade

$(KUBASH_BIN)/arkade:
	$(eval TMP := $(shell mktemp -d --suffix=kubashTMP))
	cd $(TMP) && curl -sLS https://dl.get-arkade.dev | sh
	chmod +x $(TMP)/arkade
	sudo install -v -m511 ${TMP}/arkade $(KUBASH_BIN)/arkade
	rm -Rf $(TMP)

nomad: $(KUBASH_BIN)/nomad

$(KUBASH_BIN)/nomad:
	$(eval TMP := $(shell mktemp -d --suffix=kubashTMP))
	cd $(TMP) && curl -sLS https://releases.hashicorp.com/nomad/1.1.0/nomad_1.1.0_linux_amd64.zip | jar xv
	cd $(TMP) && ls -alh
	chmod +x $(TMP)/nomad
	sudo install -v -m511 ${TMP}/nomad $(KUBASH_BIN)/nomad
	rm -Rf $(TMP)