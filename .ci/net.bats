#!/usr/bin/env bats
# Regression test for issue #67: in configure_secondary_network_interfaces
# the this_* variables fed to envsubst were never reset between
# interfaces or hosts, so a field left 'null' in one interface's CSV
# row silently inherited the previous interface's (or host's) value -
# defining a third interface picked up the second interface's
# address lines and "blew up".

setup() {
  KUBASH_ROOT="${KUBASH_ROOT:-$HOME/.kubash}"
  CAPTURE="$BATS_TEST_TMPDIR/capture"
  mkdir -p "$CAPTURE"
  # the function under test, extracted from lib/net.bash
  eval "$(sed -n '/^configure_secondary_network_interfaces ()/,/^}/p' "$KUBASH_ROOT/lib/net.bash")"
  # the 2.0.0 column layout it reads
  eval "$(grep '^CSV_COLUMNS_2_0_0=' "$KUBASH_ROOT/lib/kvars.bash")"
  squawk() { :; }
  croak() { return 1; }
  set_csv_columns() { csv_columns="$CSV_COLUMNS_2_0_0"; }
  sudo_command() { :; }
  rsync() {
    local args=("$@")
    local src="${args[$(($# - 2))]}"
    local dest="${args[$(($# - 1))]}"
    cp "$src" "$CAPTURE/$(echo "$dest" | tr '@:/' '___')"
  }
  export KUBASH_DIR="$KUBASH_ROOT"
  export K8S_SU_USER=vagrant
  export KUBASH_HOSTS_CSV="$BATS_TEST_TMPDIR/hosts.csv"
  # hostA: full static network2, no network3.
  # hostB: network2 without netmask/broadcast/gateway ('null'),
  #        network3 with only an ip ('null' elsewhere).
  python3 - "$KUBASH_HOSTS_CSV" <<'PYEOF'
import sys
cols = ("node role cpu mem sshPort network1 mac1 ip1 rp1 sm1 bc1 gw1 "
        "pHost pUser pPort pBase os virt network2 mac2 ip2 rp2 sm2 bc2 gw2 "
        "network3 mac3 ip3 rp3 sm3 bc3 gw3").split()
def row(**kw):
    d = dict.fromkeys(cols, 'null')
    d.update(kw)
    return ','.join(d[c] for c in cols)
base = dict(role='node', cpu='2', mem='2048', sshPort='22',
            network1='net1', mac1='52:54:00:00:00:01', ip1='10.0.1.11',
            rp1='10.0.1.0', sm1='255.255.255.0', bc1='10.0.1.255', gw1='10.0.1.1',
            pHost='localhost', pUser='vagrant', pPort='22', pBase='/tmp',
            os='debian-gnu', virt='qemu')
a = dict(base, node='hostA', mac2='52:54:00:00:00:02', network2='net2',
         ip2='10.0.2.11', rp2='10.0.2.0', sm2='255.255.255.0',
         bc2='10.0.2.255', gw2='10.0.2.1')
b = dict(base, node='hostB', ip1='10.0.1.12', mac2='52:54:00:00:00:03',
         network2='net2', ip2='10.0.2.12', rp2='10.0.2.0',
         mac3='52:54:00:00:00:04', network3='net3', ip3='10.0.3.12')
with open(sys.argv[1], 'w') as f:
    f.write(row(**a) + '\n')
    f.write(row(**b) + '\n')
PYEOF
}

@test "net: null fields do not inherit the previous interface's values (#67)" {
  run configure_secondary_network_interfaces
  [ "$status" -eq 0 ]
  a_eth1=$(echo "$CAPTURE"/*10.0.1.11*eth1* 2>/dev/null)
  b_eth1=$(echo "$CAPTURE"/*10.0.1.12*eth1* 2>/dev/null)
  b_eth2=$(echo "$CAPTURE"/*10.0.1.12*eth2* 2>/dev/null)
  grep -q 'gateway 10.0.2.1' "$a_eth1"
  [ -f "$b_eth1" ]
  [ -f "$b_eth2" ]
  # hostB eth1 has its own address and network...
  grep -q 'address 10.0.2.12' "$b_eth1"
  grep -q 'network 10.0.2.0' "$b_eth1"
  # ...but NOT hostA's netmask, broadcast, or gateway
  run grep -q 'netmask 255.255.255.0' "$b_eth1"
  [ "$status" -ne 0 ]
  run grep -q 'broadcast 10.0.2.255' "$b_eth1"
  [ "$status" -ne 0 ]
  run grep -q 'gateway 10.0.2.1' "$b_eth1"
  [ "$status" -ne 0 ]
  # hostB eth2 has its own address and no inherited gateway
  grep -q 'address 10.0.3.12' "$b_eth2"
  run grep -q 'gateway' "$b_eth2"
  [ "$status" -ne 0 ]
  run grep -q 'netmask' "$b_eth2"
  [ "$status" -ne 0 ]
}
