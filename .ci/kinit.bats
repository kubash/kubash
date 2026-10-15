#!/usr/bin/env bats

# Pins the kubeadm-config emission of lib/kinit.bash after the
# Phase 4h prune (Kubernetes floor 1.35): the etcd extraArgs and
# apiServer certSANs helpers emit only the v1beta4 forms modern
# kubeadm accepts, and determine_api_version refuses pre-1.35
# minors outright.

setup() {
  KUBASH_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  eval "$(sed -n '/^kinit_etcd_arg_lines()/,/^}/p' "$KUBASH_ROOT/lib/kinit.bash")"
  eval "$(sed -n '/^kinit_api_server_cert_sans_block()/,/^}/p' "$KUBASH_ROOT/lib/kinit.bash")"
}

@test "kinit_etcd_arg_lines emits the v1beta4 list style" {
  run kinit_etcd_arg_lines listen-peer-urls 'https://10.0.0.9:2380'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = '            - name: listen-peer-urls' ]
  [ "${lines[1]}" = '              value: https://10.0.0.9:2380' ]
}

@test "kinit_etcd_arg_lines preserves quoted values" {
  run kinit_etcd_arg_lines advertise-client-urls '"https://10.0.0.9:2379"'
  [ "${lines[0]}" = '            - name: advertise-client-urls' ]
  [ "${lines[1]}" = '              value: "https://10.0.0.9:2379"' ]
}

@test "kinit_api_server_cert_sans_block emits the nested form" {
  run kinit_api_server_cert_sans_block '- "10.0.0.11"'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'apiServer:' ]
  [ "${lines[1]}" = '  certSANs:' ]
  [ "${lines[2]}" = '  - "127.0.0.1"' ]
  [ "${lines[3]}" = '  - "10.0.0.11"' ]
}

@test "kinit_api_server_cert_sans_block with no extra entries" {
  run kinit_api_server_cert_sans_block ''
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'apiServer:' ]
  [ "${lines[1]}" = '  certSANs:' ]
  [ "${lines[2]}" = '  - "127.0.0.1"' ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "determine_api_version refuses Kubernetes older than 1.35" {
  eval "$(sed -n '/^determine_api_version ()/,/^}/p' "$KUBASH_ROOT/lib/kinit.bash")"
  # stubs: only determine_api_version's branching is under test
  squawk() { :; }
  croak() { echo "croaked: $*" >&2; exit 1; }
  KUBE_MAJOR_VER=1
  KUBE_MINOR_VER=34
  run determine_api_version
  [ "$status" -eq 1 ]
  [[ "$output" == *'34 is too old'* ]]
}

@test "determine_api_version maps 1.35 and later to v1beta4" {
  eval "$(sed -n '/^determine_api_version ()/,/^}/p' "$KUBASH_ROOT/lib/kinit.bash")"
  squawk() { :; }
  croak() { echo "croaked: $*" >&2; exit 1; }
  KUBE_MAJOR_VER=1
  KUBE_MINOR_VER=35
  run determine_api_version
  [ "$status" -eq 0 ]
  KUBE_MINOR_VER=37
  determine_api_version
  [ "$kubeadm_apiVersion" = 'kubeadm.k8s.io/v1beta4' ]
  [ "$kubeadm_cfg_kind" = 'ClusterConfiguration' ]
}
