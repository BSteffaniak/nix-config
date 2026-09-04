# Option declarations for myConfig.shell.fish.
{ lib, ... }:

{
  options.myConfig.shell.fish = {
    enable = lib.mkEnableOption "Fish shell configuration";

    # Low-level options for custom use
    aliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Custom fish shell aliases";
    };

    functions = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Custom fish shell functions";
    };

    shellInit = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Fish shell initialization code";
    };

    interactiveShellInit = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Interactive shell initialization code";
    };

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Fish plugins to install";
      example = lib.literalExpression ''
        with pkgs.fishPlugins; [
          done
          fzf-fish
          forgit
          hydro
        ]
      '';
    };

    extraConfigFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        List of additional fish config files to source.
        Paths are relative to home directory.
        Useful for sourcing non-Nix managed configurations.
        Files are sourced in order, and only if they exist.
      '';
      example = lib.literalExpression ''
        [
          ".config/fish/work.fish"
          ".config/fish/private.fish"
          ".local/fish/custom.fish"
        ]
      '';
    };

    # ============================================================
    # FEATURE-BASED CONFIGURATION
    # ============================================================

    # Flat Project Configuration
    flat = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Flat project tooling";
      };

      logging = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Flat logging functions (requires flat.enable)";
      };

      airship = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Airship/devship wrapper (requires flat.enable and airship package)";
      };
    };

    # Zellij Configuration
    zellij = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Zellij terminal multiplexer integration";
      };

      resurrect = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable session resurrection function (requires zellij.enable)";
      };
    };

    # OpenCode Configuration
    opencode = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable OpenCode development tooling";
      };

      devMode = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable development mode runner (requires opencode.enable)";
      };

      projectPath = lib.mkOption {
        type = lib.types.str;
        default = "/hdd/GitHub/opencode";
        description = "Path to OpenCode project";
      };
    };

    # Neovim Configuration
    neovim = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable Neovim-specific features.
          Automatically detected from system configuration (myConfig.editors.neovim.enable).
        '';
      };

      sessionLoading = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable nvims function for session loading (requires neovim.enable)";
      };

      manPages = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable enhanced man page viewer in nvim (requires neovim.enable)";
      };
    };

    # General Utilities
    utilities = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable general utility functions";
      };

      sessionManagement = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable reload-session function (requires utilities.enable)";
      };

      pathManagement = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable path management utilities (fish_remove_path) - requires utilities.enable";
      };

      retryCommand = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable auto-retry command wrapper (requires utilities.enable)";
      };
    };

    # Development Tools
    development = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable development/testing tools";
      };

      benchmark = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable terminal rendering benchmark (requires development.enable)";
      };
    };

    # Editor Configuration
    editor = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable editor environment variable configuration";
      };

      nvim = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Set neovim as EDITOR and VISUAL (requires editor.enable).
          Automatically detected from system configuration (myConfig.editors.neovim.enable).
        '';
      };
    };

    # Direnv Integration
    direnv = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable direnv integration for per-directory environments";
      };
    };
  };
}
