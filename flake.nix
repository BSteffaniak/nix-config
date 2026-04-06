{
  description = "Unified Cross-Platform Nix Configuration";

  inputs = {
    # Core nixpkgs - shared base for all platforms
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Darwin uses darwin-specific branch for compatibility
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";

    # Home Manager - shared across all platforms
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Platform-specific frameworks
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # NixOS-specific inputs
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    swww.url = "github:LGFae/swww";

    # Darwin-specific inputs
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-aerospace = {
      url = "github:nikitabobko/homebrew-tap";
      flake = false;
    };
    homebrew-felixkratz = {
      url = "github:FelixKratz/homebrew-formulae";
      flake = false;
    };
    homebrew-linear = {
      url = "github:schpet/homebrew-tap";
      flake = false;
    };

    # Firefox on darwin (nixpkgs firefox is broken on macOS)
    nixpkgs-firefox-darwin = {
      url = "github:bandithedoge/nixpkgs-firefox-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Shared development tools and overlays
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Custom packages from source
    lspmux = {
      url = "git+https://codeberg.org/p2502/lspmux";
      flake = false;
    };
    zellij-fork = {
      url = "github:BSteffaniak/zellij/toggle-session";
      flake = false;
    };
    cronstrue = {
      url = "github:bradymholt/cronstrue";
      flake = false;
    };
    linear-cli-src = {
      url = "github:schpet/linear-cli";
      flake = false;
    };
    tone-clone-src = {
      url = "github:BSteffaniak/tone-clone";
      flake = false;
    };
    worktree-setup-src = {
      url = "github:BSteffaniak/worktree-setup";
      flake = false;
    };
    bmux-src = {
      url = "git+ssh://git@github.com/BSteffaniak/bmux";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-darwin,
      nixpkgs-unstable,
      home-manager,
      nix-darwin,
      nix-homebrew,
      homebrew-core,
      homebrew-cask,
      homebrew-aerospace,
      homebrew-felixkratz,
      ...
    }:
    let
      # ── Custom Library ────────────────────────────────────────────
      myLib = import ./lib { inherit (nixpkgs) lib; };

      # ── Host Discovery ───────────────────────────────────────────
      # Automatically discover all hosts from hosts/*/meta.nix.
      # Adding a new host requires only creating a directory under hosts/
      # with meta.nix, default.nix, and home.nix -- no flake.nix edits needed.
      hostDirs = builtins.readDir ./hosts;

      hostNames = builtins.filter (
        name: hostDirs.${name} == "directory" && builtins.pathExists (./hosts + "/${name}/meta.nix")
      ) (builtins.attrNames hostDirs);

      hostMeta = builtins.listToAttrs (
        map (name: {
          inherit name;
          value = import (./hosts + "/${name}/meta.nix");
        }) hostNames
      );

      # Partition hosts by type
      filterByType = type: nixpkgs.lib.filterAttrs (_name: meta: meta.type == type) hostMeta;

      nixosHosts = filterByType "nixos";
      darwinHosts = filterByType "darwin";
      hmHosts = filterByType "home-manager";

      # ── Overlays ─────────────────────────────────────────────────
      mkOverlays =
        system: nixpkgsLib:
        import ./lib/overlays.nix {
          inherit (nixpkgsLib) lib;
          inherit nixpkgs-unstable;
          # All flake inputs -- source-build auto-discovery looks up inputs by name
          flakeInputs = inputs;
          # Complex overlays that need explicit input wiring
          rust-overlay = inputs.rust-overlay;
          zellij-fork = inputs.zellij-fork;
          cronstrue-src = inputs.cronstrue;
          firefox-darwin = inputs.nixpkgs-firefox-darwin;
          enableRust = true;
          enableGithubReleases = true;
          enableSourceBuilds = true;
          enableZellijFork = true;
          enableCronstrue = true;
          enableFirefoxDarwin = true;
          enableMinecraftPlugins = true;
        };

      # ── Host Builders ────────────────────────────────────────────
      mkDarwinHost = import ./lib/mkDarwinHost.nix;
      mkNixosHost = import ./lib/mkNixosHost.nix;
      mkHomeConfig = import ./lib/mkHomeConfig.nix;
    in
    {
      # ── NixOS Configurations ─────────────────────────────────────
      nixosConfigurations = builtins.mapAttrs (
        name: meta:
        mkNixosHost {
          inherit
            name
            meta
            inputs
            mkOverlays
            myLib
            ;
        }
      ) nixosHosts;

      # ── Darwin (macOS) Configurations ────────────────────────────
      darwinConfigurations = builtins.mapAttrs (
        name: meta:
        mkDarwinHost {
          inherit
            name
            meta
            inputs
            mkOverlays
            myLib
            ;
        }
      ) darwinHosts;

      # ── Standalone Home-Manager Configurations ───────────────────
      homeConfigurations = builtins.listToAttrs (
        nixpkgs.lib.mapAttrsToList (name: meta: {
          name = "${meta.username}@${name}";
          value = mkHomeConfig {
            inherit
              name
              meta
              inputs
              mkOverlays
              myLib
              ;
          };
        }) hmHosts
      );

      # ── Dev Shell ────────────────────────────────────────────────
      # Provides tools for working on this nix config repo itself.
      # Activated automatically via .envrc + direnv.
      devShells =
        let
          forSystems = [
            "x86_64-linux"
            "aarch64-linux"
            "aarch64-darwin"
            "x86_64-darwin"
          ];
        in
        builtins.listToAttrs (
          map (system: {
            name = system;
            value.default =
              let
                pkgs = import nixpkgs { inherit system; };
              in
              pkgs.mkShell {
                packages = with pkgs; [
                  # Encryption (for private host configs)
                  git-crypt
                  gnupg

                  # Nix development
                  nixfmt-rfc-style # ./fmt.sh
                  nvd # ./rebuild.sh --diff
                  nix-diff # deep derivation diffing

                  # Formatting (non-nix files)
                  nodePackages.prettier # ./fmt.sh (markdown, yaml, json, etc.)

                  # Shell
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
              };
          }) forSystems
        );
    };
}
