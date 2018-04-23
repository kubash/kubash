# Ingress

There are a few shortcuts to get various ingress started on the cluster
for testing

#### [voyager](https://appscode.com/products/voyager/6.0.0/)

`kubash voyager`

#### [traefik](https://traefik.io)

`kubash traefik`

#### [linkerd](https://linkerd.io)

`kubash linkerd`

#### taint_ingress node1 [node2] [node3]....

This preps a node with an 'ingress=true' label it as ingress, and also prevents normal
scheduling on the node.
