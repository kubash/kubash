#!/usr/bin/env bats

# Pins the etcd extraArgs emission styles of
# lib/kinit.bash:kinit_etcd_arg_lines (Phase 3d). The kinit heredocs
# splice this helper's output into the kubeadm configs they write:
# map style before v1beta4, name/value list style from v1beta4 on.

setup() {
  KUBASH_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  eval "$(sed -n '/^kinit_etcd_arg_lines()/,/^}/p' "$KUBASH_ROOT/lib/kinit.bash")"
}

@test "kinit_etcd_arg_lines map style before v1beta4" {
  kubeadm_apiVersion='kubeadm.k8s.io/v1beta3'
  run kinit_etcd_arg_lines listen-peer-urls 'https://10.0.0.9:2380'
  [ "$status" -eq 0 ]
  [ "$output" = '            listen-peer-urls: https://10.0.0.9:2380' ]
}

@test "kinit_etcd_arg_lines list style for v1beta4" {
  kubeadm_apiVersion='kubeadm.k8s.io/v1beta4'
  run kinit_etcd_arg_lines listen-peer-urls 'https://10.0.0.9:2380'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = '            - name: listen-peer-urls' ]
  [ "${lines[1]}" = '              value: https://10.0.0.9:2380' ]
}

@test "kinit_api_server_cert_sans_block top-level form before v1beta2" {
  eval "$(sed -n '/^kinit_api_server_cert_sans_block()/,/^}/p' "$KUBASH_ROOT/lib/kinit.bash")"
  kubeadm_apiVersion='kubeadm.k8s.io/v1beta1'
  run kinit_api_server_cert_sans_block '- "10.0.0.11"'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'apiServerCertSANs:' ]
  [ "${lines[1]}" = '- "127.0.0.1"' ]
  [ "${lines[2]}" = '- "10.0.0.11"' ]
}

@test "kinit_api_server_cert_sans_block nested form from v1beta2 on" {
  eval "$(sed -n '/^kinit_api_server_cert_sans_block()/,/^}/p' "$KUBASH_ROOT/lib/kinit.bash")"
  kubeadm_apiVersion='kubeadm.k8s.io/v1beta2'
  run kinit_api_server_cert_sans_block '- "10.0.0.11"'
  [ "${lines[0]}" = 'apiServer:' ]
  [ "${lines[1]}" = '  certSANs:' ]
  [ "${lines[2]}" = '  - "127.0.0.1"' ]
  [ "${lines[3]}" = '  - "10.0.0.11"' ]
  kubeadm_apiVersion='kubeadm.k8s.io/v1beta4'
  run kinit_api_server_cert_sans_block '- "10.0.0.11"'
  [ "${lines[0]}" = 'apiServer:' ]
  [ "${lines[1]}" = '  certSANs:' ]
}

@test "kinit_etcd_arg_lines preserves quoted values" {
  kubeadm_apiVersion='kubeadm.k8s.io/v1beta3'
  run kinit_etcd_arg_lines advertise-client-urls '"https://10.0.0.9:2379"'
  [ "$output" = '            advertise-client-urls: "https://10.0.0.9:2379"' ]
  kubeadm_apiVersion='kubeadm.k8s.io/v1beta4'
  run kinit_etcd_arg_lines advertise-client-urls '"https://10.0.0.9:2379"'
  [ "${lines[1]}" = '              value: "https://10.0.0.9:2379"' ]
}
