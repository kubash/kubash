#!/usr/bin/env bats
# Tests for mount_all_other_targets (lib/storage.bash), issue #68:
# the four storage device sets were four copy-pasted blocks, and
# in blocks 1-3 a 'null' UUID generated its replacement into the
# wrong variable - fsck ran against UUID=null, mkfs got -U null,
# and fstab recorded UUID=null. The blocks are one helper now;
# these tests pin the remote command stream it emits.

setup() {
  KUBASH_ROOT="${KUBASH_ROOT:-$HOME/.kubash}"
  STREAM="$BATS_TEST_TMPDIR/stream.log"
  : > "$STREAM"
  for fn in mount_all_other_targets mount_one_storage_target \
            lvm_creation_run lvm_extend_run check_first_device; do
    eval "$(sed -n "/^$fn ()/,/^}/p" "$KUBASH_ROOT/lib/storage.bash")"
  done
  eval "$(grep '^CSV_COLUMNS_6_0_0=' "$KUBASH_ROOT/lib/kvars.bash")"
  csv_columns="$CSV_COLUMNS_6_0_0"
  squawk() { :; }
  croak() { echo "CROAK: $*" >> "$STREAM"; }
  uuidgen() { echo 'FIXED-UUID-1234'; }
  sudo_command() {
    echo "$4" >> "$STREAM"
    if [ -n "$FSCK_FAIL" ]; then
      case "$4" in *fsck.ext4*) return 1 ;; esac
    fi
    return 0
  }
  export K8S_lvm_vg=kubashvg
  # hostL: base + device1, both LVM (create, then extend).
  # hostM: base plain with a supplied UUID; device1 plain with a
  # 'null' UUID (the #68 bug case); device2 plain with a supplied
  # UUID; device3 absent.
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
         storagePath='/img', storageType='raw', storageSize='23G',
         storageTarget='vdb', storageMountPath='lvm',
         storagePath1='/img', storageType1='raw', storageSize1='23G',
         storageTarget1='vdc', storageMountPath1='lvm')
m = dict(base, node='hostM', ip1='10.0.1.22',
         storagePath='/img', storageType='raw', storageSize='23G',
         storageTarget='vdb', storageMountPath='/data0', storageUUID='UUID-BASE',
         storagePath1='/img', storageType1='raw', storageSize1='23G',
         storageTarget1='vdc', storageMountPath1='/data1',
         storagePath2='/img', storageType2='raw', storageSize2='23G',
         storageTarget2='vdd', storageMountPath2='/data2', storageUUID2='UUID-DEV2')
print(row(**l))
print(row(**m))
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
