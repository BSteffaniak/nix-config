# Host discovery and configuration builders.
#
# Hosts are discovered from hosts/*/meta.nix. Each meta.nix declares:
#
#   {
#     type = "nixos" | "darwin" | "home-manager";
#     system = "x86_64-linux";          # Nix system identifier
#     hostname = "my-host";             # As reported by `hostname`
#     username = "braden";              # Primary user
#     stateVersion = "24.11";           # system.stateVersion (NixOS: "24.11", Darwin: 6)
#     homeStateVersion = "24.11";       # home.stateVersion
#     extraModules = [ "nix-minecraft" ];  # Optional named extras (see extraModuleMap)
#   }
#
# Usage from flake.nix:
#
#   hosts = import ./lib/hosts.nix { inherit inputs overlays; hostsDir = ./hosts; };
#   nixosConfigurations = hosts.nixosConfigurations;
#   ...
{
  inputs,
  # overlays : system -> [ overlay ]
  overlays,
  hostsDir,
}:
let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs) lib;

  myLib = import ./default.nix { inherit lib; };

  # ── Discovery ────────────────────────────────────────────────────
  hostDirs = builtins.readDir hostsDir;

  hostMeta = lib.filterAttrs (_: meta: meta != null) (
    lib.mapAttrs (
      name: kind:
      let
        metaFile = hostsDir + "/${name}/meta.nix";
      in
      if kind == "directory" && builtins.pathExists metaFile then import metaFile else null
    ) hostDirs
  );

  hostsOfType = type: lib.filterAttrs (_: meta: meta.type == type) hostMeta;

  # ── Optional named extras ────────────────────────────────────────
  # Each entry may provide platform modules and/or overlays. Referenced from
  # meta.extraModules by name so hosts never import flake inputs directly.
  extraModuleMap = {
    nix-minecraft = {
      nixosModules = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];
      overlays = [ inputs.nix-minecraft.overlay ];
    };
  };

  extrasFor =
    meta:
    let
      names = meta.extraModules or [ ];
      lookup =
        name:
        extraModuleMap.${name} or (throw "hosts.nix: unknown extraModules entry '${name}' in meta.nix");
      entries = map lookup names;
    in
    {
      nixosModules = lib.concatMap (e: e.nixosModules or [ ]) entries;
      darwinModules = lib.concatMap (e: e.darwinModules or [ ]) entries;
      overlays = lib.concatMap (e: e.overlays or [ ]) entries;
    };

  # ── Shared pieces ────────────────────────────────────────────────
  nixpkgsConfig = {
    allowUnfree = true;
    android_sdk.accept_license = true;
  };

  specialArgs = { inherit inputs myLib; };

  # Home Manager integration shared by NixOS and Darwin.
  # `bridge` is the platform-specific home module (home/nixos or home/darwin).
  mkHomeManagerModule =
    {
      name,
      meta,
      bridge,
    }:
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        extraSpecialArgs = specialArgs;
        sharedModules = [
          bridge
          { home.stateVersion = lib.mkDefault meta.homeStateVersion; }
        ];
        users.${meta.username}.imports = [ (hostsDir + "/${name}/home.nix") ];
      };
    };

  # Host identity derived from meta.nix; everything is mkDefault so a host
  # default.nix can still override.
  mkIdentityModule = meta: {
    myConfig.username = lib.mkDefault meta.username;
    networking.hostName = lib.mkDefault meta.hostname;
    system.stateVersion = lib.mkDefault meta.stateVersion;
  };

  # ── Builders ─────────────────────────────────────────────────────
  mkNixosHost =
    name: meta:
    let
      extras = extrasFor meta;
    in
    nixpkgs.lib.nixosSystem {
      inherit (meta) system;
      inherit specialArgs;
      modules = [
        (hostsDir + "/${name}")
        inputs.home-manager.nixosModules.home-manager
        (mkHomeManagerModule {
          inherit name meta;
          bridge = ../home/nixos;
        })
        (mkIdentityModule meta)
        {
          nixpkgs.config = nixpkgsConfig;
          nixpkgs.overlays = extras.overlays ++ overlays meta.system;
        }
      ]
      ++ extras.nixosModules;
    };

  mkDarwinHost =
    name: meta:
    let
      extras = extrasFor meta;
    in
    inputs.nix-darwin.lib.darwinSystem {
      inherit (meta) system;
      inherit specialArgs;
      modules = [
        (hostsDir + "/${name}")
        inputs.home-manager.darwinModules.home-manager
        inputs.nix-homebrew.darwinModules.nix-homebrew
        ../modules/darwin/nix-homebrew.nix
        (mkHomeManagerModule {
          inherit name meta;
          bridge = ../home/darwin;
        })
        (mkIdentityModule meta)
        (
          { config, ... }:
          {
            system.primaryUser = lib.mkDefault config.myConfig.username;
            # nix-darwin leaves users.users.<name>.home null; home-manager's
            # darwin module derives home.homeDirectory from it.
            users.users.${config.myConfig.username}.home = lib.mkDefault "/Users/${config.myConfig.username}";
          }
        )
        {
          nixpkgs.config = nixpkgsConfig;
          nixpkgs.overlays = extras.overlays ++ overlays meta.system;
        }
      ]
      ++ extras.darwinModules;
    };

  mkHomeHost =
    name: meta:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        inherit (meta) system;
        config = nixpkgsConfig;
        overlays = overlays meta.system;
      };
      extraSpecialArgs = specialArgs;
      modules = [
        ../home/standalone
        (hostsDir + "/${name}/home.nix")
        {
          home.username = lib.mkDefault meta.username;
          home.homeDirectory = lib.mkDefault "/home/${meta.username}";
          home.stateVersion = lib.mkDefault meta.homeStateVersion;
        }
      ];
    };
in
{
  inherit hostMeta myLib;

  nixosConfigurations = lib.mapAttrs mkNixosHost (hostsOfType "nixos");
  darwinConfigurations = lib.mapAttrs mkDarwinHost (hostsOfType "darwin");
  homeConfigurations = lib.mapAttrs' (
    name: meta: lib.nameValuePair "${meta.username}@${name}" (mkHomeHost name meta)
  ) (hostsOfType "home-manager");
}
