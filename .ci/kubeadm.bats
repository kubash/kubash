#!/usr/bin/env bats

# Validation for the kubeadm config templates added in Phase 2c.
# Renders each v1beta4 template the way lib/yaml.bash does (envsubst
# with a representative etcd fragment) and asks a real kubeadm to
# validate it. Skips when kubeadm is not on PATH; CI installs a
# pinned kubeadm into the kubash bin dir before running the suite.

setup() {
  KUBASH_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  cat > "$BATS_TEST_TMPDIR/stacked.frag" <<'EOF'
  local:
    serverCertSANs:
    - '10.0.0.11'
    peerCertSANs:
    - '10.0.0.11'
    extraArgs:
    - name: initial-cluster
      value: kubashnode1=https://10.0.0.11:2380
    - name: initial-cluster-state
      value: new
EOF
  cat > "$BATS_TEST_TMPDIR/external.frag" <<'EOF'
  external:
    endpoints:
    - https://10.0.0.21:2379
    caFile: /etc/kubernetes/pki/etcd/ca.crt
    certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
    keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key
EOF
}

patch_for() {
  case "$1" in
    1.35) echo v1.35.9 ;;
    1.36) echo v1.36.5 ;;
    1.37) echo v1.37.1 ;;
  esac
}

@test "kubeadm v1beta4 templates validate with a real kubeadm" {
  if ! command -v kubeadm >/dev/null 2>&1; then
    skip "kubeadm not on PATH"
  fi
  for v in 1.35 1.36 1.37; do
    for kind in stacked external; do
      if [ "$kind" = stacked ]; then
        frag="$BATS_TEST_TMPDIR/stacked.frag"
        tpl="$KUBASH_ROOT/templates/kubeadm-config-$v.yaml"
      else
        frag="$BATS_TEST_TMPDIR/external.frag"
        tpl="$KUBASH_ROOT/templates/kubeadm-config-external-$v.yaml"
      fi
      my_master_ip=10.0.0.11 \
      load_balancer_ip=10.0.0.10 \
      my_KUBE_CIDR=10.244.0.0/16 \
      KUBERNETES_VERSION="$(patch_for $v)" \
      ENDPOINTS_LINES="$(cat "$frag")" \
        envsubst < "$tpl" > "$BATS_TEST_TMPDIR/rendered-$v-$kind.yaml"
      run kubeadm config validate --config "$BATS_TEST_TMPDIR/rendered-$v-$kind.yaml"
      [ "$status" -eq 0 ]
    done
  done
}

@test "determine_api_version maps minor 31+ to v1beta4" {
  awk '/^determine_api_version \(\)/,/^}/' \
    "$KUBASH_ROOT/lib/kinit.bash" > "$BATS_TEST_TMPDIR/determine.inc"
  [ -s "$BATS_TEST_TMPDIR/determine.inc" ]
  cat > "$BATS_TEST_TMPDIR/run-mapping.bash" <<'EOF'
#!/usr/bin/env bash
squawk () { :; }
croak () { exit "${1:-3}"; }
source "$1"
KUBE_MAJOR_VER=1 KUBE_MINOR_VER="$2" determine_api_version >/dev/null 2>&1
echo "$kubeadm_apiVersion"
EOF
  run bash "$BATS_TEST_TMPDIR/run-mapping.bash" "$BATS_TEST_TMPDIR/determine.inc" 36
  [ "$output" = "kubeadm.k8s.io/v1beta4" ]
  run bash "$BATS_TEST_TMPDIR/run-mapping.bash" "$BATS_TEST_TMPDIR/determine.inc" 30
  [ "$output" = "kubeadm.k8s.io/v1beta3" ]
  run bash "$BATS_TEST_TMPDIR/run-mapping.bash" "$BATS_TEST_TMPDIR/determine.inc" 20
  [ "$output" = "kubeadm.k8s.io/v1beta2" ]
}
