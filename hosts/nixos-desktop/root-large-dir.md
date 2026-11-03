# Root ext4 large-directory migration

This host's Nix deduplication directory (`/nix/store/.links`) exhausted ext4's
normal directory index depth despite free blocks and inodes. The host-local
`root-large-dir.nix` enables the persistent `large_dir` feature at early boot,
while root is unmounted. It does not reformat or move any files.

## Deployment

Keep a current backup and access to the boot console/recovery media. A failed
check deliberately stops in stage 1; normal SSH will not be available then.
Do not hibernate into this migration: perform a clean shutdown/reboot.

1. Build and review with `./rebuild.sh --diff`.
2. Install the next boot generation with `./rebuild.sh --boot`.
3. Reboot when ready. The first boot performs a full filesystem check before
   and after enabling the feature; allow time for both checks.
4. Verify using:

   ```bash
   sudo tune2fs -l /dev/disk/by-uuid/015f9988-3f81-48a8-983c-a81166edcd18
   ```

   Confirm `large_dir` appears on the `Filesystem features:` line.
5. Run `sudo nix-store --optimise`, then inspect `journalctl -k -b` for fresh
   directory-index warnings.

The migration is guarded by the exact UUID, ext4 type, no active swap, no
resume parameters, and an unmounted device. Unresolved errors stop boot;
fsck statuses 2/3 request a reboot. Later boots skip the feature change and
only run a normal preen check, also covering an interrupted migration.
Do not run `root-large-dir.sh` manually on a running system.

The feature survives generation rollback. Current Linux and e2fsprogs support
it; use compatible recovery media. `tune2fs` does not support clearing this
feature. After successful deployment the import and migration files may be
removed, but removal does not disable the filesystem feature.

## Tests

`python3 hosts/nixos-desktop/test-root-large-dir.py` uses disposable 64 MiB
sparse ext4 images without root or loop devices. It tests the actual feature
change, rerun, UUID/mount/swap/resume guards, and fsck statuses 1, 2, and 4.
`MIGRATION_TEST_SHELL` and `MIGRATION_TEST_UTILS` can select the built initrd's
shell and binary directory to test the same tools used at boot.
