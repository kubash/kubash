---
  csv_version: '5.0.0'
  kubernetes_version: '$REPLACEME_KUBE_VER'
  hosts:
    extetcd-master1:
      hostname: extetcdmaster1
      role: primary_master
      cpuCount: 22
      Memory: 2800
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      kvm_os_variant: virtio26
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9f:11'
        ip: dhcp
    extetcd-master2:
      hostname: extetcdmaster2
      role: master
      cpuCount: 1
      Memory: 1500
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      kvm_os_variant: virtio26
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9f:12'
        ip: dhcp
    extetcd-master3:
      hostname: extetcdmaster3
      role: master
      cpuCount: 1
      Memory: 1500
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      kvm_os_variant: virtio26
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9f:13'
        ip: dhcp
    extetcd-etcd1:
      hostname: extetcdetcd1
      role: primary_etcd
      cpuCount: 1
      Memory: 1496
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      kvm_os_variant: virtio26
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9f:14'
        ip: dhcp
    extetcd-etcd2:
      hostname: extetcdetcd2
      role: etcd
      cpuCount: 1
      Memory: 1222
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      kvm_os_variant: virtio26
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9f:15'
        ip: dhcp
    extetcd-etcd3:
      hostname: extetcdetcd3
      role: etcd
      cpuCount: 1
      Memory: 1122
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      kvm_os_variant: virtio26
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9f:16'
        ip: dhcp
    extetcd-node1:
      hostname: extetcdnode1
      role: node
      cpuCount: 4
      Memory: 4096
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      kvm_os_variant: virtio26
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9f:17'
        ip: dhcp
    extetcd-node2:
      hostname: extetcdnode2
      role: node
      cpuCount: 3
      Memory: 2222
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      kvm_os_variant: virtio26
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9f:18'
        ip: dhcp
    extetcd-node3:
      hostname: extetcdnode3
      role: node
      cpuCount: 2
      Memory: 2222
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      kvm_os_variant: virtio26
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9f:19'
        ip: dhcp
    extetcd-ingress1:
      hostname: extetcdingress1
      role: ingress
      cpuCount: 2
      Memory: 2222
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      kvm_os_variant: virtio26
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9f:20'
        ip: dhcp
    extetcd-storage1:
      hostname: extetcdstorage1
      role: storage
      cpuCount: 2
      Memory: 2222
      provisioner:
        Host: 'localhost'
        User: root
        Port: 22
        BasePath: '/var/lib/libvirt/images'
      os: $REPLACEME_OS_TPL
      kvm_os_variant: virtio26
      virt: qemu
      sshPort: 22
      network1:
        network: network=default
        mac: '52:54:00:e2:9f:21'
        ip: dhcp
  ca:
    cert:
      CERT_COMMON_NAME: etcd
      CERT_COUNTRY: US
      CERT_LOCALITY: Austin
      CERT_ORGANISATION: extetcd
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
