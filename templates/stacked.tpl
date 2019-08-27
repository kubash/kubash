---
  csv_version: '4.0.0'
  kubernetes_version: '$REPLACEME_KUBE_VER'
  hosts:
    stacked-master1:
      hostname: stackedmaster1
      role: primary_master
      cpuCount: 4
      Memory: 2800
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9e:11'
        ip: dhcp
    stacked-master2:
      hostname: stackedmaster2
      role: master
      cpuCount: 4
      Memory: 2500
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9e:12'
        ip: dhcp
    stacked-master3:
      hostname: stackedmaster3
      role: master
      cpuCount: 4
      Memory: 2500
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9e:13'
        ip: dhcp
    stacked-node1:
      hostname: stackednode1
      role: node
      cpuCount: 4
      Memory: 4096
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9e:17'
        ip: dhcp
    stacked-node2:
      hostname: stackednode2
      role: node
      cpuCount: 3
      Memory: 2222
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9e:18'
        ip: dhcp
    stacked-node3:
      hostname: stackednode3
      role: node
      cpuCount: 2
      Memory: 2222
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9e:19'
        ip: dhcp
    stacked-ingress1:
      hostname: stackedingress1
      role: ingress
      cpuCount: 2
      Memory: 2222
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9e:20'
        ip: dhcp
    stacked-storage1:
      hostname: stackedstorage1
      role: storage
      cpuCount: 2
      Memory: 2222
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9e:21'
        ip: dhcp
  ca:
    cert:
      CERT_COMMON_NAME: etcd
      CERT_COUNTRY: US
      CERT_LOCALITY: Austin
      CERT_ORGANISATION: stacked
      CERT_STATE: Texas
      CERT_ORG_UNIT: Deployment
  net_set: flannel
  users:
    admin:
      role: admin
    bob:
      role: provisioner
    logger:
      role: log
