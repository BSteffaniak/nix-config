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
    brew-src = {
      url = "github:Homebrew/brew/5.1.7";
      flake = false;
    };
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      inputs.brew-src.follows = "brew-src";
    };
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
    lspmux-src = {
      url = "git+https://codeberg.org/p2502/lspmux";
      flake = false;
    };
    cronstrue-src = {
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
    sendsafely-java-src = {
      url = "github:BSteffaniak/sendsafely-java";
      flake = false;
    };
    worktree-setup-src = {
      url = "github:BSteffaniak/worktree-setup";
      flake = false;
    };
    clippier-src = {
      url = "github:MoosicBox/MoosicBox";
      flake = false;
    };
    bmux-src = {
      url = "git+ssh://git@github.com/BSteffaniak/bmux";
      flake = false;
    };
    bcode-src = {
      url = "git+ssh://git@github.com/BSteffaniak/bcode";
      flake = false;
    };
    sshenv-src = {
      url = "github:BSteffaniak/sshenv";
      flake = false;
    };
    sledge-src = {
      url = "github:BSteffaniak/sledge";
      flake = false;
    };
    brouter-src = {
      url = "github:BSteffaniak/brouter";
      flake = false;
    };
    git-sshripped-src = {
      url = "github:BSteffaniak/git-sshripped";
      flake = false;
    };
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;

      # nixpkgs tree used for a given system. Darwin follows the darwin-gated
      # stable channel; everything else uses nixos-<release>.
      nixpkgsFor = system: if lib.hasSuffix "-darwin" system then inputs.nixpkgs-darwin else nixpkgs;

      # system -> [ overlay ]
      overlays = system: import ./overlays { inherit inputs; };

      hosts = import ./lib/hosts.nix {
        inherit inputs overlays;
        hostsDir = ./hosts;
      };

      forAllSystems = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      pkgsFor =
        system:
        import (nixpkgsFor system) {
          inherit system;
          overlays = overlays system;
        };
    in
    {
      inherit (hosts) nixosConfigurations darwinConfigurations homeConfigurations;

      devShells = forAllSystems (system: {
        default = import ./lib/dev-shell.nix { pkgs = pkgsFor system; };
      });

      formatter = forAllSystems (system: (pkgsFor system).nixfmt-rfc-style);

      # `nix flake check` evaluates every host's toplevel. Cross-platform
      # hosts are exposed under every system so a single machine can check
      # the whole fleet without building.
      checks = forAllSystems (
        _system:
        lib.mapAttrs' (
          name: cfg: lib.nameValuePair "nixos-${name}" cfg.config.system.build.toplevel
        ) hosts.nixosConfigurations
        // lib.mapAttrs' (
          name: cfg: lib.nameValuePair "darwin-${name}" cfg.config.system.build.toplevel
        ) hosts.darwinConfigurations
        // lib.mapAttrs' (
          name: cfg:
          lib.nameValuePair "home-${builtins.replaceStrings [ "@" ] [ "-" ] name}" cfg.activationPackage
        ) hosts.homeConfigurations
      );
    };
}
