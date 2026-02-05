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

    # Shared development tools and overlays
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Custom packages from source
    ra-multiplex = {
      url = "github:pr2502/ra-multiplex";
      flake = false;
    };
    opencode-release-info = {
      url = "https://api.github.com/repos/sst/opencode/releases/latest";
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
      # Helper to create overlays for any system
      # Uses single flake.lock at root
      mkOverlays =
        system: nixpkgsLib:
        import ./lib/overlays.nix {
          inherit (nixpkgsLib) lib;
          inherit nixpkgs-unstable;
          ra-multiplex-src = inputs.ra-multiplex;
          rust-overlay = inputs.rust-overlay;
          opencode-release-info = inputs.opencode-release-info;
          zellij-fork = inputs.zellij-fork;
          cronstrue-src = inputs.cronstrue;
          # Enable all overlays by default
          enableRust = true;
          enableOpencode = true;
          enableRaMultiplex = true;
          enableZellijFork = true;
          enableCronstrue = true;
        };
    in
    {
      # ============================================================
      # NixOS Configurations
      # ============================================================
      nixosConfigurations = {
        nixos-desktop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/nixos-desktop
            home-manager.nixosModules.home-manager
            {
              nixpkgs.config = {
                allowUnfree = true;
                android_sdk.accept_license = true;
              };
              nixpkgs.overlays = [
                inputs.nix-minecraft.overlay
              ]
              ++ (mkOverlays "x86_64-linux" nixpkgs);
            }
            (
              { config, ... }:
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  backupFileExtension = "backup";
                  users.braden = {
                    imports = [
                      ./home/nixos
                      ./hosts/nixos-desktop/home.nix
                    ];
                  };
                  extraSpecialArgs = {
                    inherit inputs;
                    osConfig = config;
                  };
                };
              }
            )
          ];
        };
      };

      # ============================================================
      # Darwin (macOS) Configurations
      # ============================================================
      darwinConfigurations = {
        macbook-air = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/macbook-air
            home-manager.darwinModules.home-manager
            nix-homebrew.darwinModules.nix-homebrew
            {
              nixpkgs.config = {
                allowUnfree = true;
                android_sdk.accept_license = true;
              };
              nixpkgs.overlays = mkOverlays "aarch64-darwin" nixpkgs-darwin;
            }
            (
              { config, ... }:
              let
                username = config.myConfig.username;
              in
              {
                nix-homebrew = {
                  enable = true;
                  enableRosetta = true;
                  user = username;
                  taps = {
                    "homebrew/homebrew-core" = homebrew-core;
                    "homebrew/homebrew-cask" = homebrew-cask;
                    "nikitabobko/homebrew-tap" = homebrew-aerospace;
                    "FelixKratz/homebrew-formulae" = homebrew-felixkratz;
                  };
                  mutableTaps = false;
                };

                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  backupFileExtension = "backup";
                  users.${username} = {
                    imports = [
                      ./home/darwin
                      ./hosts/macbook-air/home.nix
                    ];
                  };
                  extraSpecialArgs = {
                    inherit inputs;
                    osConfig = config;
                  };
                };

                homebrew.taps = builtins.attrNames config.nix-homebrew.taps;
              }
            )
          ];
        };

        mac-studio = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/mac-studio
            home-manager.darwinModules.home-manager
            nix-homebrew.darwinModules.nix-homebrew
            {
              nixpkgs.config = {
                allowUnfree = true;
                android_sdk.accept_license = true;
              };
              nixpkgs.overlays = mkOverlays "aarch64-darwin" nixpkgs-darwin;
            }
            (
              { config, ... }:
              let
                username = config.myConfig.username;
              in
              {
                nix-homebrew = {
                  enable = true;
                  enableRosetta = true;
                  user = username;
                  taps = {
                    "homebrew/homebrew-core" = homebrew-core;
                    "homebrew/homebrew-cask" = homebrew-cask;
                    "nikitabobko/homebrew-tap" = homebrew-aerospace;
                    "FelixKratz/homebrew-formulae" = homebrew-felixkratz;
                  };
                  mutableTaps = false;
                };

                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  backupFileExtension = "backup";
                  users.${username} = {
                    imports = [
                      ./home/darwin
                      ./hosts/mac-studio/home.nix
                    ];
                  };
                  extraSpecialArgs = {
                    inherit inputs;
                    osConfig = config;
                  };
                };

                homebrew.taps = builtins.attrNames config.nix-homebrew.taps;
              }
            )
          ];
        };
      };

      # ============================================================
      # Standalone Home-Manager Configurations (Ubuntu, etc.)
      # ============================================================
      homeConfigurations = {
        "braden@ubuntu-laptop" = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            config.allowUnfree = true;
            overlays = mkOverlays "x86_64-linux" nixpkgs;
          };
          modules = [
            ./hosts/ubuntu-laptop/home.nix
          ];
          extraSpecialArgs = {
            inherit inputs;
          };
        };
      };
    };
}
