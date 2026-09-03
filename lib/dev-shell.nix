# Development shell for working on this repository.
# Activated automatically via .envrc + direnv.
{ pkgs }:
pkgs.mkShell {
  packages = with pkgs; [
    # Encryption (for private host configs)
    git-sshripped

    # Nix development
    nixfmt-rfc-style # ./fmt.sh
    nvd # ./rebuild.sh --diff
    nix-diff # deep derivation diffing (scripts/check-all-hosts.sh)

    # Formatting (non-nix files)
    nodePackages.prettier # ./fmt.sh (markdown, yaml, json, etc.)

    # Shells (for the interactive handoff below)
    fish
    zsh
    nushell
  ];

  shellHook = ''
    # Optional interactive shell handoff.
    # Priority:
    # 1) NIX_DEV_SHELL_PREFERRED override
    # 2) Detect parent shell from process tree
    # 3) Fallback to $SHELL
    preferred_shell="''${NIX_DEV_SHELL_PREFERRED:-}"

    detect_parent_shell() {
      pid="$PPID"
      depth=0
      while [ -n "$pid" ] && [ "$pid" -gt 1 ] && [ "$depth" -lt 8 ]; do
        cmd="$(ps -o comm= -p "$pid" 2>/dev/null | tr -d '[:space:]')"
        name="$(basename "$cmd")"
        case "$name" in
          -*) name="$(printf "%s" "$name" | sed 's/^-//')" ;;
        esac

        case "$name" in
          fish|bash|zsh|nu|nushell)
            printf "%s" "$name"
            return 0
            ;;
        esac

        pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d '[:space:]')"
        depth=$((depth + 1))
      done
      return 1
    }

    if [ -z "$preferred_shell" ]; then
      preferred_shell="$(detect_parent_shell || true)"
    fi

    if [ -z "$preferred_shell" ] && [ -n "$SHELL" ]; then
      preferred_shell="$(basename "$SHELL")"
      case "$preferred_shell" in
        -*) preferred_shell="$(printf "%s" "$preferred_shell" | sed 's/^-//')" ;;
      esac
    fi

    if [ "$preferred_shell" = "nushell" ]; then
      preferred_shell="nu"
    fi

    case "$preferred_shell" in
      fish|zsh|nu) ;;
      bash|"") preferred_shell="" ;;
      *) preferred_shell="" ;;
    esac

    if [ -n "$preferred_shell" ] && [ -z "$IN_NIX_DEV_SHELL_EXEC" ] && [ -z "$BASH_EXECUTION_STRING" ]; then
      case "$-" in
        *i*)
          if command -v "$preferred_shell" >/dev/null 2>&1; then
            export IN_NIX_DEV_SHELL_EXEC=1
            exec "$preferred_shell"
          fi
          ;;
      esac
    fi
  '';
}
