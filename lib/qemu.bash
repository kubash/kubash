#!/usr/bin/env bash

qemu-provisioner () {
  squawk 1 "qemu-provisioner $@"

  export K8S_node=$1
  export K8S_role=$2
  export K8S_cpuCount=$3
  export K8S_Memory=$4
  export K8S_network1=$5
  export K8S_mac1=$6
  export K8S_ip1=$7
  export K8S_provisionerHost=$8
  export K8S_provisionerUser=$9
  export K8S_provisionerPort=${10}
  export K8S_provisionerBasePath=${11}
  export K8S_os=${12}
  export K8S_virt=${13}
  export K8S_network2=${14}
  export K8S_mac2=${15}
  export K8S_ip2=${16}
  export K8S_network3=${17}
  export K8S_mac3=${18}
  export K8S_ip3=${19}
  if [[ "$K8S_mac1" == 'null' ]]; then
    K8S_mac1=$(VERBOSITY=0 kubash --verbosity=1 genmac)
  fi
  if [[ "$K8S_network2" != 'null' ]]; then
    if [[ "$K8S_mac2" == 'null' ]]; then
      K8S_mac2=$(VERBOSITY=0 kubash --verbosity=1 genmac)
    fi
    SECOND_NIC="--network=$K8S_network2,mac=$K8S_mac2,model=virtio"
  else
    SECOND_NIC=" "
  fi
  if [[ "$K8S_network3" != 'null' ]]; then
    if [[ "$K8S_mac3" == 'null' ]]; then
      K8S_mac3=$(VERBOSITY=0 kubash --verbosity=1 genmac)
    fi
    THIRD_NIC="--network=$K8S_network3,mac=$K8S_mac3,model=virtio"
  else
    THIRD_NIC=" "
  fi

  squawk 7 "K8S_node=$1
  K8S_role=$2
  K8S_cpuCount=$3
  K8S_Memory=$4
  K8S_network1=$5
  K8S_mac1=$6
  K8S_ip1=$7
  K8S_provisionerHost=$8
  K8S_provisionerUser=$9
  K8S_provisionerPort=${10}
  K8S_provisionerBasePath=${11}
  K8S_os=${12}
  K8S_virt=${13}
  K8S_network2=${14}
  K8S_mac2=${15}
  K8S_ip2=${16}
  K8S_network3=${17}
  K8S_mac3=${18}
  K8S_ip3=${19}
  "

  # Create VM for node
  qemunodeimg="$K8S_provisionerBasePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node.qcow2"
  if [[ "$K8S_os" == "coreos" ]]; then
    KVM_BASE_IMG=kubash.img
  fi
  qemucmd2run="$PSEUDO qemu-img create -f qcow2 -F qcow2 -b $K8S_provisionerBasePath/$KUBASH_CLUSTER_NAME-k8s-$KVM_BASE_IMG $qemunodeimg"

  if [[ "$K8S_os" == "coreos" ]]; then
    squawk 5 "Keyer"
    KEYTMP=$(mktemp -d)
    touch $KEYTMP/keys
    if [ ! -z  "$KEYS_URL" ]; then
      curl --silent -L "$KEYS_URL"  >> $KEYTMP/keys
    else
      echo 'no KEYS_URL given'
    fi
    if [ ! -z  "$KEYS_TO_ADD" ]; then
      echo "$KEYS_TO_ADD" >>  $KEYTMP/keys
    else
      echo 'no KEYS_TO_ADD given'
    fi
    squawk 18 "Keys $(cat $KEYTMP/keys)"
    echo '    ssh_authorized_keys:'>  $KEYTMP/keys.json
    cat  $KEYTMP/keys|sed 's/^/    - /' >> $KEYTMP/keys.json
    SSH_AUTHORIZED_KEYS=$(cat $KEYTMP/keys.json)
    squawk 19 "Keys.json $SSH_AUTHORIZED_KEYS"
    rm -Rf $KEYTMP
    chkdir $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node
    if [[ "$K8S_ip2" == 'null' && "$K8S_ip2" == 'null' ]]; then
      SSH_AUTHORIZED_KEYS=$SSH_AUTHORIZED_KEYS \
      K8S_SU_USER=$K8S_SU_USER \
      K8S_node=$K8S_node \
      envsubst < $KUBASH_DIR/templates/user_data \
      > $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node/user_data
    elif [[ "$K8S_ip2" -ne 'null' && "$K8S_ip3" == 'null' ]]; then
      K8S_mac2=$K8S_mac2 \
      K8S_ip2=$K8S_ip2 \
      SSH_AUTHORIZED_KEYS=$SSH_AUTHORIZED_KEYS \
      K8S_SU_USER=$K8S_SU_USER \
      K8S_node=$K8S_node \
      envsubst < $KUBASH_DIR/templates/user_data_two_interface \
      > $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node/user_data
    else
      K8S_mac2=$K8S_mac2 \
      K8S_ip2=$K8S_ip2 \
      K8S_network3=$K8S_network3 \
      K8S_mac3=$K8S_mac3 \
      K8S_ip3=$K8S_ip3 \
      SSH_AUTHORIZED_KEYS=$SSH_AUTHORIZED_KEYS \
      K8S_SU_USER=$K8S_SU_USER \
      K8S_node=$K8S_node \
      envsubst < $KUBASH_DIR/templates/user_data_three_interface \
      > $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node/user_data
    fi
    ct < $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node/user_data \
       > $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node/user_data.ign

    virshcmd2run="$PSEUDO virt-install --connect qemu:///system \
    --import \
    --autostart \
    --name $K8S_node \
    --ram $K8S_Memory \
    --vcpus $K8S_cpuCount \
    --os-type=linux \
    --os-variant=$K8S_kvm_os_variant \
    --noautoconsole \
    --accelerate \
    --hvm \
    --disk path=$qemunodeimg,format=qcow2,bus=virtio \
    --network=$K8S_network1,mac=$K8S_mac1,model=virtio \
    $SECOND_NIC \
    $THIRD_NIC \
    --print-xml
    " >&3 2>&3
  else
    # not coreOS
    virshcmd2run="$PSEUDO virt-install --connect qemu:///system \
    --import \
    --autostart \
    --name $K8S_node \
    --ram $K8S_Memory \
    --vcpus $K8S_cpuCount \
    --os-type=linux \
    --os-variant=$K8S_kvm_os_variant \
    --noautoconsole \
    --accelerate \
    --hvm \
    --disk path=$qemunodeimg,format=qcow2,bus=virtio \
    --network=$K8S_network1,mac=$K8S_mac1,model=virtio \
    $SECOND_NIC \
    $THIRD_NIC"
  fi

  if [[ "$K8S_provisionerHost" = "localhost" ]]; then
    squawk 5 "$qemucmd2run"
    $qemucmd2run
    if [[ "$K8S_os" == "coreos" ]]; then
      squawk 5 "create domain.xml $virshcmd2run"
      chmod 775 $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node
      chmod 775 $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME
      #ls -lh $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node
      #rm -f $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node/domain.xml
      squawk 5 "$virshcmd2run$virshcmd2run"
      $virshcmd2run > $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node/domain.xml
      sed -i 's|type=\"kvm\"|type=\"kvm\" xmlns:qemu=\"http://libvirt.org/schemas/domain/qemu/1.0\"|' $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node/domain.xml
      sed -i "/<\/devices>/a <qemu:commandline>\n  <qemu:arg value='-fw_cfg'/>\n  <qemu:arg value='name=opt/com.coreos/config,file=$K8S_provisionerBasePath/$KUBASH_CLUSTER_NAME/$K8S_node/user_data.ign'/>\n</qemu:commandline>" $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node/domain.xml
      squawk 5 "sync the cluster directory"

      squawk 9 "$PSEUDO rsync -az $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME $K8S_provisionerBasePath/"
      $PSEUDO rsync -az $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME $K8S_provisionerBasePath/

      $PSEUDO virsh define $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node/domain.xml
      sudo chown root. $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node/domain.xml
      sudo chown root. $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node/user_data.ign
      $PSEUDO virsh start $K8S_node
      if [[ $K8S_storageType == 'raw' ]]; then
        if [[ -f $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.raw ]]; then
          squawk 33 "File already exists using it"
        else
          $PSEUDO qemu-img create \
            -f raw $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.raw \
            $K8S_storageSize \
            -o preallocation=$QEMU_PREALLOCATION
        fi
        $PSEUDO virsh attach-disk --domain $K8S_node $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.raw --target $K8S_storageTarget --persistent --config --live
      elif [[ $K8S_storageType == 'qcow2' ]]; then
        if [[ -f $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.qcow2 ]]; then
          squawk 33 "File already exists using it"
        else
          $PSEUDO qemu-img create \
            -f qcow2 $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.qcow2 \
            $K8S_storageSize \
            -o preallocation=$QEMU_PREALLOCATION
        fi
        $PSEUDO virsh attach-disk --domain $K8S_node $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.qcow2 --target $K8S_storageTarget --persistent --config --live
      fi
      # disk 1
      if [[ $K8S_storageType1 == 'raw' ]]; then
        if [[ -f ${K8S_storagePath1}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget1}.raw ]]; then
          squawk 33 "File already exists using it"
        else
          $PSEUDO qemu-img create \
            -f raw ${K8S_storagePath1}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget1}.raw \
            ${K8S_storageSize1} \
            -o preallocation=$QEMU_PREALLOCATION
        fi
        $PSEUDO virsh attach-disk --domain $K8S_node ${K8S_storagePath1}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget1}.raw --target ${K8S_storageTarget1} --persistent --config --live
      elif [[ $K8S_storageType == 'qcow2' ]]; then
        if [[ -f ${K8S_storagePath1}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget1}.qcow2 ]]; then
          squawk 33 "File already exists using it"
        else
          $PSEUDO qemu-img create \
            -f qcow2 ${K8S_storagePath1}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget1}.qcow2 \
            ${K8S_storageSize1} \
            -o preallocation=$QEMU_PREALLOCATION
        fi
        $PSEUDO virsh attach-disk --domain $K8S_node ${K8S_storagePath1}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget1}.qcow2 --target ${K8S_storageTarget1} --persistent --config --live
      fi
      # disk 2
      if [[ $K8S_storageType2 == 'raw' ]]; then
        if [[ -f ${K8S_storagePath2}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget2}.raw ]]; then
          squawk 33 "File already exists using it"
        else
          $PSEUDO qemu-img create \
            -f raw ${K8S_storagePath2}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget2}.raw \
            ${K8S_storageSize2} \
            -o preallocation=$QEMU_PREALLOCATION
        fi
        $PSEUDO virsh attach-disk --domain $K8S_node ${K8S_storagePath2}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget2}.raw --target ${K8S_storageTarget2} --persistent --config --live
      elif [[ $K8S_storageType == 'qcow2' ]]; then
        if [[ -f ${K8S_storagePath2}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget2}.qcow2 ]]; then
          squawk 33 "File already exists using it"
        else
          $PSEUDO qemu-img create \
            -f qcow2 ${K8S_storagePath2}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget2}.qcow2 \
            ${K8S_storageSize2} \
            -o preallocation=$QEMU_PREALLOCATION
        fi
        $PSEUDO virsh attach-disk --domain $K8S_node ${K8S_storagePath2}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget2}.qcow2 --target ${K8S_storageTarget2} --persistent --config --live
      fi
      # disk 3
      if [[ $K8S_storageType1 == 'raw' ]]; then
        if [[ -f ${K8S_storagePath3}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget3}.raw ]]; then
          squawk 33 "File already exists using it"
        else
          $PSEUDO qemu-img create \
            -f raw ${K8S_storagePath3}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget3}.raw \
            ${K8S_storageSize3} \
            -o preallocation=$QEMU_PREALLOCATION
        fi
        $PSEUDO virsh attach-disk --domain $K8S_node ${K8S_storagePath3}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget3}.raw --target ${K8S_storageTarget3} --persistent --config --live
      elif [[ $K8S_storageType == 'qcow2' ]]; then
        if [[ -f ${K8S_storagePath3}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget3}.qcow2 ]]; then
          squawk 33 "File already exists using it"
        else
          $PSEUDO qemu-img create \
            -f qcow2 ${K8S_storagePath3}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget3}.qcow2 \
            ${K8S_storageSize3} \
            -o preallocation=$QEMU_PREALLOCATION
        fi
        $PSEUDO virsh attach-disk --domain $K8S_node ${K8S_storagePath3}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget3}.qcow2 --target ${K8S_storageTarget3} --persistent --config --live
      fi
    else
      # not coreOS
      squawk 5 "$PSEUDO $virshcmd2run"
      $PSEUDO $virshcmd2run
      if [[ $K8S_storageType == 'raw' ]]; then
        if [[ -f $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.raw ]]; then
          squawk 33 "File already exists using it"
        else
          $PSEUDO qemu-img create \
            -f raw $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.raw \
            $K8S_storageSize \
            -o preallocation=$QEMU_PREALLOCATION
        fi
        $PSEUDO virsh attach-disk --domain $K8S_node $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.raw --target $K8S_storageTarget --persistent --config --live
      elif [[ $K8S_storageType == 'qcow2' ]]; then
        if [[ -f $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.qcow2 ]]; then
          squawk 33 "File already exists using it"
        else
          $PSEUDO qemu-img create \
            -f qcow2 $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.qcow2 \
            $K8S_storageSize \
            -o preallocation=$QEMU_PREALLOCATION
        fi
        $PSEUDO virsh attach-disk --domain $K8S_node $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.qcow2 --target $K8S_storageTarget --persistent --config --live
      fi
      # disk 1
      if [[ ${K8S_storageType1} == 'raw' ]]; then
        if [[ -f ${K8S_storagePath1}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget1}.raw ]]; then
          squawk 33 "File already exists using it"
        else
          $PSEUDO qemu-img create \
            -f raw ${K8S_storagePath1}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget1}.raw \
            ${K8S_storageSize1} \
            -o preallocation=$QEMU_PREALLOCATION
        fi
        $PSEUDO virsh attach-disk --domain $K8S_node ${K8S_storagePath1}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget1}.raw --target ${K8S_storageTarget1} --persistent --config --live
      elif [[ ${K8S_storageType1} == 'qcow2' ]]; then
        if [[ -f ${K8S_storagePath1}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget1}.qcow2 ]]; then
          squawk 33 "File already exists using it"
        else
          $PSEUDO qemu-img create \
            -f qcow2 ${K8S_storagePath1}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget1}.qcow2 \
            ${K8S_storageSize1} \
            -o preallocation=$QEMU_PREALLOCATION
        fi
        $PSEUDO virsh attach-disk --domain $K8S_node ${K8S_storagePath1}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget1}.qcow2 --target ${K8S_storageTarget1} --persistent --config --live
      fi
      # disk 2
      if [[ ${K8S_storageType2} == 'raw' ]]; then
        if [[ -f ${K8S_storagePath2}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget2}.raw ]]; then
          squawk 33 "File already exists using it"
        else
          $PSEUDO qemu-img create \
            -f raw ${K8S_storagePath2}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget2}.raw \
            ${K8S_storageSize2} \
            -o preallocation=$QEMU_PREALLOCATION
        fi
        $PSEUDO virsh attach-disk --domain $K8S_node ${K8S_storagePath2}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget2}.raw --target ${K8S_storageTarget2} --persistent --config --live
      elif [[ ${K8S_storageType2} == 'qcow2' ]]; then
        if [[ -f ${K8S_storagePath2}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget2}.qcow2 ]]; then
          squawk 33 "File already exists using it"
        else
          $PSEUDO qemu-img create \
            -f qcow2 ${K8S_storagePath2}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget2}.qcow2 \
            ${K8S_storageSize2} \
            -o preallocation=$QEMU_PREALLOCATION
        fi
        $PSEUDO virsh attach-disk --domain $K8S_node ${K8S_storagePath2}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget2}.qcow2 --target ${K8S_storageTarget2} --persistent --config --live
      fi
      # disk 3
      if [[ ${K8S_storageType3} == 'raw' ]]; then
        if [[ -f ${K8S_storagePath3}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget3}.raw ]]; then
          squawk 33 "File already exists using it"
        else
          $PSEUDO qemu-img create \
            -f raw ${K8S_storagePath3}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget3}.raw \
            ${K8S_storageSize3} \
            -o preallocation=$QEMU_PREALLOCATION
        fi
        $PSEUDO virsh attach-disk --domain $K8S_node ${K8S_storagePath3}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget3}.raw --target ${K8S_storageTarget3} --persistent --config --live
      elif [[ ${K8S_storageType3} == 'qcow2' ]]; then
        if [[ -f ${K8S_storagePath3}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget3}.qcow2 ]]; then
          squawk 33 "File already exists using it"
        else
          $PSEUDO qemu-img create \
            -f qcow2 ${K8S_storagePath3}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget3}.qcow2 \
            ${K8S_storageSize3} \
            -o preallocation=$QEMU_PREALLOCATION
        fi
        $PSEUDO virsh attach-disk --domain $K8S_node ${K8S_storagePath3}/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-${K8S_storageTarget3}.qcow2 --target ${K8S_storageTarget3} --persistent --config --live
      fi
    fi
    # suspect
    #fi
  else
    squawk 5 "ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost $qemucmd2run"
    ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "$qemucmd2run"

    if [[ "$K8S_os" == "coreos" ]]; then
      squawk 5 "create the domain.xml"
      squawk 1 "touch $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node/domain.xml"
      touch $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node/domain.xml
      ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "$virshcmd2run" > $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node/domain.xml
      sed -i 's|type=\"kvm\"|type=\"kvm\" xmlns:qemu=\"http://libvirt.org/schemas/domain/qemu/1.0\"|' $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node/domain.xml
      sed -i "/<\/devices>/a <qemu:commandline>\n  <qemu:arg value='-fw_cfg'/>\n  <qemu:arg value='name=opt/com.coreos/config,file=$K8S_provisionerBasePath/$KUBASH_CLUSTER_NAME/$K8S_node/user_data.ign'/>\n</qemu:commandline>" $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME/$K8S_node/domain.xml

      squawk 5 "sync the cluster directory"
      squawk 9 "rsync $KUBASH_RSYNC_OPTS 'ssh -p$K8S_provisionerPort' $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME $K8S_provisionerUser@$K8S_provisionerHost:~/"
      rsync $KUBASH_RSYNC_OPTS "ssh -p$K8S_provisionerPort" $KUBASH_CLUSTERS_DIR/$KUBASH_CLUSTER_NAME $K8S_provisionerUser@$K8S_provisionerHost:$K8S_provisionerBasePath/


      virshcmd2run="$PSEUDO virsh define $K8S_provisionerBasePath/$KUBASH_CLUSTER_NAME/$K8S_node/domain.xml"
      squawk 5 "ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost $virshcmd2run"
      ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "$virshcmd2run"

      if [[ $K8S_storageType == 'raw' ]]; then
      set +e
            ssh -q -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "test -f $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.raw"
      if [[ $? -eq 0 ]]; then
        squawk 33 "File already exists using it"
      else
        squawk 33 "File does not already exist. Creating it"
          virshcmd2run="$PSEUDO qemu-img create -f raw $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.raw $K8S_storageSize -o preallocation=$QEMU_PREALLOCATION"
              squawk 5 "ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost $virshcmd2run"
              ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "$virshcmd2run"
      fi
	set -e
        virshcmd2run="$PSEUDO virsh attach-disk --domain $K8S_node $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.raw --target $K8S_storageTarget --persistent --config --live"
        squawk 5 "ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost $virshcmd2run"
        ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "$virshcmd2run"
      elif [[ $K8S_storageType == 'qcow2' ]]; then
	virshcmd2run="$PSEUDO qemu-img create -f qcow2 $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.qcow2 $K8S_storageSize -o preallocation=$QEMU_PREALLOCATION"
        squawk 5 "ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost $virshcmd2run"
        ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "$virshcmd2run"
	set +e
        ssh -q -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "test -f $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.qcow2"
	if [[ $? -eq 0 ]]; then
	  squawk 33 "File already exists using it"
	else
	  squawk 33 "File does not already exist. Creating it"
  	  virshcmd2run="$PSEUDO qemu-img create -f qcow2 $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.qcow2 $K8S_storageSize -o preallocation=$QEMU_PREALLOCATION"
          squawk 5 "ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost $virshcmd2run"
          ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "$virshcmd2run"
	fi
	set -e
        virshcmd2run="$PSEUDO virsh attach-disk --domain $K8S_node $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.qcow2 --target $K8S_storageTarget --persistent --config --live"
        squawk 5 "ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost $virshcmd2run"
        ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "$virshcmd2run"
      fi

      virshcmd2run="$PSEUDO virsh start $K8S_node"
      squawk 5 "ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost $virshcmd2run"
      ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "$virshcmd2run"
    else
      # not coreOS
      squawk 5 "ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost $virshcmd2run"
      ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "$virshcmd2run"
      if [[ $K8S_storageType == 'raw' ]]; then
	set +e
        ssh -q -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "test -f $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.raw"
	if [[ $? -eq 0 ]]; then
	  squawk 33 "File already exists using it"
	else
	  squawk 33 "File does not already exist. Creating it"
  	  virshcmd2run="$PSEUDO qemu-img create -f raw $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.raw $K8S_storageSize -o preallocation=$QEMU_PREALLOCATION"
          squawk 5 "ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost $virshcmd2run"
          ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "$virshcmd2run"
	fi
	set -e
        virshcmd2run="$PSEUDO virsh attach-disk --domain $K8S_node $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.raw --target $K8S_storageTarget --persistent --config --live"
        squawk 5 "ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost $virshcmd2run"
        ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "$virshcmd2run"
      elif [[ $K8S_storageType == 'qcow2' ]]; then
	set +e
        ssh -q -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "test -f $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.qcow2"
	if [[ $? -eq 0 ]]; then
	  squawk 33 "File already exists using it"
	else
	  squawk 33 "File does not already exist. Creating it"
  	  virshcmd2run="$PSEUDO qemu-img create -f qcow2 $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.qcow2 $K8S_storageSize -o preallocation=$QEMU_PREALLOCATION"
          squawk 5 "ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost $virshcmd2run"
          ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "$virshcmd2run"
	fi
	set -e
        virshcmd2run="$PSEUDO virsh attach-disk --domain $K8S_node $K8S_storagePath/$KUBASH_CLUSTER_NAME-k8s-$K8S_node-$K8S_storageTarget.qcow2 --target $K8S_storageTarget --persistent --config --live"
        squawk 5 "ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost $virshcmd2run"
        ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "$virshcmd2run"
      fi
    fi
  fi
}
