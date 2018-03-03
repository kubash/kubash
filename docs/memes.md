# yo dawg

Yo Dawg! I heard you like orchestration?  So I put an orchestrator inside of your orchestration, so you can orchestrate your orchestration while orchestrating ....

Why is kubernetes so complicated to set up?  Oh there's minikube, but don't use minikube to setup your cluster, there's kubadm for that, but it can't provision your cluster, or make it do anything afterwards it hasn't even heard of tiller.... yada yada

KUBASH!!!  Be gone with such woes, build your images `kubash build`, define your hosts in provision.csv and then provision `kubash auto` which will initialize the cluster, start networking, add openebs, and tiller and get you well on your way to serving actual containers.
