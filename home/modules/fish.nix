{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  options.homeModules.fish = {
    enable = mkEnableOption "Fish shell configuration";

    # Low-level options for custom use
    aliases = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Custom fish shell aliases";
    };

    functions = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Custom fish shell functions";
    };

    shellInit = mkOption {
      type = types.lines;
      default = "";
      description = "Shell initialization code (runs for all shells)";
    };

    interactiveShellInit = mkOption {
      type = types.lines;
      default = "";
      description = "Interactive shell initialization code";
    };

    plugins = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Fish plugins to install";
      example = literalExpression ''
        with pkgs.fishPlugins; [
          done
          fzf-fish
          forgit
          hydro
        ]
      '';
    };

    extraConfigFiles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of additional fish config files to source.
        Paths are relative to home directory.
        Useful for sourcing non-Nix managed configurations.
        Files are sourced in order, and only if they exist.
      '';
      example = literalExpression ''
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
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Flat project tooling";
      };

      logging = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Flat logging functions (requires flat.enable)";
      };

      airship = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Airship/devship wrapper (requires flat.enable and airship package)";
      };
    };

    # Zellij Configuration
    zellij = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Zellij terminal multiplexer integration";
      };

      resurrect = mkOption {
        type = types.bool;
        default = true;
        description = "Enable session resurrection function (requires zellij.enable)";
      };
    };

    # OpenCode Configuration
    opencode = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable OpenCode development tooling";
      };

      devMode = mkOption {
        type = types.bool;
        default = true;
        description = "Enable development mode runner (requires opencode.enable)";
      };

      projectPath = mkOption {
        type = types.str;
        default = "/hdd/GitHub/opencode";
        description = "Path to OpenCode project";
      };
    };

    # Neovim Configuration
    neovim = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable Neovim-specific features.
          Automatically detected from system configuration (myConfig.editors.neovim.enable).
        '';
      };

      sessionLoading = mkOption {
        type = types.bool;
        default = true;
        description = "Enable nvims function for session loading (requires neovim.enable)";
      };

      manPages = mkOption {
        type = types.bool;
        default = true;
        description = "Enable enhanced man page viewer in nvim (requires neovim.enable)";
      };
    };

    # General Utilities
    utilities = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable general utility functions";
      };

      sessionManagement = mkOption {
        type = types.bool;
        default = true;
        description = "Enable reload-session function (requires utilities.enable)";
      };

      pathManagement = mkOption {
        type = types.bool;
        default = true;
        description = "Enable path management utilities (fish_remove_path) - requires utilities.enable";
      };

      retryCommand = mkOption {
        type = types.bool;
        default = true;
        description = "Enable auto-retry command wrapper (requires utilities.enable)";
      };
    };

    # Development Tools
    development = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable development/testing tools";
      };

      benchmark = mkOption {
        type = types.bool;
        default = true;
        description = "Enable terminal rendering benchmark (requires development.enable)";
      };
    };

    # Editor Configuration
    editor = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable editor environment variable configuration";
      };

      nvim = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Set neovim as EDITOR and VISUAL (requires editor.enable).
          Automatically detected from system configuration (myConfig.editors.neovim.enable).
        '';
      };
    };

    # Direnv Integration
    direnv = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable direnv integration for per-directory environments";
      };
    };
  };

  config = mkIf config.homeModules.fish.enable {
    programs.fish = {
      enable = true;
      shellAliases = config.homeModules.fish.aliases;
      functions = config.homeModules.fish.functions;
      plugins = map (pkg: {
        name = pkg.pname;
        src = pkg.src;
      }) config.homeModules.fish.plugins;

      shellInit = ''
        ${config.homeModules.fish.shellInit}
      '';

      interactiveShellInit = ''


        # Source extra config files specified in configuration
        ${concatMapStringsSep "\n" (file: ''
          if test -e "$HOME/${file}"
            source "$HOME/${file}"
          end
        '') config.homeModules.fish.extraConfigFiles}

        # Source local override file (convention-based)
        # This allows quick customizations without rebuilding
        if test -e "$HOME/.config/fish/local.fish"
          source "$HOME/.config/fish/local.fish"
        end

        ${config.homeModules.fish.interactiveShellInit}
      '';
    };
  };
}
