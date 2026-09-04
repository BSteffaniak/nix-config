# Fish shell configuration.
#
# Options: ./options.nix (myConfig.shell.fish.*)
# Function library: ./functions.nix
{
  config,
  lib,
  pkgs,
  osConfig ? { },
  ...
}:

let
  shellCfg = config.myConfig.shell;
  fishCfg = shellCfg.fish;
  fishEnabled = fishCfg.enable || shellCfg.default == "fish";

  neovimEnabled = config.myConfig.editors.neovim.enable;

  functions = import ./functions.nix { inherit lib fishCfg; };

  completionCommands =
    if shellCfg.shared.completions.enable then
      lib.unique (shellCfg.contrib.completionCommands ++ shellCfg.shared.completions.commands)
    else
      [ ];

  completionInit = lib.concatMapStringsSep "\n" (command: ''
    if type -q ${command}
      ${command} completion fish | source
    end
  '') completionCommands;

  editorInit = lib.optionalString (fishCfg.editor.enable && fishCfg.editor.nvim) ''
    # Set editor environment variables
    set -gx EDITOR nvim
    set -gx VISUAL nvim
  '';

  direnvInit = lib.optionalString fishCfg.direnv.enable ''
    # Initialize direnv for per-directory environment management
    direnv hook fish | source
  '';
in
{
  imports = [ ./options.nix ];

  config = lib.mkIf fishEnabled {
    # Smart defaults derived from other features; hosts can override.
    myConfig.shell.fish = {
      neovim.enable = lib.mkDefault neovimEnabled;
      editor.nvim = lib.mkDefault neovimEnabled;
      direnv.enable = lib.mkDefault true;

      functions = functions.fishFunctions;
      interactiveShellInit = lib.mkMerge [
        editorInit
        direnvInit
      ];
    };

    # POSIX scripts available in every shell.
    myConfig.shell.contrib.functions = functions.sharedFunctions;

    home.sessionVariables = lib.mkIf (fishCfg.editor.enable && fishCfg.editor.nvim) {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    home.packages = with pkgs; [
      fishPlugins.bass
      fishPlugins.done
    ];

    # home-manager's fish module force-enables `programs.man.generateCaches`
    # via `mkDefault true` to back `man <tab>` completion with `apropos`.
    # That rebuilds the man-db `whatis` index on every switch, which is slow
    # and noisy. Disable it; `man <name>` still works without the cache.
    programs.man.generateCaches = false;

    # Home Manager otherwise generates Fish completions from every installed
    # package's man pages. Keep native and explicitly configured completions,
    # but avoid fragile completion derivations such as age's.
    programs.fish.generateCompletions = false;

    programs.fish = {
      enable = true;
      shellAliases = shellCfg.resolved.aliases // fishCfg.aliases;
      inherit (fishCfg) functions;
      plugins = map (pkg: {
        name = pkg.pname;
        inherit (pkg) src;
      }) fishCfg.plugins;

      shellInit = ''
        ${fishCfg.shellInit}
      '';

      interactiveShellInit = ''
        ${shellCfg.contrib.fishInit}
        ${shellCfg.shared.fishInit}
        ${completionInit}


        # Source extra config files specified in configuration
        ${lib.concatMapStringsSep "\n" (file: ''
          if test -e "$HOME/${file}"
            source "$HOME/${file}"
          end
        '') fishCfg.extraConfigFiles}

        # Source local override file (convention-based)
        # This allows quick customizations without rebuilding
        if test -e "$HOME/.config/fish/local.fish"
          source "$HOME/.config/fish/local.fish"
        end

        ${fishCfg.interactiveShellInit}
      '';
    };
  };
}
