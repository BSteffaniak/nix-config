{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  options.homeModules.git = {
    enable = mkEnableOption "Git configuration";

    userName = mkOption {
      type = types.str;
      default = "Braden Steffaniak";
      description = "Git user name";
    };

    userEmail = mkOption {
      type = types.str;
      default = "BradenSteffaniak@gmail.com";
      description = "Git user email";
    };

    extraConfig = mkOption {
      type = types.attrs;
      default = {
        pull.rebase = true;
        core.autocrlf = "input";
        push.default = "upstream";
      };
      description = "Additional git configuration";
      example = literalExpression ''
        {
          pull.rebase = true;
          core.autocrlf = "input";
          init.defaultBranch = "main";
          commit.gpgsign = true;
        }
      '';
    };

    aliases = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Git aliases";
      example = literalExpression ''
        {
          co = "checkout";
          br = "branch";
          st = "status";
          lg = "log --graph --oneline --decorate";
        }
      '';
    };

    signing = {
      key = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "GPG key ID for signing commits";
      };

      signByDefault = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to sign commits by default";
      };
    };
  };

  config = mkIf config.homeModules.git.enable {
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
          name = config.homeModules.git.userName;
          email = config.homeModules.git.userEmail;
        };
        alias = config.homeModules.git.aliases;
      }
      // config.homeModules.git.extraConfig;
      signing = mkIf (config.homeModules.git.signing.key != null) {
        key = config.homeModules.git.signing.key;
        signByDefault = config.homeModules.git.signing.signByDefault;
      };
    };
  };
}
