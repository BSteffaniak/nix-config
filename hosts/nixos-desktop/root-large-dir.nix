{ config, lib, ... }:

{
  assertions = [
    {
      assertion = !config.boot.initrd.systemd.enable;
      message = "The nixos-desktop root large_dir migration requires the scripted initrd.";
    }
    {
      assertion =
        config.fileSystems."/".fsType == "ext4"
        && config.fileSystems."/".device == "/dev/disk/by-uuid/015f9988-3f81-48a8-983c-a81166edcd18";
      message = "Review the root large_dir migration before changing the root filesystem.";
    }
  ];

  # The ext filesystem module already includes tune2fs/e2fsck; stage 1
  # supplies blkid and BusyBox. Run after udev, before checkFS/mountFS.
  # Never do this in activation: root must be completely unmounted.
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    (
      ${builtins.readFile ./root-large-dir.sh}
    )
    largeDirResult=$?
    if [ "$largeDirResult" -ne 0 ]; then
      if [ "$largeDirResult" -eq 2 ]; then
        reboot -f
      fi
      echo "Root large_dir migration stopped boot (status $largeDirResult)."
      # fail normally allows 'ignore and continue'. Do not allow that to
      # bypass a failed migration; the recovery shell/reboot remain usable.
      while true; do
        fail
        sleep 1
      done
    fi
  '';
}
