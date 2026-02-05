{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:

with lib;

let
  fishCfg = config.homeModules.fish;

  # ============================================================
  # FLAT PROJECT CONFIGURATION
  # ============================================================
  flatFunctions = optionalAttrs fishCfg.flat.enable (
    (optionalAttrs fishCfg.flat.logging {
      set-flat-logging-levels = ''
        set -gx LOGGING_LABEL_LOGGING_LEVELS $argv[1]
      '';

      enable-flat-logging = ''
        set level $argv[1]
        set show_prefix $argv[2]
        set prefix_separator $argv[3]
        set suffix $argv[4]

        test -z "$level"; and set level DEBUG
        test -z "$show_prefix"; and set show_prefix true
        test -z "$prefix_separator"; and set prefix_separator '\n'
        test -z "$suffix"; and set suffix '\n'

        set-flat-logging-levels "*:$level"
        set -gx LOGGING_DEFAULT_SHOW_PREFIX $show_prefix
        set -gx LOGGING_DEFAULT_PREFIX_SEPARATOR $prefix_separator
        set -gx LOGGING_DEFAULT_SUFFIX $suffix
      '';

      disable-flat-logging = ''
        set -e LOGGING_LABEL_LOGGING_LEVELS
        set -e LOGGING_DEFAULT_SHOW_PREFIX
        set -e LOGGING_DEFAULT_PREFIX_SEPARATOR
        set -e LOGGING_DEFAULT_SUFFIX
      '';

      reset-flat-logging = ''
        disable-flat-logging
        enable-flat-logging
      '';
    })
    // (optionalAttrs fishCfg.flat.airship {
      devship = ''
        airship --use-links $argv
      '';
    })
  );

  # ============================================================
  # ZELLIJ CONFIGURATION
  # ============================================================
  zellijFunctions = optionalAttrs (fishCfg.zellij.enable && fishCfg.zellij.resurrect) {
    zresurrect = ''
      echo "Resurrecting zellij sessions..."
      zellij list-sessions --short | while read session
        if test -n "$session"
          echo "→ $session"
          zellij attach $session --force-run-commands --create-background
        end
      end
      echo "Done! Check sessions with: zellij ls"
    '';
  };

  # ============================================================
  # NEOVIM CONFIGURATION
  # ============================================================
  neovimFunctions = optionalAttrs fishCfg.neovim.enable (
    (optionalAttrs fishCfg.neovim.sessionLoading {
      nvims = ''
        nvim -c 'lua Handle_load_session()' $argv
      '';
    })
    // (optionalAttrs fishCfg.neovim.manPages {
      man = ''
        command man $argv 2>/dev/null | col -b | nvim -R -c 'set ft=man nomod nolist' -
      '';
    })
  );

  # ============================================================
  # UTILITIES CONFIGURATION
  # ============================================================
  utilitiesFunctions = optionalAttrs fishCfg.utilities.enable (
    (optionalAttrs fishCfg.utilities.sessionManagement {
      reload-session = ''
        set -e __fish_home_manager_config_sourced
        source ~/.config/fish/config.fish
      '';
    })
    // (optionalAttrs fishCfg.utilities.pathManagement {
      fish_remove_path = ''
        if set -l index (contains -i "$argv" $fish_user_paths)
          set -e fish_user_paths[$index]
          echo "Removed $argv from the path"
        end
      '';
    })
    // (optionalAttrs fishCfg.utilities.retryCommand {
      auto-retry = ''
        set current_attempt 0
        set max_attempts $argv[1]
        set delay $argv[2]
        set cmd $argv[3..-1]

        while test $current_attempt -lt $max_attempts
          set current_attempt (math $current_attempt + 1)
          if eval $cmd
            return 0
          end
          echo "Failed at attempt $current_attempt/$max_attempts, retrying after {$delay}s"
          sleep $delay
        end

        return 1
      '';
    })
  );

  # ============================================================
  # DEVELOPMENT CONFIGURATION
  # ============================================================
  developmentFunctions = optionalAttrs (fishCfg.development.enable && fishCfg.development.benchmark) {
    benchmark = ''
      for i in (seq 1 400000)
        echo -e '\r'
        echo -e "Iteration $i:\r"
        echo -e '\033[0K\033[1mBold\033[0m \033[7mInvert\033[0m \033[4mUnderline\033[0m'
        echo -e '\033[0K\033[1m\033[7m\033[4mBold & Invert & Underline\033[0m'
        echo
        echo -e '\033[0K\033[31m Red \033[32m Green \033[33m Yellow \033[34m Blue \033[35m Magenta \033[36m Cyan \033[0m'
        echo -e '\033[0K\033[1m\033[4m\033[31m Red \033[32m Green \033[33m Yellow \033[34m Blue \033[35m Magenta \033[36m Cyan \033[0m'
        echo
        echo -e '\033[0K\033[41m Red \033[42m Green \033[43m Yellow \033[44m Blue \033[45m Magenta \033[46m Cyan \033[0m'
        echo -e '\033[0K\033[1m\033[4m\033[41m Red \033[42m Green \033[43m Yellow \033[44m Blue \033[45m Magenta \033[46m Cyan \033[0m'
        echo
        echo -e '\033[0K\033[30m\033[41m Red \033[42m Green \033[43m Yellow \033[44m Blue \033[45m Magenta \033[46m Cyan \033[0m'
        echo -e '\033[0K\033[30m\033[1m\033[4m\033[41m Red \033[42m Green \033[43m Yellow \033[44m Blue \033[45m Magenta \033[46m Cyan \033[0m'
      end
    '';
  };

  # ============================================================
  # INTERACTIVE SHELL INIT COMPONENTS
  # ============================================================
  editorInit = optionalString (fishCfg.editor.enable && fishCfg.editor.nvim) ''
    # Set editor environment variables
    set -gx EDITOR nvim
    set -gx VISUAL nvim
  '';

  direnvInit = optionalString fishCfg.direnv.enable ''
    # Initialize direnv for per-directory environment management
    direnv hook fish | source
  '';

  # ============================================================
  # SMART DEFAULTS BASED ON SYSTEM CONFIGURATION
  # ============================================================
  # These use mkDefault so they can be overridden in host-specific configs
  smartDefaults = {
    # Neovim features: auto-enable if neovim is enabled system-wide
    neovim.enable = mkDefault (osConfig.myConfig.editors.neovim.enable or true);

    # Editor config: use neovim if it's enabled system-wide
    editor = {
      enable = mkDefault true;
      nvim = mkDefault (osConfig.myConfig.editors.neovim.enable or true);
    };

    # Direnv: enabled by default when fish is enabled
    direnv.enable = mkDefault (osConfig.myConfig.shell.fish.enable or true);

    # Utilities: always enabled by default (generally useful)
    utilities.enable = mkDefault true;

    # Project-specific features: opt-in only (keep as false)
    flat.enable = mkDefault false;
    zellij.enable = mkDefault false;
    opencode.enable = mkDefault false;
    development.enable = mkDefault false;
  };

in
{
  config = mkIf osConfig.myConfig.shell.fish.enable {
    # Apply smart defaults, then merge with feature-based configuration
    homeModules.fish = mkMerge [
      smartDefaults
      {
        enable = true;

        # Merge built-in functions (don't reference fishCfg.functions to avoid recursion)
        functions = mkMerge [
          flatFunctions
          zellijFunctions
          neovimFunctions
          utilitiesFunctions
          developmentFunctions
        ];

        # Merge init scripts (don't reference fishCfg.interactiveShellInit to avoid recursion)
        interactiveShellInit = mkMerge [
          editorInit
          direnvInit
        ];
      }
    ];

    # Set session variables for editor
    home.sessionVariables = mkIf (fishCfg.editor.enable && fishCfg.editor.nvim) {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };
}
