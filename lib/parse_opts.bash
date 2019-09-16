#!/bin/bash

parse_opts () {
  # If cmd empty enter interactive session
  if [[ -z "$1" ]]; then
    kubash_interactive
    exit 0
  fi

  squawk 5 'parse opts'

  ORIGINAL_OPTS=$@
  # Execute getopt on the arguments passed to this program, identified by the special character $@
  short_opts="c:hvyn:"
  long_opts="version,oidc,clustername:,initializer:,csv:,help,yes,verbose,verbosity:,target-os:,target-build:,build-virt:,node-join-name:,node-join-user:,node-join-ip:,node-join-port:,node-join-role:,parallel:,builder:,debug,provisioner:"
  PARSED_OPTIONS=$(getopt --alternative -n "$0" -o "$short_opts" --long "$long_opts" -- "$@")

  #Bad arguments, something has gone wrong with the getopt command.
  if [[ $? -ne 0 ]];
  then
    horizontal_rule
    croak 3  'bad argruments'
  fi

  # A little magic, necessary when using getopt.
  eval set -- "$PARSED_OPTIONS"

  squawk 5 'loop through opts'

  opt_loop_count=1
  while true; do
    squawk 5 "$opt_loop_count $@"
    ((++opt_loop_count))
    case "$1" in
      -h|--help)
        print_help=true
        shift;;
      --debug)
        debug=true
        shift;;
      --version)
        echo "Kubash, version $KUBASH_VERSION"
        exit 0
        shift;;
      -y|--yes)
        ANSWER_YES=yes
        shift;;
      -n|--clustername)
        set_name "$2"
        shift 2 ;;
      -c|--csv)
        KUBASH_HOSTS_CSV="$2"
        RAISON=true
        shift 2 ;;
      --provisioner)
        provisioner="$2"
        shift 2 ;;
      --initializer)
        initializer="$2"
        shift 2 ;;
      --parallel)
        PARALLEL_JOBS="$2"
        shift 2 ;;
      --node-join-name)
        node_join_name="$2"
        shift 2 ;;
      --node-join-user)
        node_join_user="$2"
        shift 2 ;;
      --node-join-ip)
        node_join_ip="$2"
        shift 2 ;;
      --node-join-port)
        node_join_port="$2"
        shift 2 ;;
      --node-join-role)
        node_join_role="$2"
        shift 2 ;;
      --target-os)
        target_os="$2"
        shift 2 ;;
      --target-build)
        target_build="$2"
        shift 2 ;;
      --build-virt)
        build_virt="$2"
        shift 2 ;;
      -v|--verbose)
        increase_verbosity
        shift;;
      --verbosity)
        set_verbosity $2
        shift 2 ;;
      --oidc)
        KUBASH_OIDC_AUTH=true
        squawk 2 "OIDC Auth turned on"
        shift;;
      --builder)
        builder=$2
        shift 2 ;;
      --)
        shift
        break;;
    esac
  done

  if [[ $VERBOSITY -gt '1' ]]; then
    KUBASH_RSYNC_OPTS='-H -azve'
    if [[ "$ANSWER_YES" == "yes" ]]; then
      MV_CMD='mv -v'
      CP_CMD='cp -v'
    else
      MV_CMD='mv -iv'
      CP_CMD='cp -iv'
    fi
  else
    if [[ "$ANSWER_YES" == "yes" ]]; then
      MV_CMD='mv'
      CP_CMD='cp'
    else
      MV_CMD='mv -i'
      CP_CMD='cp -i'
    fi
  fi

  chkdir $KUBASH_CLUSTERS_DIR

  squawk 7 "Check args"

  if [[ $# -eq 0 ]]; then
    kubash_interactive
  fi
  RAISON=$1
  squawk 5 "Raison set to $RAISON"
  shift


  if [[ $RAISON = "false" || "$RAISON" = "help" ]]; then
    horizontal_rule
    usage
    exit 1
  fi

  if [[ $RAISON == "auto" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    squawk 1 "Full auto engaged"
    kubash provision \
      -n $KUBASH_CLUSTER_NAME
    kubash ping \
      -n $KUBASH_CLUSTER_NAME
    kubash configure_interfaces \
      -n $KUBASH_CLUSTER_NAME
    kubash init \
      -n $KUBASH_CLUSTER_NAME
    sleep 10
    kubash openebs \
      -n $KUBASH_CLUSTER_NAME
    sleep 10
    kubash dashboard \
      -n $KUBASH_CLUSTER_NAME
    kubash voyager \
      -n $KUBASH_CLUSTER_NAME
    kubash searchlight \
      -n $KUBASH_CLUSTER_NAME
    sleep 10
    kubash tiller  \
      -n $KUBASH_CLUSTER_NAME
    squawk 1 "Full auto finished"
    exit 0
  elif [[ $RAISON == "grab" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
        do_grab
  elif [[ $RAISON == "grant" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    if [[ $# -eq 0 ]]; then
      grant_users
    elif [[ $# -eq 2 ]]; then
      grant $1 $2
    else
      horizontal_rule
      usage
      exit 1
    fi
    exit 0
  elif [[ $RAISON == "istio" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
        do_istio
  elif [[ $RAISON == "metallb" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
        do_metallb
  elif [[ $RAISON == "minio" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
        do_minio
  elif [[ $RAISON == "scan" ]]; then
        scanlooper
  elif [[ $RAISON == "efk" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
        do_efk
  elif [[ $RAISON == "rook" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
        do_rook
  elif [[ $RAISON == "openebs" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    do_openebs
  elif [[ $RAISON == "genmac" ]]; then
    genmac
  elif [[ $RAISON == "dry" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    ((++VERBOSITY))
    do_test
  elif [[ $RAISON == "test_provision" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    ((++VERBOSITY))
    do_provision_test
  elif [[ $RAISON == "mount_iscsi" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
      mount_all_iscsi_targets
  elif [[ $RAISON == "hosts" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    write_ansible_hosts
    exit 0
  elif [[ $RAISON == "dotfiles" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    squawk 5 'Adjusting dotfiles'
    dotfiles_install
    exit 0
  elif [[ $RAISON == "show" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    let VERBOSITY=VERBOSITY+10
    read_csv
  elif [[ $RAISON == "read_provision_csv" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    let VERBOSITY=VERBOSITY+10
    read_provision_csv
  elif [[ $RAISON == "test" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    let VERBOSITY=VERBOSITY+10
    do_test
  elif [[ $RAISON == "ping" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    if [[ "$PARALLEL_JOBS" -gt "1" ]] ; then
    ping_in_parallel
    else
      ping
    fi
  elif [[ $RAISON == "aping" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    write_ansible_hosts
    ansible-ping
  elif [[ $RAISON == "monitoring" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    activate_monitoring
  elif [[ $RAISON == "prep" ]]; then
    prep
  elif [[ $RAISON == "provision" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      provision_usage
      exit 1
    fi
    if [ "$provisioner" = 'gke' ]; then
      gke-provisioner $@
    else
      copy_image_to_all_provisioning_hosts
      provisioner
      squawk 1 "waiting on hosts to come up"
      sleep 33
      refresh_network_addresses
      prep
      remove_vagrant_user
      hostname_in_parallel
      copy_known_hosts
      ntpsync_in_parallel
    fi
  elif [[ $RAISON == "hostnamer" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    hostname_in_parallel
  elif [[ $RAISON == "decommission" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      decom_usage
      exit 1
    fi
    do_decom
  elif [[ $RAISON == "demo" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    demo
  elif [[ $RAISON == "ingress" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    do_nginx_ingress $KUBASH_INGRESS_NAME
  elif [[ $RAISON == "interactive" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    kubash_interactive $@
  elif [[ $RAISON == "masters" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      init_usage
      exit 1
    fi
    DO_MASTER_JOIN=true
    initialize
    do_grab
  elif [[ $RAISON == "minit" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      init_usage
      exit 1
    fi
    DO_MASTER_JOIN=false
    DO_NODE_JOIN=false
    initialize
  elif [[ $RAISON == "nodes" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      init_usage
      exit 1
    fi
    DO_NODE_JOIN=true
    initialize
    do_grab
  elif [[ $RAISON == "init" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      init_usage
      exit 1
    fi
    if [[ -z "$initializer" ]]; then
      initializer=kubeadm
      DO_NODE_JOIN=true
      DO_MASTER_JOIN=true
      kubeadm_reset
      copy_known_hosts
      squawk 5 "Initialize"
      initialize
      do_grab
      ping
      exit 0
    elif [[ "$initializer" == "kubespray" ]]; then
      squawk 5 "Kubespray Initialize"
      kubespray_initialize
      exit 0
    elif [[ "$initializer" == "openshift" ]]; then
      squawk 5 "Openshift Initialize"
      openshift_initialize
      exit 0
    elif [[ "$initializer" == "kubeadm2ha" ]]; then
      squawk 5 "Kubeadm2ha Initialize"
      kubeadm2ha_initialize
      exit 0
    fi
  elif [[ $RAISON == "extras" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      init_usage
      exit 1
    fi
    do_tiller
  elif [[ $RAISON == "yaml2cluster" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    yaml2cluster $@
  elif [[ $RAISON == "json2cluster" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    json2cluster $@
  elif [[ $RAISON == "searchlight" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    do_searchlight
  elif [[ $RAISON == "taint_ingress" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    taint_all_ingress $@
  elif [[ $RAISON == "mark_ingress" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    mark_all_ingress $@
  elif [[ $RAISON == "dashboard" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    do_dashboard
  elif [[ $RAISON == "kafka" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    do_kafka
  elif [[ $RAISON == "redis" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    do_redis
  elif [[ $RAISON == "postgres" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
  do_postgres
  elif [[ $RAISON == "rabbitmq" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
  do_rabbitmq
  elif [[ $RAISON == "percona" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
  do_percona
  elif [[ $RAISON == "jupyter" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
  do_jupyter
  elif [[ $RAISON == "mongodb" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
  do_mongodb
  elif [[ $RAISON == "jenkins" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
  do_jenkins
  elif [[ $RAISON == "voyager" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    do_voyager
  elif [[ $RAISON == "configure_interfaces" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    configure_secondary_network_interfaces
  elif [[ $RAISON == "traefik" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    do_traefik
  elif [[ $RAISON == "linkerd" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    do_linkerd
  elif [[ $RAISON == "kubedb" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    inst_kubedb_helm
  elif [[ $RAISON == "tiller" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    do_tiller
  elif [[ $RAISON == "refresh" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    refresh_network_addresses
  elif [[ $RAISON == "armor_fix" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    apparmor_fix_all_provisioning_hosts
  elif [[ $RAISON == "known_hosts" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    copy_known_hosts $@
  elif [[ $RAISON == "prepetcd" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    prep_etcd $@
  elif [[ $RAISON == "copy" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    copy_image_to_all_provisioning_hosts
  elif [[ $RAISON == "reset" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    kubeadm_reset
  elif [[ $RAISON == "build-all" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    build_all_in_parallel
  elif [[ $RAISON == "etcd_ext" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    if [[ "$MASTERS_AS_ETCD" == "true" ]]; then
      etcd_kubernetes_docs_stacked_method
    else
      etcd_kubernetes_ext_etcd_method
    fi
  elif [[ $RAISON == "do_net" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    do_net
  elif [[ $RAISON == "build" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      build_usage
      exit 1
    fi
    if [[ -z "$builder" ]]; then
      builder='packer'
    fi
    if [[ -z "$target_os" ]]; then
      target_os=kubeadm
      if [[ -z "$target_build" ]]; then
        target_build=kubeadm-7.4-x86_64
      fi
      build_usage
      croak 3  'support removed request repair :('
    elif [[ "$target_os" == "centos" ]]; then
      if [[ -z "$target_build" ]]; then
        target_build=centos-7.4-x86_64
      fi
      build_usage
      croak 3  'support removed request repair :('
    elif [[ "$target_os" == "openshift" ]]; then
      if [[ -z "$target_build" ]]; then
        target_build=openshift-7.5-x86_64
      fi
      build_usage
      croak 3  'support removed request repair :('
    elif [[ "$target_os" == "kubespray" ]]; then
      if [[ -z "$target_build" ]]; then
        target_build=kubespray-7.5-x86_64
      fi
      build_usage
      croak 3  'support removed request repair :('
    elif [[ "$target_os" == "kubeadm2ha" ]]; then
      if [[ -z "$target_build" ]]; then
        target_build=kubeadm2ha-7.4-x86_64
      fi
      build_usage
      croak 3  'support removed request repair :('
    elif [[ "$target_os" == "kubeadm" ]]; then
      if [[ -z "$target_build" ]]; then
        target_build=kubeadm-7.4-x86_64
      fi
      build_usage
      croak 3  'support removed request repair :('
    elif [[ "$target_os" == "fedora" ]]; then
      if [[ -z "$target_build" ]]; then
        target_build=fedora-27-x86_64
      fi
      build_usage
      croak 3  'support removed request repair :('
    elif [[ "$target_os" =~ 'centos7' ]]; then
      if [[ -z "$target_build" ]]; then
        echo "matching $target_os"
        build_num=$(echo $target_os | sed 's/centos7//')
        target_build=centos7$build_num
        packer_create_pax_dir 'centos7' $build_num
      fi
    elif [[ "$target_os" =~ 'stretch' ]]; then
      if [[ -z "$target_build" ]]; then
        echo "matching $target_os"
        build_num=$(echo $target_os | sed 's/stretch//')
        target_build=stretch$build_num
        packer_create_pax_dir 'stretch' $build_num
      fi
    elif [[ "$target_os" =~ 'bionic' ]]; then
      if [[ -z "$target_build" ]]; then
        echo "matching $target_os"
        build_num=$(echo $target_os | sed 's/bionic//')
        target_build=bionic$build_num-18.04-amd64
        packer_create_pax_dir 'bionic' $build_num
      fi
    elif [[ "$target_os" =~ 'buster' ]]; then
      if [[ -z "$target_build" ]]; then
        echo "matching $target_os"
        build_num=$(echo $target_os | sed 's/buster//')
        target_build=buster$build_num
        packer_create_pax_dir 'buster' $build_num
      fi
    elif [[ "$target_os" =~ 'ubuntu' ]]; then
      if [[ -z "$target_build" ]]; then
        echo "matching $target_os"
        build_num=$(echo $target_os | sed 's/ubuntu//')
        target_build=ubuntu$build_num-16.04-amd64
        packer_create_pax_dir 'ubuntu' $build_num
      fi
    elif [[ "$target_os" =~ 'xenial' ]]; then
      if [[ -z "$target_build" ]]; then
        echo "matching $target_os"
        build_num=$(echo $target_os | sed 's/xenial//')
        target_build=xenial$build_num-16.04-amd64
        packer_create_pax_dir 'xenial' $build_num
      fi
    elif [[ "$target_os" == "coreos" ]]; then
      #override packer atm
      builder=coreos
      if [[ $builder == "packer" ]]; then
        croak 3  'packer not supported for coreos at this time'
      elif [[ $builder == "coreos" ]]; then
        if [[ -z "$target_build" ]]; then
          squawk 5 "Setting coreos channel to stable"
          target_build=stable
        fi
      fi
    fi
    if [[ -z "$target_build" ]]; then
      target_build=ubuntu-16.04-amd64
    fi
    #build_usage
    if [[ -z "$build_virt" ]]; then
      build_virt=qemu
    fi
    if [[ $builder == "packer" ]]; then
      squawk 5 "packer_build $build_virt $target_os $target_build"
      packer_build $build_virt $target_os $target_build $build_num
    elif [[ $builder == "coreos" ]]; then
      squawk 5 "coreos_build $build_virt $target_os $target_build"
      coreos_build $build_virt $target_os $target_build
    elif [[ $builder == "veewee" ]]; then
      squawk 2 " Executing vee wee build..."
      # veewee_build
      croak 3  'VeeWee support not built yet :('
    else
      croak 3  'builder not recognized'
    fi
    exit 0
  elif [[ $RAISON == "node_join" ]]; then
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      node_usage
      exit 1
    fi
    if [[ -z "$node_join_name" ]]; then
      croak 3  'you must specify the --node-join-name option'
    fi
    if [[ -z "$node_join_ip" ]]; then
      croak 3  'you must specify the --node-join-ip option'
    fi
    if [[ -z "$node_join_user" ]]; then
      croak 3  'you must specify the --node-join-user option'
    fi
    if [[ -z "$node_join_port" ]]; then
      croak 3  'you must specify the --node-join-port option'
    fi
    if [[ -z "$node_join_role" ]]; then
      croak 3  'you must specify the --node-join-role option'
    fi
    if [[ $node_join_role == "node" ]]; then
      squawk 2 " Executing node join..."
      DO_NODE_JOIN=true
      node_join $node_join_name $node_join_ip $node_join_user $node_join_port
    elif [[ $node_join_role == "master" ]]; then
      squawk 2 " Executing master join..."
      DO_MASTER_JOIN=true
      master_join $node_join_name $node_join_ip $node_join_user $node_join_port
    fi
    exit 0
  else
    squawk 8 'passthru'
    # Else fall through to passing on to kubectl for the current cluster
    if [[ $print_help == "true" ]]; then
      horizontal_rule
      usage
      exit 1
    fi
    squawk 5 "kubectl -n $KUBASH_CLUSTER_NAME --kubeconfig=$KUBASH_CLUSTER_DIR/config $RAISON $@"
    kubectl -n $KUBASH_CLUSTER_NAME --kubeconfig=$KUBASH_CLUSTER_DIR/config $RAISON $@
  fi

  if [[ $print_help == "true" ]]; then
    horizontal_rule
    usage
    exit 1
  fi
}
