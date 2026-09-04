{
  config,
  lib,
  pkgs,
  inputs ? { },
  ...
}:

let
  cfg = config.myConfig.editors.neovim;
in
{
  options.myConfig.editors.neovim = {
    enable = lib.mkEnableOption "Neovim editor";

    useNightly = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use nightly Neovim build";
    };

    # Plugin toggles
    plugins = {
      supermaven = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Supermaven AI assistant";
      };

      copilot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable GitHub Copilot";
      };

      avante = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Avante AI assistant";
      };

      jdtls = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Java development tools (nvim-jdtls)";
      };

      elixir = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Elixir development plugins";
      };

      ionide = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Ionide F# support";
      };

      dadbod = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable vim-dadbod database tools";
      };

      treesitterHypr = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable tree-sitter Hyprland support";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        # Lua runtime and development tools
        # Note: Using luajit only (what Neovim uses) to avoid collision with lua package
        luajit
        luajitPackages.luarocks

        # Neovim configuration editing tools
        stylua
        lua-language-server
        tree-sitter

        # Universal language servers
        nil # Nix LSP
        bash-language-server
      ]
      ++ (
        # Neovim editor (conditional: nightly or stable)
        if cfg.useNightly && inputs ? neovim-nightly-overlay then
          [ inputs.neovim-nightly-overlay.packages."${pkgs.stdenv.hostPlatform.system}".default ]
        else
          [ pkgs.neovim ]
      );

    # Set neovim as default editor
    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    # Symlink standalone neovim config from configs/neovim
    xdg.configFile."nvim" = {
      source = ../../../configs/neovim;
      recursive = true;
    };

    # Generate host-specific plugin configuration
    xdg.configFile."nvim/lua/host-config.lua".text = ''
      -- Auto-generated host-specific configuration
      -- Do not edit manually - this file is managed by Nix
      return {
        plugins = {
          supermaven = ${if cfg.plugins.supermaven then "true" else "false"},
          copilot = ${if cfg.plugins.copilot then "true" else "false"},
          avante = ${if cfg.plugins.avante then "true" else "false"},
          jdtls = ${if cfg.plugins.jdtls then "true" else "false"},
          elixir = ${if cfg.plugins.elixir then "true" else "false"},
          ionide = ${if cfg.plugins.ionide then "true" else "false"},
          dadbod = ${if cfg.plugins.dadbod then "true" else "false"},
          treesitter_hypr = ${if cfg.plugins.treesitterHypr then "true" else "false"},
        }
      }
    '';
  };
}
