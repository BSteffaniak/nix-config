# Personal home-manager overrides for mac-studio host
# Contains personal preferences and should not be copied when bootstrapping new hosts
{
  config,
  lib,
  pkgs,
  ...
}:

let
  externalTmp = "/Volumes/ehdd/tmp/${config.home.username}";
  # Run at shell startup, not evaluation/activation: the drive may be absent.
  selectTmp = pkgs.writeShellScript "mac-studio-select-tmp" ''
    set -eu
    volume=/Volumes/ehdd
    info=$(/usr/sbin/diskutil info -plist "$volume" 2>/dev/null) || info=""
    uuid=$(printf '%s' "$info" | /usr/bin/plutil -extract VolumeUUID raw -o - - 2>/dev/null) || uuid=""
    mountpoint=$(printf '%s' "$info" | /usr/bin/plutil -extract MountPoint raw -o - - 2>/dev/null) || mountpoint=""
    ownership=$(printf '%s' "$info" | /usr/bin/plutil -extract GlobalPermissionsEnabled raw -o - - 2>/dev/null) || ownership=""
    if [ "$uuid" = 97676AC9-C0F3-47E3-93C2-F12D10243564 ] && \
       [ "$mountpoint" = "$volume" ] && [ "$ownership" = true ] && \
       [ ! -L "$volume/tmp" ] && [ ! -L ${lib.escapeShellArg externalTmp} ] && \
       [ -d ${lib.escapeShellArg externalTmp} ] && [ -w ${lib.escapeShellArg externalTmp} ] && \
       [ "$(/usr/bin/stat -f '%u:%Lp' ${lib.escapeShellArg externalTmp})" = "$(/usr/bin/id -u):700" ]; then
      printf '%s/\n' ${lib.escapeShellArg externalTmp}
    else
      /usr/bin/getconf DARWIN_USER_TEMP_DIR
    fi
  '';
in
{
  # Applies to new shells and their children, not Finder apps or the Nix daemon.
  myConfig.shell.shared = {
    bashInit = ''
      export TMPDIR="$(${selectTmp})"
    '';
    zshInit = ''
      export TMPDIR="$(${selectTmp})"
    '';
    fishInit = ''
      set -gx TMPDIR (${selectTmp})
    '';
    nushellEnv = ''
      $env.TMPDIR = (${selectTmp} | str trim)
    '';
  };

  # Fish shell - feature-based configuration
  myConfig.shell.fish = {
    # Zellij
    zellij = {
      enable = true;
      resurrect = true;
    };
  };

  myConfig = {
    # Desktop - AeroSpace tiling window manager
    desktop.aerospace.enable = true;
    desktop.sketchybar.enable = true;
    desktop.hex.enable = true;
    desktop.mkalias.enable = true;
    desktop.sledge.enable = true;
    desktop.wallpaper.enable = true;

    # CLI tools - now configured directly in home-manager
    cliTools = {
      terminals.bmux.enable = true;
      terminals.ghostty = {
        enable = true;
        hideWindowDecoration = true;
      };
      terminals.zellij.enable = true;
      terminals.tmux.enable = true;

      monitoring.bottom.enable = true;
      monitoring.htop.enable = true;
      monitoring.ncdu.enable = true;

      fileTools.fzf.enable = true;
      fileTools.ripgrep.enable = true;
      fileTools.fd.enable = true;
      fileTools.unzip.enable = true;
      fileTools.zip.enable = true;

      formatters.nixfmt.enable = true;
      formatters.eslint.enable = true;
      formatters.prettier.enable = true;
      formatters.taplo.enable = true;

      utilities.direnv.enable = true;
      utilities.jq.enable = true;
      utilities.parallel.enable = true;
      utilities.writeGood.enable = true;
      utilities.cronstrue.enable = true;
      utilities.cloc.enable = true;
      utilities.watchexec.enable = true;
      utilities.lsof.enable = true;
      utilities.killall.enable = true;
      utilities.nixSearch.enable = true;
      utilities.media.ffmpeg.enable = true;
      utilities.media.flac.enable = true;
      utilities.media.mediainfo.enable = true;
      utilities.opencodeUpstream.enable = true;
      utilities.sshenv.enable = true;
      utilities.clippier.enable = true;
      utilities.worktreeSetup.enable = true;
    };

    # Development environments
    development.nodejs.enable = true;
    development.go.enable = true;
    development.python.enable = true;
    development.android.enable = true;
    development.java.enable = true;
    development.openssl.enable = true;

    # Containers and DevOps
    containers.podman.enable = true;
    containers.tools.enable = true;
    devops.kubernetes.enable = true;
    devops.cloud.enable = true;
    devops.infrastructure.enable = true;

    # Editors
    editors.neovim.enable = true;
    editors.neovim.useNightly = true;

    # Development tool configs
    development.rust.enable = true;
    development.bcode.enable = true;
    development.lazygit.enable = true;
    development.act.enable = true;
    development.opencode.enable = true;
    development.opencode.aliases.openai-api = {
      provider = "openai";
      sshenvProfile = "openai-api";
      ignorePersistedAuth = true;
    };
    development.opencode.aliases.openai-api-fast = {
      provider = "openai-fast";
      sshenvProfile = "openai-api";
      ignorePersistedAuth = true;
    };
    development.opencode.aliases.openrouter = {
      provider = "openrouter";
      sshenvProfile = "openrouter";
      ignorePersistedAuth = true;
    };
    development.opencode.aliases.grok-4-6 = {
      provider = "grok-4.6";
      sshenvProfile = "xai";
      ignorePersistedAuth = true;
    };
    development.opencode.aliases.grok-code-fast = {
      provider = "grok-code-fast";
      sshenvProfile = "xai";
      ignorePersistedAuth = true;
    };
    development.agents.permissions.restricted = [
      "git"
      "brew"
    ];
    development.brouter = {
      enable = true;
      makePiDefault = true;
      openaiMax.enable = true;
      openrouter.enable = true;
      opencodeZen.enable = true;
    };
    development.pi.enable = true;
    development.lspmux.enable = true;

    # DevOps tool configs
    devops.github.enable = true;

    shell.git.enable = true;
    shell.ssh = {
      enable = true;
      matchBlocks = {
        "github.com" = {
          user = "git";
          identityFile = "~/.ssh/github_rsa";
        };
      };
    };

    # Tools
    tools = {
      archiving.enable = true;
      encryption.enable = true;
      ai.claudeCode.enable = true;
      ai.ollama = {
        enable = true;
        model = "qwen3:30b-a3b";
        extraModels = [ "qwen3:14b" ];
        # Keep Ollama available without downloading models during activation.
        modelsToPull = [ ];
      };
      tts.piper.enable = true;
    };
  };

  home.packages = with pkgs; [
    discord
  ];
}
