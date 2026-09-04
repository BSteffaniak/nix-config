{
  config,
  lib,
  ...
}:

let
  cfg = config.myConfig.services.sshd;
in
{
  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      ports = [ cfg.port ];
      settings = {
        PasswordAuthentication = cfg.passwordAuthentication;
        AllowUsers = cfg.allowedUsers;
        UseDns = cfg.useDns;
        X11Forwarding = cfg.x11Forwarding;
        PermitRootLogin = cfg.permitRootLogin;
      };
      inherit (cfg) extraConfig;
    };
  };
}
