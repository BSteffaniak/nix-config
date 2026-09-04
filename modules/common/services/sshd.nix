# OpenSSH server (sshd). The SSH client is configured per-user in
# home-manager via myConfig.shell.ssh.
{
  config,
  lib,
  ...
}:

{
  options.myConfig.services.sshd = {
    enable = lib.mkEnableOption "OpenSSH server (sshd)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 22;
      description = "SSH server port";
    };

    allowedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ config.myConfig.username ];
      description = "Users allowed to connect via SSH";
    };

    passwordAuthentication = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow password authentication";
    };

    permitRootLogin = lib.mkOption {
      type = lib.types.enum [
        "yes"
        "no"
        "prohibit-password"
        "forced-commands-only"
      ];
      default = "prohibit-password";
      description = "Permit root login";
    };

    x11Forwarding = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable X11 forwarding";
    };

    useDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use DNS for hostname resolution";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra SSH server configuration (NixOS only)";
    };
  };
}
