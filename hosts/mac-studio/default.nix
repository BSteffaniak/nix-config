{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ../../modules/common
    ../../modules/darwin
  ];

  # Host-specific system settings. User tools live in home.nix.
  myConfig = {
    # Login shells
    shell.fish.enable = true;
    shell.bash.enable = true;
    shell.zsh.enable = true;
    shell.nushell.enable = true;

    services.sshd.enable = true;
    services.tailscale.enable = true;

    # Darwin-specific
    darwin.homebrew.enable = true;
    darwin.androidStudio.enable = true;
    darwin.systemDefaults.enable = true;
    darwin.systemDefaults.darkMode = true;
    darwin.applications.enable = true;
    darwin.ghostty.enable = true;
    darwin.googleChrome.enable = true;
    darwin.istatMenus.enable = true;
    darwin.microsoftEdge.enable = true;
    darwin.roon.enable = true;
    darwin.scrollReverser.enable = true;
    darwin.scrollReverser.reverseVertical = false;
    darwin.security.touchId.enable = true;
    darwin.ollama.enable = true;

    # Desktop environment
    desktop.aerospace.enable = true;
    desktop.sketchybar.enable = true;
  };

  environment.systemPackages = [
    inputs.home-manager.packages."${pkgs.stdenv.hostPlatform.system}".default
  ];

  # Ownership is persistent macOS state; removing this does not undo it.
  # Never provision beneath an absent or different volume.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    (
      set -eu
      volume=/Volumes/ehdd
      info=$(/usr/sbin/diskutil info -plist "$volume" 2>/dev/null) || info=""
      uuid=$(printf '%s' "$info" | /usr/bin/plutil -extract VolumeUUID raw -o - - 2>/dev/null) || uuid=""
      mountpoint=$(printf '%s' "$info" | /usr/bin/plutil -extract MountPoint raw -o - - 2>/dev/null) || mountpoint=""
      if [ "$uuid" = 97676AC9-C0F3-47E3-93C2-F12D10243564 ] && [ "$mountpoint" = "$volume" ]; then
        /usr/sbin/diskutil enableOwnership "$volume"
        # Refuse symlinks before running privileged directory operations.
        if [ -L "$volume/tmp" ] || [ -L "$volume/tmp/${config.system.primaryUser}" ]; then
          echo "Refusing symlink in external temp directory" >&2
          exit 1
        fi
        /usr/bin/install -d -o root -g wheel -m 0755 "$volume/tmp"
        /usr/bin/install -d -o ${lib.escapeShellArg config.system.primaryUser} -g staff -m 0700 \
          "$volume/tmp/${config.system.primaryUser}"
      else
        echo "Skipping external temp setup: expected ehdd volume is not mounted" >&2
      fi
    )
  '';

  networking.computerName = "Braden's Mac Studio";
}
