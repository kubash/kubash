# Provision


```
kubash provision
```

### provision.list

This file is the main control point for `kubash provision`, each node is listed like so:

```
#name,role,cpuCount,Memory,network,mac,provisionerHost,provisionerUser,provisionerPort,provisionerBasePath,os,virt
```

one, and only one node should be denoted `init_master` this is the first node to seed the rest of the cluster

```
master1,init_master,2,4096,default,52:54:00:e2:8c:11,localhost,root,22,/var/lib/libvirt/images,ubuntu,qemu
```

Additional masters can then be listed as such:

```
master2,master,2,4096,default,52:54:00:e2:8c:12,localhost,root,22,/var/lib/libvirt/images,ubuntu,qemu
```

And then the nodes:

```
node1,node,2,4096,default,52:54:00:e2:8c:13,localhost,root,22,/var/lib/libvirt/images,ubuntu,qemu
node2,node,2,4096,default,52:54:00:e2:8c:14,localhost,root,22,/var/lib/libvirt/images,ubuntu,qemu
node3,node,2,4096,default,52:54:00:e2:8c:15,localhost,root,22,/var/lib/libvirt/images,ubuntu,qemu
```

for the ansible playbook initializers you can also specify etcd nodes

```
etcd1,etcd,2,4096,default,52:54:00:e2:8c:16,localhost,root,22,/var/lib/libvirt/images,ubuntu,qemu
```

### Generate mac address

Kubash can also generate mac addresses for you:

```
kubash genmac
```

### Asciinema example run

[![asciicast](https://asciinema.org/a/164071.png)](https://asciinema.org/a/164071)
