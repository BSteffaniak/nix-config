{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;

let
  plugins = {
    geyserMC = pkgs.minecraftPlugins.geysermc;
    floodgate = pkgs.minecraftPlugins.floodgate;
    viaVersion = pkgs.minecraftPlugins.viaversion;
  };
in
{
  options.myConfig.services.minecraft = {
    enable = mkEnableOption "Minecraft server";
  };

  config = mkIf config.myConfig.services.minecraft.enable {
    environment.systemPackages =
      with pkgs;
      [ ]
      ++ lib.optionals pkgs.stdenv.isLinux [
        prismlauncher
      ];

    services.minecraft-servers = {
      enable = true;
      eula = true;
      openFirewall = true;
      servers = {
        greenfield = {
          enable = true;
          autoStart = false;

          # Use Paper server
          package = pkgs.paperServers.paper;

          serverProperties = {
            server-port = 25565;
            max-players = 20;
            view-distance = 10;
            simulation-distance = 10;
            enable-command-block = true;
            motd = "Greenfield - Java & Bedrock Crossplay";
            resource-pack-required = true;
          };

          whitelist = {
            # Your whitelist entries here
          };

          symlinks = {
            "plugins/GeyserMC.jar" = plugins.geyserMC;
            "plugins/Floodgate.jar" = plugins.floodgate;
            "plugins/ViaVersion.jar" = plugins.viaVersion;
          };
        };
      };
    };

    # Open Bedrock port
    networking.firewall.allowedUDPPorts = [ 19132 ];
  };
}
