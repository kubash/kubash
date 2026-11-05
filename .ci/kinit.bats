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

@test "get_major_minor_kube_version parses kubeadm -o short on 1.35-1.37" {
  eval "$(sed -n '/^get_major_minor_kube_version ()/,/^}/p' "$KUBASH_ROOT/lib/utils.bash")"
  squawk() { :; }
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat > "$BATS_TEST_TMPDIR/bin/ssh" <<'EOF'
#!/bin/bash
echo "$KUBEADM_SHORT"
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/ssh"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  # The old parse required Major/Minor/GitVersion adjacency in the
  # full version struct, which 1.35+ output no longer has (it
  # inserts Emulation/MinCompatibility fields); -o short is stable.
  for v in 1.35.9 1.36.5 1.37.1; do
    export KUBEADM_SHORT="v$v"
    get_major_minor_kube_version user host name 22
    # No set +e here on purpose: the function ends with set -e,
    # and with errexit off a failing assertion below would pass
    # vacuously in bats. A failure must abort the test.
    [ "$KUBE_MAJOR_VER" = "1" ]
    [ "$KUBE_MINOR_VER" = "$(echo "$v" | cut -d. -f2)" ]
  done
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

@test "external etcd method passes -p on every ssh call (K-F5)" {
  awk '/^etcd_kubernetes_13_ext_etcd_method \(\)/,/^}/' \
    "$KUBASH_ROOT/lib/kinit.bash" > "$BATS_TEST_TMPDIR/ext-method.inc"
  [ -s "$BATS_TEST_TMPDIR/ext-method.inc" ]
  # Real ssh invocations only (squawk log lines excluded): every one
  # must carry an explicit -p, since etcd/master hosts may listen on
  # a non-22 sshPort and the bare form silently uses port 22.
  # (grep -c exits 1 on a zero count, so `|| true` keeps the
  # assignment itself from failing; the assertions below decide.)
  bare_count=$(grep -E '(^|[|]) *ssh ' "$BATS_TEST_TMPDIR/ext-method.inc" \
    | grep -v 'squawk' | grep -vc -- '-p' || true)
  [ "$bare_count" -eq 0 ]
  # Each host kind uses its own port array (command lines only).
  etcd_ports=$(grep -E '(^|[|]) *ssh ' "$BATS_TEST_TMPDIR/ext-method.inc" \
    | grep -v 'squawk' | grep -c 'ssh -p ${ETCDPORTS\[$i\]}' || true)
  [ "$etcd_ports" -eq 2 ]
  master_ports=$(grep -E '(^|[|]) *ssh ' "$BATS_TEST_TMPDIR/ext-method.inc" \
    | grep -v 'squawk' | grep -c 'ssh -p ${MASTERPORTS\[$i\]}' || true)
  [ "$master_ports" -eq 2 ]
  etcd0_ports=$(grep -E '(^|[|]) *ssh ' "$BATS_TEST_TMPDIR/ext-method.inc" \
    | grep -v 'squawk' | grep -c 'ssh -p ${ETCDPORTS\[0\]}' || true)
  [ "$etcd0_ports" -eq 3 ]
}

@test "kubeadm alpha phase is gone from kinit and kattic (K-F6)" {
  # `kubeadm alpha phase` is dead on 1.35-1.37: bare alpha prints only
  # the experimental-sub-commands banner and --config is an unknown
  # flag, so the cert/etcd steps it guarded silently did nothing.
  run grep -rn 'alpha phase' "$KUBASH_ROOT/lib/kinit.bash" "$KUBASH_ROOT/lib/kattic.bash"
  [ "$status" -eq 1 ]
  [ "$output" = "" ]
  run grep -c 'kubeadm init phase certs etcd-ca' "$KUBASH_ROOT/lib/kinit.bash"
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
  run grep -c 'kubeadm init phase certs etcd-server' "$KUBASH_ROOT/lib/kinit.bash"
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
  run grep -c 'kubeadm init phase etcd local' "$KUBASH_ROOT/lib/kattic.bash"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}
