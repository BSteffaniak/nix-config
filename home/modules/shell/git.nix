# Git configuration.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.shell.git;
in
{
  options.myConfig.shell.git = {
    enable = lib.mkEnableOption "Git configuration";

    userName = lib.mkOption {
      type = lib.types.str;
      default = "Braden Steffaniak";
      description = "Git user name";
    };

    userEmail = lib.mkOption {
      type = lib.types.str;
      default = "BradenSteffaniak@gmail.com";
      description = "Git user email";
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.attrsOf (
          lib.types.oneOf [
            lib.types.str
            lib.types.bool
            lib.types.int
          ]
        )
      );
      default = {
        pull.rebase = true;
        core.autocrlf = "input";
        push.default = "upstream";
        rerere.enabled = true;
      };
      description = "Additional git configuration";
      example = lib.literalExpression ''
        {
          pull.rebase = true;
          core.autocrlf = "input";
          init.defaultBranch = "main";
          commit.gpgsign = true;
        }
      '';
    };

    aliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        set-master = "branch --set-upstream-to=origin/master";
      };
      description = "Git aliases";
      example = lib.literalExpression ''
        {
          co = "checkout";
          br = "branch";
          st = "status";
          lg = "log --graph --oneline --decorate";
        }
      '';
    };

    signing = {
      key = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "GPG key ID for signing commits";
      };

      signByDefault = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to sign commits by default";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      hooks = {
        post-commit = pkgs.writeShellScript "post-commit" ''
          # Clean up any leftover PREPARED_MSG after successful commit
          # (e.g. when committing via lazygit, the prepare-commit-msg hook
          # doesn't consume it because SOURCE="message")
          GIT_DIR="$(git rev-parse --git-dir)"
          rm -f "$GIT_DIR/PREPARED_MSG"

          # Existing post-commit logic: work-hours commit date adjuster
          BINARY="$HOME/.config/git/hooks/post-commit/target/release/post-commit"
          if [ -x "$BINARY" ]; then
              "$BINARY"
          fi
        '';
        prepare-commit-msg = pkgs.writeShellScript "prepare-commit-msg" ''
          MSGFILE="$1"
          SOURCE="$2"
          GIT_DIR="$(git rev-parse --git-dir)"
          PREPARED="$GIT_DIR/PREPARED_MSG"

          # Only inject on plain `git commit` (no -m, --amend, merge, etc.)
          if [ -z "$SOURCE" ] && [ -f "$PREPARED" ]; then
            EXISTING=$(cat "$MSGFILE")
            printf '%s\n\n%s\n' "$(cat "$PREPARED")" "$EXISTING" > "$MSGFILE"
            rm "$PREPARED"
            rm -f "$GIT_DIR/LAZYGIT_PENDING_COMMIT"
          fi
        '';
      };
      settings = {
        user = {
          name = cfg.userName;
          email = cfg.userEmail;
        };
        alias = cfg.aliases;
      }
      // cfg.extraConfig;
      signing = lib.mkIf (cfg.signing.key != null) {
        inherit (cfg.signing) key signByDefault;
      };
    };
  };
}
