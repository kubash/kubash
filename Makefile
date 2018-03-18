# Reactionetes Makefile
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
$(eval MY_KUBE_VERSION := v1.8.0)
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

all: $(KUBASH_BIN)/kush $(KUBASH_BIN)/kzsh $(KUBASH_BIN)/kudash reqs anaconda nvm

reqs: linuxreqs

linuxreqs: kubectl helm minikube jinja2 submodules/openebs yaml2json ct

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
	curl -sLo $(TMP)/helmget --silent https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get
	HELM_INSTALL_DIR=$(HELM_INSTALL_DIR) \
	sudo -E bash -l $(TMP)/helmget
	rm $(TMP)/helmget
	rmdir $(TMP)

kubectl: $(KUBASH_BIN)
	@scripts/kubashnstaller kubectl

$(KUBASH_BIN)/kubectl:
	@echo 'Installing kubectl'
	$(eval TMP := $(shell mktemp -d --suffix=KUBECTLTMP))
	cd $(TMP) \
	&& curl -sLO https://storage.googleapis.com/kubernetes-release/release/$(MY_KUBE_VERSION)/bin/linux/amd64/kubectl \
	&& chmod +x kubectl \
	&& sudo mv -v kubectl $(KUBASH_BIN)/
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
	go get github.com/kubernetes-incubator/cri-tools/cmd/crictl
	cp ${GOPATH}/bin/crictl $(KUBASH_BIN)/

# force this to install as centos has another packer from the cracklib-dicts package
packer: $(KUBASH_BIN) $(KUBASH_BIN)/packer

$(KUBASH_BIN)/packer: SHELL:=/bin/bash
$(KUBASH_BIN)/packer:
	@echo 'Installing packer'
	$(eval PACKER_VERSION:=1.1.3)
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
	rsync -av example/ coreos;
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
	&& curl -sL https://github.com/openshift/origin/releases/download/v3.9.0-alpha.3/openshift-origin-client-tools-v3.9.0-alpha.3-78ddc10-linux-64bit.tar.gz | tar zxvf -
	mv -v $(TMP)/openshift-origin-client-tools*/oc $(KUBASH_BIN)/
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

ci: chown autopilot 
	
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
	minikube \
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

tests:
	@echo 'These are the bats tests'
	bats .tests.bats

fail_tests:
	@echo 'These are tests which fail and can be considered future fixes'
	bats .fails.bats

ct: $(KUBASH_BIN)/ct

$(KUBASH_BIN)/ct:
	$(eval TMP := $(shell mktemp -d --suffix=CTTMP))
	$(eval CT_VERSION := v0.7.0)
	cd $(TMP) \
	&& curl -sL -o ct \
	https://github.com/coreos/container-linux-config-transpiler/releases/download/$(CT_VERSION)/ct-$(CT_VERSION)-x86_64-unknown-linux-gnu \
	&& chmod +x ct \
	&& mv ct $(KUBASH_BIN)/
	rm -Rf $(TMP)

submodules/openebs:
	cd submodules; git clone https://github.com/openebs/openebs.git

cfssl:
	sudo curl -s -o $(KUBASH_BIN)/cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
	sudo curl -s -o $(KUBASH_BIN)/cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
	sudo chmod +x $(KUBASH_BIN)/cfssl*

jinja2:
	pip install jinja2 jinja2-cli

anaconda: $(KUBASH_BIN)/Anaconda.sh
	bash $(KUBASH_BIN)/Anaconda.sh

$(KUBASH_BIN)/Anaconda.sh:
	wget -c -O $(KUBASH_BIN)/Anaconda.sh https://repo.continuum.io/archive/Anaconda3-5.1.0-Linux-x86_64.sh

nvm:
	curl --silent -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | bash

coreos_key:
	$(eval TMP := $(shell mktemp -d --suffix=CKTMP))
	curl -O https://coreos.com/security/image-signing-key/CoreOS_Image_Signing_Key.asc -o $(TMP)/CoreOS_Image_Signing_Key.asc
	gpg --import --keyid-format LONG CoreOS_Image_Signing_Key.asc
	rm -Rf $(TMP)
