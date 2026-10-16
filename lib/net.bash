#!/usr/bin/env bash

netmask_to_prefix () {
  # Prints the prefix length for a dotted-quad netmask
  # (255.255.255.0 -> 24); netplan addresses must be CIDR.
  local -a octets
  local octet prefix=0
  IFS=. read -r -a octets <<< "$1"
  for octet in "${octets[@]}"; do
    while [ "$octet" -gt 0 ]; do
      prefix=$((prefix + octet % 2))
      octet=$((octet / 2))
    done
  done
  echo "$prefix"
}

configure_secondary_interface () {
  # Configures one secondary interface ($1) on the current host
  # from its CSV values: $2 ip ('dhcp' or an address), $3 subnetmask,
  # $4 routingprefix, $5 broadcast, $6 gateway ('null' = unset).
  # Debian-family hosts get an ifupdown snippet in
  # /etc/network/interfaces.d; Ubuntu-family hosts (use_netplan=true)
  # get a netplan file in /etc/netplan instead - ifupdown snippets
  # are ignored there.
  local this_iface=$1 this_addr=$2 this_mask=$3 this_prefix_addr=$4 this_bcast=$5 this_gw=$6
  export this_interface=$this_iface
  if [ "$this_addr" = 'dhcp' ]; then
    squawk 7 "$this_iface is DHCP"
    if [ "$use_netplan" = 'true' ]; then
      envsubst < $KUBASH_DIR/templates/netplan-dhcp.yaml \
      > $configure_static_network_addresses_tmp/kubash_interface
    else
      envsubst < $KUBASH_DIR/templates/debian-dhcp.interface \
      > $configure_static_network_addresses_tmp/kubash_interface
    fi
  else
    squawk 7 "$this_iface is static"
    # reset the envsubst inputs: a 'null' field must render
    # empty, not inherit the previous interface's value (#67)
    unset this_ip this_netmask this_network this_broadcast this_gateway
    if [ "$use_netplan" = 'true' ]; then
      if [ "$this_addr" = 'null' ]; then
        squawk 1 "netplan static $this_iface has no address, skipping"
        return 0
      fi
      # netplan requires CIDR; a 'null' netmask falls back to /24
      local cidr_prefix=24
      if [ ! "$this_mask" = 'null' ]; then
        cidr_prefix=$(netmask_to_prefix "$this_mask")
      fi
      export this_ip="      addresses: [\"$this_addr/$cidr_prefix\"]"
      if [ ! "$this_gw" = 'null' ]; then
        export this_gateway="      routes:
        - to: default
          via: $this_gw"
      fi
      envsubst < $KUBASH_DIR/templates/netplan-static.yaml \
      > $configure_static_network_addresses_tmp/kubash_interface
    else
      if [ ! "$this_addr" = 'null' ]; then
        export this_ip="address $this_addr"
      fi
      if [ ! "$this_mask" = 'null' ]; then
        export this_netmask="netmask $this_mask"
      fi
      if [ ! "$this_prefix_addr" = 'null' ]; then
        export this_network="network $this_prefix_addr"
      fi
      if [ ! "$this_bcast" = 'null' ]; then
        export this_broadcast="broadcast $this_bcast"
      fi
      if [ ! "$this_gw" = 'null' ]; then
        export this_gateway="gateway $this_gw"
      fi
      envsubst < $KUBASH_DIR/templates/debian-static.interface \
      > $configure_static_network_addresses_tmp/kubash_interface
    fi
  fi
  rsync $KUBASH_RSYNC_OPTS "ssh -p $K8S_sshPort" \
    $configure_static_network_addresses_tmp/kubash_interface \
    $K8S_SU_USER@$K8S_ip1:/tmp/kubash_interface-$this_iface.cfg
  if [ "$use_netplan" = 'true' ]; then
    command2run="mv -v /tmp/kubash_interface-$this_iface.cfg /etc/netplan/60-kubash-$this_iface.yaml && chmod 600 /etc/netplan/60-kubash-$this_iface.yaml"
    sudo_command $K8S_sshPort $K8S_SU_USER $K8S_ip1 "$command2run"
    command2run="netplan apply"
    sudo_command $K8S_sshPort $K8S_SU_USER $K8S_ip1 "$command2run"
  else
    command2run="mv -v /tmp/kubash_interface-$this_iface.cfg /etc/network/interfaces.d/kubash_interface-$this_iface.cfg"
    sudo_command $K8S_sshPort $K8S_SU_USER $K8S_ip1 "$command2run"
    command2run="ifup $this_iface"
    sudo_command $K8S_sshPort $K8S_SU_USER $K8S_ip1 "$command2run"
  fi
}

configure_secondary_network_interfaces () {
  squawk 1 "configure_secondary_network_interfaces"
  slurpy="$(grep -v '^#' $KUBASH_HOSTS_CSV)"
  squawk 8 "$slurpy"
  configure_static_network_addresses_tmp=$(mktemp -d)
  set_csv_columns
  while IFS="," read -r $csv_columns
  do
    squawk 7 "OS is $K8S_os"
    # Ubuntu (and noble, its codename) configures networking with
    # netplan; Debian (and trixie) with ifupdown.
    if [[ $K8S_os =~ ubuntu || $K8S_os =~ noble ]]; then
      use_netplan=true
    elif [[ $K8S_os =~ debian || $K8S_os =~ trixie ]]; then
      use_netplan=false
    else
      squawk 1 "OS not supported by network configurator"
      continue
    fi
    if [ "$K8S_network2" = 'null' ]; then
      squawk 7 "K8S_network2 is null"
    else
      squawk 7 "K8S_network2 is $K8S_network2"
      configure_secondary_interface eth1 \
        "$K8S_ip2" "$K8S_subnetmask2" "$K8S_routingprefix2" \
        "$K8S_broadcast2" "$K8S_gateway2"
    fi
    if [ "$K8S_network3" = 'null' ]; then
      squawk 7 "K8S_network3 is null"
    else
      squawk 7 "K8S_network3 is $K8S_network3"
      configure_secondary_interface eth2 \
        "$K8S_ip3" "$K8S_subnetmask3" "$K8S_routingprefix3" \
        "$K8S_broadcast3" "$K8S_gateway3"
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
        this_node_ip=$($PSEUDO arp -n|grep -i $K8S_mac1|awk '{print $1}'|tail -n 1)
        while [[ -z "$this_node_ip" ]]; do
        squawk 2 "$PSEUDO nmap -p 22 $BROADCAST_TO_NETWORK"
        NMAP_OUTPUT=$($PSEUDO nmap -p 22 $BROADCAST_TO_NETWORK)
        squawk 1 "arp -n|grep -i $K8S_mac1|awk '{print \$1}'"
        this_node_ip=$($PSEUDO arp -n|grep -i $K8S_mac1|awk '{print $1}'|tail -n 1)
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

