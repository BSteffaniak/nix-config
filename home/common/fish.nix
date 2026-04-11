{
  config,
  lib,
  myLib,
  pkgs,
  osConfig ? { },
  ...
}:

with lib;

let
  fishCfg = config.homeModules.fish;

  defaultShell = attrByPath [
    "defaults"
    "shell"
    "default"
  ] "nushell" myLib;

  systemNeovimEnabled =
    if
      hasAttrByPath [
        "myConfig"
        "editors"
        "neovim"
        "enable"
      ] osConfig
    then
      osConfig.myConfig.editors.neovim.enable
    else
      config.myConfig.editors.neovim.enable or true;

  systemFishEnabled =
    if
      hasAttrByPath [
        "myConfig"
        "shell"
        "fish"
        "enable"
      ] osConfig
    then
      osConfig.myConfig.shell.fish.enable
    else
      (config.myConfig.shell.fish.enable or false)
      || (config.myConfig.shell.default or defaultShell) == "fish";

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
  );

  # Shared flat functions (POSIX scripts, available in all shells)
  flatSharedFunctions = optionalAttrs fishCfg.flat.enable (
    optionalAttrs fishCfg.flat.airship {
      devship = ''
        exec airship --use-links "$@"
      '';
    }
  );

  # ============================================================
  # ZELLIJ CONFIGURATION
  # ============================================================
  zellijFunctions = { };

  zellijSharedFunctions = optionalAttrs (fishCfg.zellij.enable && fishCfg.zellij.resurrect) {
    zresurrect = ''
      echo "Resurrecting zellij sessions..."
      zellij list-sessions --short | while IFS= read -r session; do
        if [ -n "$session" ]; then
          echo "-> $session"
          zellij attach "$session" --force-run-commands --create-background
        fi
      done
      echo "Done! Check sessions with: zellij ls"
    '';
  };

  # ============================================================
  # NEOVIM CONFIGURATION
  # ============================================================
  # Fish-only neovim functions (none remaining -- moved to shared)
  neovimFunctions = { };

  # Shared neovim functions (POSIX scripts, available in all shells)
  neovimSharedFunctions = optionalAttrs fishCfg.neovim.enable (
    (optionalAttrs fishCfg.neovim.sessionLoading {
      nvims = ''
        exec nvim -c 'lua Handle_load_session()' "$@"
      '';
    })
    // (optionalAttrs fishCfg.neovim.manPages {
      nman = ''
        command man "$@" 2>/dev/null | col -b | nvim -R -c 'set ft=man nomod nolist' -
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
  );

  utilitySharedFunctions =
    optionalAttrs (fishCfg.utilities.enable && fishCfg.utilities.retryCommand)
      {
        auto-retry = ''
          current_attempt=0
          max_attempts="$1"
          delay="$2"
          shift 2

          if [ -z "$max_attempts" ] || [ -z "$delay" ] || [ "$#" -eq 0 ]; then
            echo "Usage: auto-retry <max_attempts> <delay_seconds> <command...>"
            exit 2
          fi

          while [ "$current_attempt" -lt "$max_attempts" ]; do
            current_attempt=$((current_attempt + 1))
            if "$@"; then
              exit 0
            fi

            echo "Failed at attempt $current_attempt/$max_attempts, retrying after $delay seconds"
            sleep "$delay"
          done

          exit 1
        '';
      };

  # ============================================================
  # DEVELOPMENT CONFIGURATION
  # ============================================================
  # Fish-only development functions (none remaining -- moved to shared)
  developmentFunctions = { };

  # Shared development functions (POSIX scripts, available in all shells)
  developmentSharedFunctions =
    optionalAttrs (fishCfg.development.enable && fishCfg.development.benchmark)
      {
        benchmark = ''
          i=0
          while [ "$i" -lt 400000 ]; do
            i=$((i + 1))
            printf '\r'
            printf "Iteration %s:\r" "$i"
            printf '\033[0K\033[1mBold\033[0m \033[7mInvert\033[0m \033[4mUnderline\033[0m\n'
            printf '\033[0K\033[1m\033[7m\033[4mBold & Invert & Underline\033[0m\n'
            echo
            printf '\033[0K\033[31m Red \033[32m Green \033[33m Yellow \033[34m Blue \033[35m Magenta \033[36m Cyan \033[0m\n'
            printf '\033[0K\033[1m\033[4m\033[31m Red \033[32m Green \033[33m Yellow \033[34m Blue \033[35m Magenta \033[36m Cyan \033[0m\n'
            echo
            printf '\033[0K\033[41m Red \033[42m Green \033[43m Yellow \033[44m Blue \033[45m Magenta \033[46m Cyan \033[0m\n'
            printf '\033[0K\033[1m\033[4m\033[41m Red \033[42m Green \033[43m Yellow \033[44m Blue \033[45m Magenta \033[46m Cyan \033[0m\n'
            echo
            printf '\033[0K\033[30m\033[41m Red \033[42m Green \033[43m Yellow \033[44m Blue \033[45m Magenta \033[46m Cyan \033[0m\n'
            printf '\033[0K\033[30m\033[1m\033[4m\033[41m Red \033[42m Green \033[43m Yellow \033[44m Blue \033[45m Magenta \033[46m Cyan \033[0m\n'
          done
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
    neovim.enable = mkDefault systemNeovimEnabled;

    # Editor config: use neovim if it's enabled system-wide
    editor = {
      enable = mkDefault true;
      nvim = mkDefault systemNeovimEnabled;
    };

    # Direnv: enabled by default when fish is enabled
    direnv.enable = mkDefault systemFishEnabled;

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
  config = mkIf systemFishEnabled {
    # Apply smart defaults, then merge with feature-based configuration
    homeModules.fish = mkMerge [
      smartDefaults
      {
        enable = true;

        # Fish-only functions (shell-state mutators that use set -gx, fish builtins, etc.)
        functions = mkMerge [
          flatFunctions
          zellijFunctions
          utilitiesFunctions
        ];

        # Merge init scripts (don't reference fishCfg.interactiveShellInit to avoid recursion)
        interactiveShellInit = mkMerge [
          editorInit
          direnvInit
        ];
      }
    ];

    # Shared functions (POSIX scripts via writeShellScriptBin, available in all shells)
    homeModules.shell.shared.functions = mkMerge [
      flatSharedFunctions
      zellijSharedFunctions
      neovimSharedFunctions
      utilitySharedFunctions
      developmentSharedFunctions
    ];

    # Set session variables for editor
    home.sessionVariables = mkIf (fishCfg.editor.enable && fishCfg.editor.nvim) {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };
}
