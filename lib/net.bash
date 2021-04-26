#!/usr/bin/env bash

configure_secondary_network_interfaces () {
  squawk 1 "configure_secondary_network_interfaces"
  slurpy="$(grep -v '^#' $KUBASH_HOSTS_CSV)"
  squawk 8 "$slurpy"
  configure_static_network_addresses_tmp=$(mktemp -d)
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    squawk 7 "OS is $K8S_os"
    if [[ $K8S_os =~ debian* || $K8S_os =~ ubuntu* ]]; then
      if [ "$K8S_network2" = 'null' ]; then
        squawk 7 "K8S_network2 is null"
      else
        squawk 7 "K8S_network2 is $K8S_network2"
        export this_interface=eth1
        if [ "$K8S_ip2" = 'dhcp' ]; then
          squawk 7 "network2 is DHCP"
          envsubst < $KUBASH_DIR/templates/debian-dhcp.interface \
          > $configure_static_network_addresses_tmp/kubash_interface
          rsync $KUBASH_RSYNC_OPTS "ssh -p $K8S_sshPort" \
            $configure_static_network_addresses_tmp/kubash_interface \
            $K8S_SU_USER@$K8S_ip1:/tmp/kubash_interface-$this_interface.cfg
          command2run="mv -v /tmp/kubash_interface-$this_interface.cfg /etc/network/interfaces.d/kubash_interface-$this_interface.cfg"
          sudo_command $K8S_sshPort $K8S_SU_USER $K8S_ip1 "$command2run"
        else
          squawk 7 "network2 is static setting"
          #sudo_command $K8S_sshPort $K8S_SU_USER $K8S_ip1 "$command2run"
          if [ ! "$K8S_ip2" = 'null' ]; then
            export this_ip="address $K8S_ip2"
          fi
          if [ ! "$K8S_subnetmask2" = 'null' ]; then
            export this_netmask="netmask $K8S_subnetmask2"
          fi
          if [ ! "$K8S_routingprefix2" = 'null' ]; then
            export this_network="network $K8S_routingprefix2"
          fi
          if [ ! "$K8S_broadcast2" = 'null' ]; then
            export this_broadcast="broadcast $K8S_broadcast2"
          fi
          if [ ! "$K8S_gateway2" = 'null' ]; then
            export this_gateway="gateway $K8S_gateway2"
          fi
          envsubst < $KUBASH_DIR/templates/debian-static.interface \
          > $configure_static_network_addresses_tmp/kubash_interface
          rsync $KUBASH_RSYNC_OPTS "ssh -p $K8S_sshPort" \
            $configure_static_network_addresses_tmp/kubash_interface \
            $K8S_SU_USER@$K8S_ip1:/tmp/kubash_interface-$this_interface.cfg
          command2run="mv -v /tmp/kubash_interface-$this_interface.cfg /etc/network/interfaces.d/kubash_interface-$this_interface.cfg"
          sudo_command $K8S_sshPort $K8S_SU_USER $K8S_ip1 "$command2run"
        fi
        command2run="ifup $this_interface"
        sudo_command $K8S_sshPort $K8S_SU_USER $K8S_ip1 "$command2run"
      fi
      if [ "$K8S_network3" = 'null' ]; then
        squawk 7 "K8S_network3 is null"
      else
        squawk 7 "K8S_network3 is $K8S_network3"
        export this_interface=eth2
        if [ "$K8S_ip3" = 'dhcp' ]; then
          envsubst < $KUBASH_DIR/templates/debian-dhcp.interface \
          > $configure_static_network_addresses_tmp/kubash_interface
          rsync $KUBASH_RSYNC_OPTS "ssh -p $K8S_sshPort" \
            $configure_static_network_addresses_tmp/kubash_interface \
            $K8S_SU_USER@$K8S_ip1:/tmp/kubash_interface-$this_interface.cfg
          command2run="mv -v /tmp/kubash_interface-$this_interface.cfg /etc/network/interfaces.d/kubash_interface-$this_interface.cfg"
          sudo_command $K8S_sshPort $K8S_SU_USER $K8S_ip1 "$command2run"
        else
          #sudo_command $K8S_sshPort $K8S_SU_USER $K8S_ip1 "$command2run"
          if [ ! "$K8S_ip3" = 'null' ]; then
            export this_ip="address $K8S_ip3"
          fi
          if [ ! "$K8S_subnetmask3" = 'null' ]; then
            export this_netmask="netmask $K8S_subnetmask3"
          fi
          if [ ! "$K8S_routingprefix3" = 'null' ]; then
            export this_network="network $K8S_routingprefix3"
          fi
          if [ ! "$K8S_broadcast3" = 'null' ]; then
            export this_broadcast="broadcast $K8S_broadcast3"
          fi
          if [ ! "$K8S_gateway3" = 'null' ]; then
            export this_gateway="gateway $K8S_gateway3"
          fi
          envsubst < $KUBASH_DIR/templates/debian-static.interface \
          > $configure_static_network_addresses_tmp/kubash_interface
          rsync $KUBASH_RSYNC_OPTS "ssh -p $K8S_sshPort" \
            $configure_static_network_addresses_tmp/kubash_interface \
            $K8S_SU_USER@$K8S_ip1:/tmp/kubash_interface-$this_interface.cfg
          command2run="mv -v /tmp/kubash_interface-$this_interface.cfg /etc/network/interfaces.d/kubash_interface-$this_interface.cfg"
          sudo_command $K8S_sshPort $K8S_SU_USER $K8S_ip1 "$command2run"
        fi
        command2run="ifup $this_interface"
        sudo_command $K8S_sshPort $K8S_SU_USER $K8S_ip1 "$command2run"
      fi
    else
      squawk 1 "OS not supported by network configurator"
    fi
  done <<< "$slurpy"
  touch $configure_static_network_addresses_tmp/kubash_interface
  rm $configure_static_network_addresses_tmp/kubash_interface
  rmdir $configure_static_network_addresses_tmp
  squawk 19 'secondary network interfaces configured'
}

refresh_network_addresses () {
  squawk 1 "refresh_network_addresses"
  slurpy="$(grep -v '^#' $KUBASH_PROVISION_CSV)"
  squawk 8 "$slurpy"
  rm $KUBASH_HOSTS_CSV
  touch $KUBASH_HOSTS_CSV
  set_csv_columns
  squawk 22 "$PSEUDO ip -s -s neigh flush all"
  $PSEUDO ip -s -s neigh flush all
  while IFS="," read -r $csv_columns
  do
      net_type=$(echo $K8S_network1|cut -f1 -d=)
      if [[ "$net_type" == "network" ]]; then
        K8S_networkDiscovery=virsh
      else
        K8S_networkDiscovery=arp
      fi
      if [[ "$K8S_networkDiscovery" == "virsh" ]]; then
        if [[ "$K8S_provisionerHost" == "localhost" ]]; then
          countzero=0
          while [[ -z "$this_node_ip" ]]; do
            squawk 7 "checking for IP address"
            squawk 8 "$PSEUDO virsh domifaddr $K8S_node --full"
            this_node_ip=$($PSEUDO virsh domifaddr $K8S_node --full|grep ipv4|tail -n1|awk '{print $4}'|cut -f1 -d/ 2>/dev/null)
            if [[ "$countzero" -gt 2 ]]; then
              sleep 2
              fi
            ((++countzero))
          done
        else
          countzero=0
          this_node_ip=''
          while [[ "$this_node_ip" == '' ]]; do
            squawk 7 "checking for IP address"
            squawk 8 "$PSEUDO virsh domifaddr $K8S_node --full"
            this_node_ip=$(ssh -n -p $K8S_provisionerPort $K8S_provisionerUser@$K8S_provisionerHost "$PSEUDO virsh domifaddr $K8S_node --full"|grep ipv4|tail -n1|awk '{print $4}'|cut -f1 -d/ 2>/dev/null)
            if [[ "$countzero" -gt 2 ]]; then
              sleep 2
            fi
            ((++countzero))
          done
        fi
      elif [[ "$K8S_networkDiscovery" == "arp" ]]; then
        countzero=0
        this_node_ip=$($PSEUDO arp -n|grep $K8S_mac1|awk '{print $1}'|tail -n 1)
        while [[ -z "$this_node_ip" ]]; do
        squawk 2 "$PSEUDO nmap -p 22 $BROADCAST_TO_NETWORK"
        NMAP_OUTPUT=$($PSEUDO nmap -p 22 $BROADCAST_TO_NETWORK)
        squawk 1 "arp -n|grep $K8S_mac1|awk '{print \$1}'"
        this_node_ip=$($PSEUDO arp -n|grep $K8S_mac1|awk '{print $1}'|tail -n 1)
        if [[ "$countzero" -gt 2 ]]; then
          sleep 8
        fi
        sleep 2
        ((++countzero))
        done
      fi
      squawk 5 "adding to $KUBASH_HOSTS_CSV"
      if [[ "$K8S_os" == 'coreos' ]]; then
        this_K8S_user=$K8S_SU_USER
      else
        this_K8S_user=$K8S_user
      fi
      countzero=0
      set +e
      this_ssh_status=254
      until [[ "$this_ssh_status" == '0' ]]
      do
        if [[ "$countzero" -gt 25 ]]; then
          croak 3  "$K8S_node host not coming up investigate $this_node_ip"
        elif [[ "$countzero" -gt 2 ]]; then
          sleep 3
        fi
        squawk 19 "checking ssh $this_node_ip $countzero"
        squawk 33 "ssh -o 'UserKnownHostsFile /dev/null' -o 'StrictHostKeyChecking no' -n -q $this_K8S_user@$this_node_ip exit"
        ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -n -q $this_K8S_user@$this_node_ip exit
        this_ssh_status=$?
        ((++countzero))
      done
      set -e
      KUBASH_CSV_VER=$(cat $KUBASH_CSV_VER_FILE)
      if   [[ "$KUBASH_CSV_VER" == '1.0.0' ]]; then
        CSV_BUILDER="$K8S_node,$K8S_role,$K8S_cpuCount,$K8S_Memory,$K8S_sshPort,$K8S_network1,$K8S_mac1,$this_node_ip,$K8S_provisionerHost,$K8S_provisionerUser,$K8S_provisionerPort,$K8S_provisionerBasePath,$K8S_os,$K8S_virt,$K8S_network2,$K8S_mac2,$K8S_ip2,$K8S_network3,$K8S_mac3,$K8S_ip3"
      elif [[ "$KUBASH_CSV_VER" == '2.0.0' ]]; then
        CSV_BUILDER="$K8S_node,$K8S_role,$K8S_cpuCount,$K8S_Memory,$K8S_sshPort,$K8S_network1,$K8S_mac1,$this_node_ip,$K8S_routingprefix1,$K8S_subnetmask1,$K8S_broadcast1,$K8S_gateway1,$K8S_provisionerHost,$K8S_provisionerUser,$K8S_provisionerPort,$K8S_provisionerBasePath,$K8S_os,$K8S_virt,$K8S_network2,$K8S_mac2,$K8S_ip2,$K8S_routingprefix2,$K8S_subnetmask2,$K8S_broadcast2,$K8S_gateway2,$K8S_network3,$K8S_mac3,$K8S_ip3,$K8S_routingprefix3,$K8S_subnetmask3,$K8S_broadcast3,$K8S_gateway3"
      elif [[ "$KUBASH_CSV_VER" == '3.0.0' ]]; then
        CSV_BUILDER="$K8S_node,$K8S_role,$K8S_cpuCount,$K8S_Memory,$K8S_sshPort,$K8S_network1,$K8S_mac1,$this_node_ip,$K8S_routingprefix1,$K8S_subnetmask1,$K8S_broadcast1,$K8S_gateway1,$K8S_provisionerHost,$K8S_provisionerUser,$K8S_provisionerPort,$K8S_provisionerBasePath,$K8S_os,$K8S_virt,$K8S_network2,$K8S_mac2,$K8S_ip2,$K8S_routingprefix2,$K8S_subnetmask2,$K8S_broadcast2,$K8S_gateway2,$K8S_network3,$K8S_mac3,$K8S_ip3,$K8S_routingprefix3,$K8S_subnetmask3,$K8S_broadcast3,$K8S_gateway3,$K8S_iscsitarget,$K8S_iscsichapusername,$K8S_iscsichappassword,$K8S_iscsihost"
      elif [[ "$KUBASH_CSV_VER" == '4.0.0' ]]; then
        CSV_BUILDER="$K8S_node,$K8S_role,$K8S_cpuCount,$K8S_Memory,$K8S_sshPort,$K8S_network1,$K8S_mac1,$this_node_ip,$K8S_routingprefix1,$K8S_subnetmask1,$K8S_broadcast1,$K8S_gateway1,$K8S_provisionerHost,$K8S_provisionerUser,$K8S_provisionerPort,$K8S_provisionerBasePath,$K8S_os,$K8S_virt,$K8S_network2,$K8S_mac2,$K8S_ip2,$K8S_routingprefix2,$K8S_subnetmask2,$K8S_broadcast2,$K8S_gateway2,$K8S_network3,$K8S_mac3,$K8S_ip3,$K8S_routingprefix3,$K8S_subnetmask3,$K8S_broadcast3,$K8S_gateway3,$K8S_iscsitarget,$K8S_iscsichapusername,$K8S_iscsichappassword,$K8S_iscsihost,$K8S_storagePath,$K8S_storageType,$K8S_storageSize"
      elif [[ "$KUBASH_CSV_VER" == '5.0.0' ]]; then
        CSV_BUILDER="$K8S_node,$K8S_role,$K8S_cpuCount,$K8S_Memory,$K8S_sshPort,$K8S_network1,$K8S_mac1,$this_node_ip,$K8S_routingprefix1,$K8S_subnetmask1,$K8S_broadcast1,$K8S_gateway1,$K8S_provisionerHost,$K8S_provisionerUser,$K8S_provisionerPort,$K8S_provisionerBasePath,$K8S_os,$K8S_kvm_os_variant,$K8S_virt,$K8S_network2,$K8S_mac2,$K8S_ip2,$K8S_routingprefix2,$K8S_subnetmask2,$K8S_broadcast2,$K8S_gateway2,$K8S_network3,$K8S_mac3,$K8S_ip3,$K8S_routingprefix3,$K8S_subnetmask3,$K8S_broadcast3,$K8S_gateway3,$K8S_iscsitarget,$K8S_iscsichapusername,$K8S_iscsichappassword,$K8S_iscsihost,$K8S_storagePath,$K8S_storageType,$K8S_storageSize,$K8S_storageTarget,$K8S_storageMountPath,$K8S_storageUUID"
      elif [[ "$KUBASH_CSV_VER" == '6.0.0' ]]; then
        CSV_BUILDER="$K8S_node,$K8S_role,$K8S_cpuCount,$K8S_Memory,$K8S_sshPort,$K8S_network1,$K8S_mac1,$this_node_ip,$K8S_routingprefix1,$K8S_subnetmask1,$K8S_broadcast1,$K8S_gateway1,$K8S_provisionerHost,$K8S_provisionerUser,$K8S_provisionerPort,$K8S_provisionerBasePath,$K8S_os,$K8S_kvm_os_variant,$K8S_virt,$K8S_network2,$K8S_mac2,$K8S_ip2,$K8S_routingprefix2,$K8S_subnetmask2,$K8S_broadcast2,$K8S_gateway2,$K8S_network3,$K8S_mac3,$K8S_ip3,$K8S_routingprefix3,$K8S_subnetmask3,$K8S_broadcast3,$K8S_gateway3,$K8S_iscsitarget,$K8S_iscsichapusername,$K8S_iscsichappassword,$K8S_iscsihost,$K8S_storagePath,$K8S_storageType,$K8S_storageSize,$K8S_storageTarget,$K8S_storageMountPath,$K8S_storageUUID,$K8S_storagePath1,$K8S_storageType1,$K8S_storageSize1,$K8S_storageTarget1,$K8S_storageMountPath1,$K8S_storageUUID1,$K8S_storagePath2,$K8S_storageType2,$K8S_storageSize2,$K8S_storageTarget2,$K8S_storageMountPath2,$K8S_storageUUID2,$K8S_storagePath3,$K8S_storageType3,$K8S_storageSize3,$K8S_storageTarget3,$K8S_storageMountPath3,$K8S_storageUUID3"
      else
        croak 3  "CSV columns cannot be set, csv_ver=$CSV_VER not recognized"
      fi
      squawk 6 $CSV_BUILDER
      echo $CSV_BUILDER \
        >> $KUBASH_HOSTS_CSV
      this_node_ip=''
  done <<< "$slurpy"
  squawk 19 'network addresses refreshed'
}

do_net () {
  squawk 1 " do_net"
  slurpy="$(grep -v '^#' $KUBASH_PROVISION_CSV)"
  if [[ $K8S_NET == "calico" ]]; then
    kubectl --kubeconfig=$KUBECONFIG apply -f $CALICO_RBAC_URL
    kubectl --kubeconfig=$KUBECONFIG apply -f $CALICO_URL
  elif [[ $K8S_NET == "flannel" ]]; then
    kubectl --kubeconfig=$KUBECONFIG apply -f $FLANNEL_URL
  elif [[ $K8S_NET == "weavenet" ]]; then
    VERSION="$(kubectl version | base64 | tr -d '\n')"
    kubectl --kubeconfig=$KUBECONFIG apply -f "https://cloud.weave.works/k8s/net?k8s-version=${VERSION}"
  fi
}

