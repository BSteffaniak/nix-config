{ config, lib, ... }:

{
  # nix-darwin only toggles the system sshd; its settings are managed by macOS.
  config = lib.mkIf config.myConfig.services.sshd.enable {
    services.openssh.enable = true;
  };
}
