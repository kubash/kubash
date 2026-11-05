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

@test "etcd_extra_arg emits the v1beta4 list style" {
  awk '/^etcd_extra_arg \(\)/,/^}/' \
    "$KUBASH_ROOT/lib/yaml.bash" > "$BATS_TEST_TMPDIR/extraarg.inc"
  [ -s "$BATS_TEST_TMPDIR/extraarg.inc" ]
  cat > "$BATS_TEST_TMPDIR/run-extraarg.bash" <<'EOF'
#!/usr/bin/env bash
TAB_2='    '
TAB_3='      '
source "$1"
etcd_extra_arg "$2" initial-cluster-state new
EOF
  run bash "$BATS_TEST_TMPDIR/run-extraarg.bash" "$BATS_TEST_TMPDIR/extraarg.inc" "$BATS_TEST_TMPDIR/list.out"
  [ "$output" = "" ]
  run cat "$BATS_TEST_TMPDIR/list.out"
  [ "$output" = "    - name: initial-cluster-state
      value: new" ]
}

@test "determine_api_version maps 1.35+ to v1beta4 and refuses older" {
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
  run bash "$BATS_TEST_TMPDIR/run-mapping.bash" "$BATS_TEST_TMPDIR/determine.inc" 35
  [ "$output" = "kubeadm.k8s.io/v1beta4" ]
  run bash "$BATS_TEST_TMPDIR/run-mapping.bash" "$BATS_TEST_TMPDIR/determine.inc" 34
  [ "$status" -eq 3 ]
  [ "$output" = "" ]
}

# One 6.0.0 CSV row: $1 node $2 role $3 sshPort $4 ip1; the other
# 56 columns are empty.
csv_row() {
  local row="$1,$2,2,4096,$3,net1,aa:bb:cc:dd:ee:01,$4"
  row+=$(printf ',%.0s' $(seq 1 56))
  printf '%s\n' "$row"
}

# Writes $BATS_TEST_TMPDIR/run-write.bash: a runner that executes the
# real write_kubeadmcfg_yaml from lib/yaml.bash with the network and
# remote-execution calls stubbed out, and copies the emitted fragments
# and rendered configs to its $4 out dir. Usage inside a test:
#   write_kubeadmcfg_runner
#   run bash "$BATS_TEST_TMPDIR/run-write.bash" \
#     "$KUBASH_ROOT" "$BATS_TEST_TMPDIR/cluster" \
#     "$BATS_TEST_TMPDIR/hosts.csv" "$BATS_TEST_TMPDIR/out"
write_kubeadmcfg_runner() {
  cat > "$BATS_TEST_TMPDIR/run-write.bash" <<'EOF'
#!/usr/bin/env bash
set -e
KUBASH_ROOT="$1"
KUBASH_CLUSTER_DIR="$2"
KUBASH_CSV="$3"
OUT_DIR="$4"
export KUBASH_DIR="$KUBASH_ROOT"
TAB_1='  '
TAB_2='    '
TAB_3='      '
TAB_4='        '
eval "$(sed -n '/^CSV_COLUMNS_6_0_0=/p' "$KUBASH_ROOT/lib/kvars.bash")"
squawk() { :; }
croak() { echo "croaked: $*" >&2; exit 1; }
hosts_csv_slurp() { :; }
get_major_minor_kube_version() { KUBE_MAJOR_VER=1; KUBE_MINOR_VER=37; }
sudo_command() { :; }
scp() { :; }
prep_20-etcd-service-manager() { :; }
eval "$(awk '/^etcd_extra_arg \(\)/,/^}/' "$KUBASH_ROOT/lib/yaml.bash")"
eval "$(awk '/^set_csv_columns \(\)/,/^}/' "$KUBASH_ROOT/lib/kcsv.bash")"
eval "$(awk '/^set_ip_files \(\)/,/^}/' "$KUBASH_ROOT/lib/utils.bash")"
eval "$(awk '/^write_kubeadmcfg_yaml \(\)/,/^}/' "$KUBASH_ROOT/lib/yaml.bash")"
kubash_hosts_csv_slurped="$(cat "$KUBASH_CSV")"
KUBASH_CSV_VER_FILE="$KUBASH_CLUSTER_DIR/csv_ver"
MASTERS_AS_ETCD=false
my_KUBE_CIDR=10.244.0.0/16
write_kubeadmcfg_yaml
cp "$do_etcd_tmp_para/servercertsans.line" "$OUT_DIR/"
cp "$do_etcd_tmp_para/peercertsans.line" "$OUT_DIR/"
cp "$do_etcd_tmp_para/external-endpoints.line" "$OUT_DIR/"
cp "$do_etcd_tmp_para/"*-external-kubeadmcfg.yaml "$OUT_DIR/"
cp "$do_etcd_tmp_para/"*kubeadmcfg.yaml "$OUT_DIR/"
EOF
}

# Single primary master, dedicated etcd tier (no plain master): the
# shape that exercises both the primary_etcd SAN/endpoints loops and
# the kube_master1 fallback.
single_primary_cluster() {
  {
    csv_row pe1 primary_etcd 2222 10.0.0.21
    csv_row et1 etcd 2222 10.0.0.22
    csv_row et2 etcd 2222 10.0.0.23
    csv_row pm1 primary_master 2222 10.0.0.11
    csv_row node1 node 2222 10.0.0.31
  } > "$BATS_TEST_TMPDIR/hosts.csv"
  mkdir -p "$BATS_TEST_TMPDIR/cluster"
  printf 'v1.37.1\n' > "$BATS_TEST_TMPDIR/cluster/kubernetes_version"
  printf '6.0.0\n' > "$BATS_TEST_TMPDIR/cluster/csv_ver"
  mkdir -p "$BATS_TEST_TMPDIR/out"
}

@test "write_kubeadmcfg_yaml includes primary_etcd in SANs and endpoints (K-F3)" {
  if [ -d "$HOME/scratch/bin" ]; then
    PATH="$HOME/scratch/bin:$PATH"
    export PATH
  fi
  # Single primary master, dedicated etcd tier (no plain master):
  # pe1 is the primary etcd node and must appear everywhere the
  # other etcd members do.
  single_primary_cluster
  write_kubeadmcfg_runner
  run bash "$BATS_TEST_TMPDIR/run-write.bash" \
    "$KUBASH_ROOT" "$BATS_TEST_TMPDIR/cluster" \
    "$BATS_TEST_TMPDIR/hosts.csv" "$BATS_TEST_TMPDIR/out"
  [ "$status" -eq 0 ]
  # primary_etcd (.21) in the SAN lists and the external endpoints,
  # alongside the plain etcd members (.22/.23).
  run grep -F "10.0.0.21" "$BATS_TEST_TMPDIR/out/servercertsans.line"
  [ "$status" -eq 0 ]
  run grep -F "10.0.0.21" "$BATS_TEST_TMPDIR/out/peercertsans.line"
  [ "$status" -eq 0 ]
  run grep -F "https://10.0.0.21:2379" "$BATS_TEST_TMPDIR/out/external-endpoints.line"
  [ "$status" -eq 0 ]
  # The other members are still there (no regression in the loops).
  run grep -F "https://10.0.0.22:2379" "$BATS_TEST_TMPDIR/out/external-endpoints.line"
  [ "$status" -eq 0 ]
  run grep -F "https://10.0.0.23:2379" "$BATS_TEST_TMPDIR/out/external-endpoints.line"
  [ "$status" -eq 0 ]
}

@test "external master config falls back to kube_primary without kube_master1 (K-F4)" {
  if [ -d "$HOME/scratch/bin" ]; then
    PATH="$HOME/scratch/bin:$PATH"
    export PATH
  fi
  # Same single-primary-master CSV as the K-F3 test: set_ip_files
  # writes kube_primary but never kube_master1, so the external
  # render must use the primary as its control-plane endpoint.
  single_primary_cluster
  write_kubeadmcfg_runner
  run bash "$BATS_TEST_TMPDIR/run-write.bash" \
    "$KUBASH_ROOT" "$BATS_TEST_TMPDIR/cluster" \
    "$BATS_TEST_TMPDIR/hosts.csv" "$BATS_TEST_TMPDIR/out"
  [ "$status" -eq 0 ]
  [ -f "$BATS_TEST_TMPDIR/out/pm1-external-kubeadmcfg.yaml" ]
  run grep -F 'controlPlaneEndpoint: "10.0.0.11"' \
    "$BATS_TEST_TMPDIR/out/pm1-external-kubeadmcfg.yaml"
  [ "$status" -eq 0 ]
  run grep -F '"10.0.0.11"' "$BATS_TEST_TMPDIR/out/pm1-external-kubeadmcfg.yaml"
  [ "$status" -eq 0 ]
  # The fallback must not leave an empty endpoint or certSAN behind.
  run grep -F 'controlPlaneEndpoint: ""' \
    "$BATS_TEST_TMPDIR/out/pm1-external-kubeadmcfg.yaml"
  [ "$status" -eq 1 ]
  if command -v kubeadm >/dev/null 2>&1; then
    run kubeadm config validate --config \
      "$BATS_TEST_TMPDIR/out/pm1-external-kubeadmcfg.yaml"
    [ "$status" -eq 0 ]
  fi
}

@test "kubeadm init phase certs and etcd local work on 1.37.1 (K-F6)" {
  if [ -x "$HOME/scratch/kubeadm/kubeadm-v1.37.1" ]; then
    KUBEADM137="$HOME/scratch/kubeadm/kubeadm-v1.37.1"
  elif command -v kubeadm >/dev/null 2>&1; then
    KUBEADM137="$(command -v kubeadm)"
  else
    skip "no kubeadm 1.37.1 binary available"
  fi
  if [ -d "$HOME/scratch/bin" ]; then
    PATH="$HOME/scratch/bin:$PATH"
    export PATH
  fi
  # Render a stacked 1.37 config the way lib/yaml.bash does, with a
  # scratch certificatesDir so the phases mint real certs there.
  my_master_ip=10.0.0.11 \
  load_balancer_ip=10.0.0.10 \
  my_KUBE_CIDR=10.244.0.0/16 \
  KUBERNETES_VERSION=v1.37.1 \
  ENDPOINTS_LINES="$(printf '  local:\n    serverCertSANs:\n    - 10.0.0.21\n    peerCertSANs:\n    - 10.0.0.21\n    extraArgs:\n    - name: initial-cluster\n      value: pe1=https://10.0.0.21:2380\n    - name: initial-cluster-state\n      value: new\n')" \
    envsubst < "$KUBASH_ROOT/templates/kubeadm-config-1.37.yaml" \
    > "$BATS_TEST_TMPDIR/rendered-1.37.yaml"
  printf 'certificatesDir: %s\n' "$BATS_TEST_TMPDIR/pki" \
    >> "$BATS_TEST_TMPDIR/rendered-1.37.yaml"
  # The dead shape: alpha rejects --config outright.
  run "$KUBEADM137" alpha phase certs etcd-server \
    --config "$BATS_TEST_TMPDIR/rendered-1.37.yaml"
  [ "$status" -eq 1 ]
  [[ "$output" == *'unknown flag: --config'* ]]
  # The replacement shape: etcd-ca, then the four etcd certs, each
  # accepting the same --config the alpha calls used.
  run "$KUBEADM137" init phase certs etcd-ca \
    --config "$BATS_TEST_TMPDIR/rendered-1.37.yaml"
  [ "$status" -eq 0 ]
  for sub in etcd-server etcd-peer etcd-healthcheck-client apiserver-etcd-client; do
    run "$KUBEADM137" init phase certs "$sub" \
      --config "$BATS_TEST_TMPDIR/rendered-1.37.yaml"
    [ "$status" -eq 0 ]
  done
  [ -f "$BATS_TEST_TMPDIR/pki/etcd/ca.crt" ]
  [ -f "$BATS_TEST_TMPDIR/pki/etcd/server.crt" ]
  [ -f "$BATS_TEST_TMPDIR/pki/etcd/peer.crt" ]
  # And the kattic etcd-local replacement, dry-run against the config.
  run "$KUBEADM137" init phase etcd local --dry-run \
    --config "$BATS_TEST_TMPDIR/rendered-1.37.yaml"
  [ "$status" -eq 0 ]
}
