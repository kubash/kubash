#!/usr/bin/env bats
# Tests for mount_all_other_targets / mount_all_iscsi_targets /
# taint_all_storage (lib/storage.bash), issue #68 and the
# November 2026 bug-hunt Tier 2 netstorage slice (N-C2..N-C8):
# the four storage device sets were four copy-pasted blocks, and
# in blocks 1-3 a 'null' UUID generated its replacement into the
# wrong variable - fsck ran against UUID=null, mkfs got -U null,
# and fstab recorded UUID=null. The blocks are one helper now;
# these tests pin the remote command stream it emits.

setup() {
  KUBASH_ROOT="${KUBASH_ROOT:-$HOME/.kubash}"
  STREAM="$BATS_TEST_TMPDIR/stream.log"
  : > "$STREAM"
  for fn in mount_all_other_targets mount_one_storage_target guest_uuid \
            guest_vg_exists lvm_creation_run lvm_extend_run check_first_device \
            mount_all_iscsi_targets taint_all_storage taint_storage \
            record_storage_failure; do
    eval "$(sed -n "/^$fn ()/,/^}/p" "$KUBASH_ROOT/lib/storage.bash")"
  done
  eval "$(grep '^CSV_COLUMNS_6_0_0=' "$KUBASH_ROOT/lib/kvars.bash")"
  csv_columns="$CSV_COLUMNS_6_0_0"
  squawk() { :; }
  croak() { echo "CROAK: $*" >> "$STREAM"; }
  uuidgen() { echo 'FIXED-UUID-1234'; }
  kubectl() { echo "kubectl $*" >> "$STREAM"; }
  sudo_command() {
    echo "$4" >> "$STREAM"
    if [ -n "$FAIL_HOST" ] && [ "$3" = "$FAIL_HOST" ]; then
      return 1
    fi
    if [ -n "$FSCK_FAIL" ]; then
      case "$4" in *fsck.ext4*) return 1 ;; esac
    fi
    return 0
  }
  export K8S_lvm_vg=kubashvg
  # kvars.bash defaults the guest user to root; this harness
  # sources only the CSV columns, so mirror that default here
  # (the iscsi calls pass $K8S_user unquoted, so an unset user
  # would drop sudo_command's 4th argument entirely).
  export K8S_user=root
  # The VG the base device created exists by default; a test
  # clears VG_EXISTS to model a base that never created one.
  export VG_EXISTS=1
  # guest_uuid / guest_vg_exists run blkid / vgs on the guest;
  # the stubs below keep that deterministic. blkid answers per
  # device from BLKID_<DEV> (e.g. BLKID_VDB), falling back to
  # EXISTING-UUID-9 for any device when BLKID_EXISTS is set (the
  # Tier 1 reused-disk case); vgs succeeds only when VG_EXISTS
  # is set.
  STUBBIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUBBIN"
  cat > "$STUBBIN/silent" <<'EOF'
#!/bin/bash
exit 0
EOF
  # guest_uuid / guest_vg_exists take the remote branch for these
  # fixture hosts, so ssh must be stubbed too.
  cat > "$STUBBIN/ssh" <<'EOF'
#!/bin/bash
case "$*" in
  *blkid*)
    dev=$(printf '%s' "$*" | sed -n 's|.*/dev/\([A-Za-z0-9]*\).*|\1|p')
    var="BLKID_$(printf '%s' "$dev" | tr 'a-z' 'A-Z')"
    uuid="${!var}"
    if [ -n "$uuid" ]; then echo "$uuid"; elif [ -n "$BLKID_EXISTS" ]; then echo 'EXISTING-UUID-9'; fi
    ;;
  *vgs*)
    [ -n "$VG_EXISTS" ] || exit 1
    ;;
esac
exit 0
EOF
  chmod +x "$STUBBIN/silent" "$STUBBIN/ssh"
  export PATH="$STUBBIN:$PATH"
  export PSEUDO=silent
  # hostL: base + device1, both LVM (create, then extend);
  #        iscsi target with 'null' CHAP (the N-C2 bug case).
  # hostM: base plain with a supplied UUID; device1 plain with a
  # 'null' UUID (the #68 bug case); device2 plain with a supplied
  # UUID; device3 absent; iscsi with a chapusername but a 'null'
  # chappassword (the N-C2 croak case).
  # hostN: storagePath set, storageTarget 'null',
  # storageMountPath lvm (the N-C7 bug case); no iscsi.
  # hostO: base plain with a supplied UUID; iscsi with real CHAP
  # (the still-working case); the host after hostM, so the N-C8
  # tests can tell continuation from abort.
  kubash_hosts_csv_slurped="$(python3 - <<'PYEOF'
cols = ("node role cpu mem sshPort network1 mac1 ip1 rp1 sm1 bc1 gw1 "
        "pHost pUser pPort pBase os kvmvariant virt "
        "network2 mac2 ip2 rp2 sm2 bc2 gw2 network3 mac3 ip3 rp3 sm3 bc3 gw3 "
        "iscsitarget iscsichapusername iscsichappassword iscsihost "
        "storagePath storageType storageSize storageTarget storageMountPath storageUUID "
        "storagePath1 storageType1 storageSize1 storageTarget1 storageMountPath1 storageUUID1 "
        "storagePath2 storageType2 storageSize2 storageTarget2 storageMountPath2 storageUUID2 "
        "storagePath3 storageType3 storageSize3 storageTarget3 storageMountPath3 storageUUID3").split()
def row(**kw):
    d = dict.fromkeys(cols, 'null'); d.update(kw)
    return ','.join(d[c] for c in cols)
base = dict(role='storage', cpu='2', mem='2048', sshPort='22',
            network1='net1', mac1='52:54:00:00:00:01', ip1='10.0.1.21',
            rp1='10.0.1.0', sm1='255.255.255.0', bc1='10.0.1.255', gw1='10.0.1.1',
            pHost='localhost', pUser='vagrant', pPort='22', pBase='/tmp',
            os='debian-gnu', virt='qemu')
l = dict(base, node='hostL',
         iscsitarget='iqn.2026-01.com.example:stor', iscsihost='10.0.9.1',
         storagePath='/img', storageType='raw', storageSize='23G',
         storageTarget='vdb', storageMountPath='lvm',
         storagePath1='/img', storageType1='raw', storageSize1='23G',
         storageTarget1='vdc', storageMountPath1='lvm')
m = dict(base, node='hostM', ip1='10.0.1.22',
         iscsitarget='iqn.2026-01.com.example:stor2',
         iscsichapusername='chapuser', iscsihost='10.0.9.2',
         storagePath='/img', storageType='raw', storageSize='23G',
         storageTarget='vdb', storageMountPath='/data0', storageUUID='UUID-BASE',
         storagePath1='/img', storageType1='raw', storageSize1='23G',
         storageTarget1='vdc', storageMountPath1='/data1',
         storagePath2='/img', storageType2='raw', storageSize2='23G',
         storageTarget2='vdd', storageMountPath2='/data2', storageUUID2='UUID-DEV2')
n = dict(base, node='hostN', ip1='10.0.1.23',
         storagePath='/img', storageType='raw', storageSize='23G',
         storageMountPath='lvm')
o = dict(base, node='hostO', ip1='10.0.1.24',
         iscsitarget='iqn.2026-01.com.example:stor3',
         iscsichapusername='chapuser', iscsichappassword='secretpw',
         iscsihost='10.0.9.3',
         storagePath='/img', storageType='raw', storageSize='23G',
         storageTarget='vde', storageMountPath='/data3', storageUUID='UUID-DEV3')
print(row(**l))
print(row(**m))
print(row(**n))
print(row(**o))
PYEOF
)"
  export kubash_hosts_csv_slurped
}

@test "storage: every device set mounts with its own UUID (#68)" {
  run mount_all_other_targets
  [ "$status" -eq 0 ]
  # LVM: first device creates the VG, the next extends it
  grep -q '^pvcreate /dev/vdb$' "$STREAM"
  grep -q '^vgcreate kubashvg /dev/vdb$' "$STREAM"
  grep -q '^vgextend kubashvg /dev/vdc$' "$STREAM"
  # supplied UUIDs are used as-is
  grep -q 'UUID=UUID-BASE' "$STREAM"
  grep -q 'UUID=UUID-DEV2' "$STREAM"
  # the 'null'-UUID device uses the generated UUID in fsck + fstab
  grep -q '^fsck.ext4 -p UUID=FIXED-UUID-1234$' "$STREAM"
  grep -q 'UUID=FIXED-UUID-1234' "$STREAM"
  # ...and 'null' never reaches a command as a UUID
  run grep -q 'UUID=null' "$STREAM"
  [ "$status" -ne 0 ]
  run grep -q -- '-U null' "$STREAM"
  [ "$status" -ne 0 ]
}

@test "storage: a reused disk keeps its existing UUID instead of reformatting" {
  export BLKID_EXISTS=1
  # the supplied-UUID devices really carry the UUIDs the CSV
  # claims, or the N-C4 check below would (rightly) croak
  export BLKID_VDB=UUID-BASE BLKID_VDD=UUID-DEV2 BLKID_VDE=UUID-DEV3
  run mount_all_other_targets
  [ "$status" -eq 0 ]
  # the null-UUID device (hostM device 1) reuses the on-disk UUID:
  # fsck and fstab carry it, no mkfs runs, uuidgen is never used
  grep -q '^fsck.ext4 -p UUID=EXISTING-UUID-9$' "$STREAM"
  grep -q 'UUID=EXISTING-UUID-9' "$STREAM"
  run grep -q 'mkfs.ext4' "$STREAM"
  [ "$status" -ne 0 ]
  run grep -q 'FIXED-UUID-1234' "$STREAM"
  [ "$status" -ne 0 ]
}

@test "storage: a failed fsck formats each device with its own UUID (#68)" {
  export FSCK_FAIL=1
  run mount_all_other_targets
  [ "$status" -eq 0 ]
  grep -q '^mkfs.ext4 -U UUID-BASE /dev/vdb$' "$STREAM"
  grep -q '^mkfs.ext4 -U FIXED-UUID-1234 /dev/vdc$' "$STREAM"
  grep -q '^mkfs.ext4 -U UUID-DEV2 /dev/vdd$' "$STREAM"
  run grep -q -- '-U null' "$STREAM"
  [ "$status" -ne 0 ]
}

@test "storage: a 'null' CHAP username/password never forces CHAP (N-C2)" {
  run mount_all_iscsi_targets
  [ "$status" -eq 0 ]
  # hostL: discovery and login run, with no CHAP updates at all
  grep -q 'iscsiadm --mode discovery --type sendtargets --portal 10.0.9.1' "$STREAM"
  grep -q 'iscsiadm --mode node --portal 10.0.9.1 --targetname iqn.2026-01.com.example:stor --login' "$STREAM"
  run grep -q 'portal 10.0.9.1.*CHAP' "$STREAM"
  [ "$status" -ne 0 ]
  run grep -q -- '--value=null' "$STREAM"
  [ "$status" -ne 0 ]
  # hostO: real CHAP still configures authmethod, username and
  # password before login
  grep -q 'portal 10.0.9.3.*--name node.session.auth.authmethod --value=CHAP' "$STREAM"
  grep -q 'portal 10.0.9.3.*--name node.session.auth.username --value=chapuser' "$STREAM"
  grep -q 'portal 10.0.9.3.*--name node.session.auth.password --value=secretpw' "$STREAM"
  grep -q 'portal 10.0.9.3 --targetname iqn.2026-01.com.example:stor3 --login' "$STREAM"
}

@test "storage: a chapusername with a 'null' chappassword croaks, without a password update (N-C2)" {
  run mount_all_iscsi_targets
  [ "$status" -eq 0 ]
  # hostM: authmethod + username run, then the croak fires...
  grep -q 'portal 10.0.9.2.*--name node.session.auth.authmethod --value=CHAP' "$STREAM"
  grep -q 'portal 10.0.9.2.*--name node.session.auth.username --value=chapuser' "$STREAM"
  grep -q 'CROAK: 3 chapusername supplied without a chappassword!!!' "$STREAM"
  # ...and no password update is ever sent for it
  run grep -q 'portal 10.0.9.2.*auth.password' "$STREAM"
  [ "$status" -ne 0 ]
}

@test "storage: fstab is guarded against duplicates and already-mounted devices (N-C3)" {
  run mount_all_other_targets
  [ "$status" -eq 0 ]
  # the append runs only when the device is not mounted and no
  # line for this UUID or mountpoint is already in fstab...
  grep -Fq 'mountpoint -q /data0 || { grep -qs "UUID=UUID-BASE[[:space:]]" /etc/fstab' "$STREAM"
  grep -Fq 'grep -qs "[[:space:]]/data0[[:space:]]" /etc/fstab' "$STREAM"
  # ...and the mount itself is skipped when already mounted
  grep -q '^mountpoint -q /data0 || mount /data0$' "$STREAM"
  grep -q '^mountpoint -q /data1 || mount /data1$' "$STREAM"
}

@test "storage: a supplied UUID that is not the device's UUID croaks before fstab (N-C4)" {
  # hostM's base disk really carries UUID-OTHER, not UUID-BASE
  export BLKID_VDB=UUID-OTHER
  # the real croak exits; the harness stub only logs, so this
  # test models the exit to prove nothing after it runs for
  # that device (the N-C8 isolation still lets the host's other
  # devices and later hosts mount; the host is recorded failed)
  croak() { echo "CROAK: $*" >> "$STREAM"; exit 1; }
  run mount_all_other_targets
  [ "$status" -ne 0 ]
  grep -q 'CROAK: 3 storage device /dev/vdb has UUID UUID-OTHER, not the supplied UUID-BASE' "$STREAM"
  # the wrong UUID never reaches fstab for that device...
  run grep -q 'UUID=UUID-BASE' "$STREAM"
  [ "$status" -ne 0 ]
  # ...but the host's other devices and hostO still mount
  grep -q 'mkdir -p /data1' "$STREAM"
  grep -q 'mkdir -p /data3' "$STREAM"
}

@test "storage: a 'null' target with an lvm mount never reaches pvcreate (N-C7)" {
  run mount_all_other_targets
  [ "$status" -eq 0 ]
  # hostN: storageTarget=null + storageMountPath=lvm, storagePath
  # set - the old code ran pvcreate /dev/null for it
  run grep -q 'pvcreate /dev/null' "$STREAM"
  [ "$status" -ne 0 ]
  run grep -q 'vgcreate kubashvg /dev/null' "$STREAM"
  [ "$status" -ne 0 ]
}

@test "storage: an extend with no VG creates it instead of vgextend (N-C6)" {
  # the base device never created the VG (VG_EXISTS cleared)
  VG_EXISTS=
  run mount_all_other_targets
  [ "$status" -eq 0 ]
  grep -q '^pvcreate /dev/vdc$' "$STREAM"
  grep -q '^vgcreate kubashvg /dev/vdc$' "$STREAM"
  run grep -q '^vgextend kubashvg /dev/vdc$' "$STREAM"
  [ "$status" -ne 0 ]
}

@test "storage: one host's failure is recorded and the rest still mount (N-C8)" {
  # every remote command for hostM fails
  export FAIL_HOST=10.0.1.22
  run mount_all_other_targets
  [ "$status" -ne 0 ]
  # hostM was attempted...
  grep -q 'mkdir -p /data0' "$STREAM"
  # ...and hostO, after it in the CSV, still mounted
  grep -q 'mkdir -p /data3' "$STREAM"
  grep -q 'UUID=UUID-DEV3' "$STREAM"
}

@test "storage: a failed host is reported at the end, once, and both phases run (N-C8)" {
  export FAIL_HOST=10.0.1.22
  run taint_all_storage
  [ "$status" -eq 0 ]
  # the run reports hostM at the end, exactly once even though
  # it failed in both the iscsi and the mount phase
  grep -q 'CROAK: 3 storage setup failed on host(s): hostM' "$STREAM"
  run grep -q 'hostM hostM' "$STREAM"
  [ "$status" -ne 0 ]
  # ...and the hosts after it still got their iscsi logins and
  # their mounts
  grep -q 'portal 10.0.9.3 --targetname iqn.2026-01.com.example:stor3 --login' "$STREAM"
  grep -q 'mkdir -p /data3' "$STREAM"
}

@test "storage: under set -e a failed host does not abort the hosts after it (N-C8)" {
  # bats `run` disables errexit, which would mask the exact bug
  # (a set -e abort in bin/kubash), so this test runs the phase
  # in a child bash with errexit on, the way the real runner
  # invokes it. Functions and harness variables are exported
  # into that child.
  export FAIL_HOST=10.0.1.22
  export STREAM FAIL_HOST VG_EXISTS PSEUDO K8S_lvm_vg K8S_user kubash_hosts_csv_slurped csv_columns
  export -f mount_all_other_targets mount_one_storage_target guest_uuid \
    guest_vg_exists lvm_creation_run lvm_extend_run check_first_device \
    record_storage_failure squawk croak sudo_command uuidgen
  run bash -c 'set -e; mount_all_other_targets'
  [ "$status" -ne 0 ]
  # hostM was attempted, and hostO after it still mounted: on
  # master the child aborts at hostM's first failed command
  grep -q 'mkdir -p /data0' "$STREAM"
  grep -q 'mkdir -p /data3' "$STREAM"
}
