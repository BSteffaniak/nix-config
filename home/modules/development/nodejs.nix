{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.development.nodejs;
in
{
  options.myConfig.development.nodejs = {
    enable = lib.mkEnableOption "Node.js development environment";

    includeBun = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include Bun runtime";
    };

    includePnpm = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include pnpm package manager";
    };

    includeLanguageServers = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include TypeScript, Astro, Svelte, and web LSPs";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        nodePackages_latest.nodejs
      ]
      ++ (lib.optional cfg.includeBun unstable.bun)
      ++ (lib.optional cfg.includePnpm pnpm_10)
      ++ (lib.optionals cfg.includeLanguageServers [
        typescript-language-server
        astro-language-server
        svelte-language-server
        vscode-langservers-extracted # HTML/CSS/JSON/ESLint
      ]);

    # Configure npm to use global directory in home
    home.sessionVariables = {
      NPM_CONFIG_PREFIX = "$HOME/.npm-global";
    };

    # Add npm global bin to PATH
    home.sessionPath = [ "$HOME/.npm-global/bin" ];
  };
}
