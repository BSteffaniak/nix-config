{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.myConfig.darwin.cloudflareWarp;
in
{
  options.myConfig.darwin.cloudflareWarp = {
    enable = mkEnableOption "Cloudflare WARP / Zero Trust client via Homebrew";
  };

  config = mkIf cfg.enable {
    homebrew.casks = [
      "cloudflare-warp"
    ];

    myConfig.darwin.homebrew.enable = true;
  };
}
