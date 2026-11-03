#!/bin/sh
# Runs only in stage 1, before root is mounted. Never invoke on the live root.
set -eu
export LC_ALL=C

expected_uuid=015f9988-3f81-48a8-983c-a81166edcd18
device="/dev/disk/by-uuid/$expected_uuid"

stop() {
	echo "Root large_dir migration: $*" >&2
	exit 1
}

check_fs() {
	local result=0
	e2fsck -p "$@" "$device" || result=$?
	case "$result" in
	0 | 1) ;;
	2 | 3)
		echo "Root filesystem check requires a reboot." >&2
		exit 2
		;;
	*) stop "e2fsck failed (status $result); refusing to mount root." ;;
	esac
}

# Never modify a filesystem that might belong to a hibernated system.
case " $(cat /proc/cmdline) " in
*" resume="* | *" resume_offset="*) stop "Resume is configured; boot with those parameters removed and a clean shutdown first." ;;
esac

[ -b "$device" ] || stop "Expected root block device is missing: $device"
[ "$(blkid -p -s UUID -o value "$device")" = "$expected_uuid" ] || stop "Root UUID mismatch."
[ "$(blkid -p -s TYPE -o value "$device")" = ext4 ] || stop "Root is not ext4."

# Compare device numbers, not mount source names (which may be aliases).
major_minor=$(stat -c '%t %T' "$device")
device_number=$(printf '%d:%d' "0x${major_minor% *}" "0x${major_minor#* }")
if grep -q "^[^ ]* [^ ]* $device_number " /proc/self/mountinfo; then
	stop "Root device is already mounted."
fi
# There should be no active swap at this point, especially no root swapfile.
[ "$(wc -l </proc/swaps)" -eq 1 ] || stop "Swap is active."

features=$(tune2fs -l "$device") || stop "Cannot inspect root superblock."
if printf '%s\n' "$features" | grep '^Filesystem features:' | grep -qw large_dir; then
	# Also completes checking after an interrupted previous migration.
	check_fs
	echo "Root large_dir feature already enabled."
	exit 0
fi

check_fs -f
echo "Enabling ext4 large_dir on root ($expected_uuid)..."
tune2fs -O large_dir "$device" || stop "Cannot enable large_dir."
check_fs -f
features=$(tune2fs -l "$device") || stop "Cannot verify root superblock."
printf '%s\n' "$features" | grep '^Filesystem features:' | grep -qw large_dir || stop "large_dir is still absent."
echo "Root large_dir migration complete."
