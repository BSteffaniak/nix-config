{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;

{
  options.myConfig.editors.neovim = {
    enable = mkEnableOption "Neovim editor";
    useNightly = mkOption {
      type = types.bool;
      default = false;
      description = "Use nightly Neovim build";
    };
  };

  config = mkIf config.myConfig.editors.neovim.enable {
    environment.systemPackages =
      with pkgs;
      [
        # Lua runtime and development tools (Neovim core dependencies)
        lua # Standard Lua interpreter (5.x)
        luajit # LuaJIT - faster JIT compiler (what Neovim uses)
        luajitPackages.luarocks # Lua package manager

        # Neovim configuration editing tools
        stylua # Lua formatter (for editing Neovim config)
        lua-language-server # Lua LSP (for editing Neovim config)

        # Universal system language servers
        nil # Nix LSP (for editing NixOS configs)
        bash-language-server # Bash LSP (shell scripts are universal)
      ]
      ++ (
        # Neovim editor (conditional: nightly or stable)
        if config.myConfig.editors.neovim.useNightly then
          [ inputs.neovim-nightly-overlay.packages."${pkgs.stdenv.hostPlatform.system}".default ]
        else
          [ pkgs.neovim ]
      );
  };
}
