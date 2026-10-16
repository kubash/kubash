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
  # the functions under test, extracted from lib/net.bash
  eval "$(sed -n '/^configure_secondary_network_interfaces ()/,/^}/p' "$KUBASH_ROOT/lib/net.bash")"
  eval "$(sed -n '/^configure_secondary_interface ()/,/^}/p' "$KUBASH_ROOT/lib/net.bash")"
  eval "$(sed -n '/^netmask_to_prefix ()/,/^}/p' "$KUBASH_ROOT/lib/net.bash")"
  # the 2.0.0 column layout it reads
  eval "$(grep '^CSV_COLUMNS_2_0_0=' "$KUBASH_ROOT/lib/kvars.bash")"
  squawk() { :; }
  croak() { return 1; }
  set_csv_columns() { csv_columns="$CSV_COLUMNS_2_0_0"; }
  sudo_command() { echo "$4" >> "$CAPTURE/commands.log"; }
  rsync() {
    local args=("$@")
    local src="${args[$(($# - 2))]}"
    local dest="${args[$(($# - 1))]}"
    cp "$src" "$CAPTURE/$(echo "$dest" | tr '@:/' '___')"
  }
  export KUBASH_DIR="$KUBASH_ROOT"
  export K8S_SU_USER=vagrant
  export KUBASH_HOSTS_CSV="$BATS_TEST_TMPDIR/hosts.csv"
  write_hosts_csv debian-gnu
}

# hostA: full static network2, no network3.
# hostB: network2 without netmask/broadcast/gateway ('null'),
#        network3 with only an ip ('null' elsewhere).
# $1 is the os string written into both rows; with $2 = 'dhcp',
# hostB's network2 is DHCP instead of sparse static.
write_hosts_csv() {
  python3 - "$KUBASH_HOSTS_CSV" "$1" "$2" <<'PYEOF'
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
            os=sys.argv[2], virt='qemu')
a = dict(base, node='hostA', mac2='52:54:00:00:00:02', network2='net2',
         ip2='10.0.2.11', rp2='10.0.2.0', sm2='255.255.255.0',
         bc2='10.0.2.255', gw2='10.0.2.1')
b = dict(base, node='hostB', ip1='10.0.1.12', mac2='52:54:00:00:00:03',
         network2='net2', ip2='10.0.2.12', rp2='10.0.2.0',
         mac3='52:54:00:00:00:04', network3='net3', ip3='10.0.3.12')
if len(sys.argv) > 3 and sys.argv[3] == 'dhcp':
    b['ip2'] = 'dhcp'
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

@test "net: ubuntu hosts get netplan files, not ifupdown snippets" {
  write_hosts_csv ubuntu dhcp
  run configure_secondary_network_interfaces
  [ "$status" -eq 0 ]
  a_eth1=$(echo "$CAPTURE"/*10.0.1.11*eth1* 2>/dev/null)
  b_eth1=$(echo "$CAPTURE"/*10.0.1.12*eth1* 2>/dev/null)
  b_eth2=$(echo "$CAPTURE"/*10.0.1.12*eth2* 2>/dev/null)
  # hostA eth1: static, dotted netmask rendered as a CIDR prefix,
  # gateway as a default route
  grep -q 'addresses: \["10.0.2.11/24"\]' "$a_eth1"
  grep -q 'via: 10.0.2.1' "$a_eth1"
  # hostB eth1: dhcp
  grep -q 'dhcp4: true' "$b_eth1"
  # hostB eth2: static with a 'null' netmask falls back to /24,
  # and no gateway means no routes block
  grep -q 'addresses: \["10.0.3.12/24"\]' "$b_eth2"
  run grep -q 'routes' "$b_eth2"
  [ "$status" -ne 0 ]
  # the files land in /etc/netplan with netplan perms, and the
  # interfaces come up via netplan apply - never ifup/interfaces.d
  grep -q '/etc/netplan/60-kubash-eth1.yaml' "$CAPTURE/commands.log"
  grep -q 'chmod 600 /etc/netplan/60-kubash-eth2.yaml' "$CAPTURE/commands.log"
  grep -q '^netplan apply$' "$CAPTURE/commands.log"
  run grep -q 'interfaces.d' "$CAPTURE/commands.log"
  [ "$status" -ne 0 ]
  run grep -q 'ifup' "$CAPTURE/commands.log"
  [ "$status" -ne 0 ]
}

@test "net: noble hosts get netplan files too" {
  write_hosts_csv noble
  run configure_secondary_network_interfaces
  [ "$status" -eq 0 ]
  a_eth1=$(echo "$CAPTURE"/*10.0.1.11*eth1* 2>/dev/null)
  grep -q 'addresses: \["10.0.2.11/24"\]' "$a_eth1"
  grep -q '/etc/netplan/60-kubash-eth1.yaml' "$CAPTURE/commands.log"
}

@test "net: netmask_to_prefix converts dotted netmasks" {
  [ "$(netmask_to_prefix 255.255.255.0)" = '24' ]
  [ "$(netmask_to_prefix 255.255.0.0)" = '16' ]
  [ "$(netmask_to_prefix 255.0.0.0)" = '8' ]
  [ "$(netmask_to_prefix 255.255.255.252)" = '30' ]
}
