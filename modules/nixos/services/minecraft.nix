{
  config,
  lib,
  options,
  pkgs,
  ...
}:

let
  plugins = {
    geyserMC = pkgs.minecraftPlugins.geysermc;
    floodgate = pkgs.minecraftPlugins.floodgate;
    viaVersion = pkgs.minecraftPlugins.viaversion;
  };
in
{
  options.myConfig.services.minecraft = {
    enable = lib.mkEnableOption "Minecraft server (requires `extraModules = [ \"nix-minecraft\" ]` in meta.nix)";
  };

  config = lib.mkIf config.myConfig.services.minecraft.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = options ? services.minecraft-servers;
            message = "myConfig.services.minecraft requires \"nix-minecraft\" in this host's meta.nix extraModules.";
          }
        ];

        environment.systemPackages = lib.optionals pkgs.stdenv.isLinux [ pkgs.prismlauncher ];

        # Open Bedrock port
        networking.firewall.allowedUDPPorts = [ 19132 ];
      }

      # Only define the option path when the nix-minecraft module is loaded;
      # otherwise the module system errors before the assertion can fire.
      (lib.optionalAttrs (options ? services.minecraft-servers) {
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
      })
    ]
  );
}
