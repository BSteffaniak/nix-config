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

              # Match the Java 26.3 protocol used by the Geyser preview;
              # the locked nix-minecraft package still targets 26.3-rc-3.
              package = pkgs.paperServers.paper.override {
                version = "26.3-build.170";
                url = "https://fill-data.papermc.io/v1/objects/178a7bd115d8ab069af267bca2cba567d3d23036392762189846f35e97e35a17/paper-26.3-170.jar";
                sha256 = "178a7bd115d8ab069af267bca2cba567d3d23036392762189846f35e97e35a17";
              };

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
                ".FxyCorndog" = "00000000-0000-0000-0009-00000a47f6c1";
                ".Anastasia1651" = "00000000-0000-0000-0009-01ff5856cc0a";
                FxyCorndog = "8c082a64-336f-46ff-a9bb-3371d9ca3993";
                AnaElise = "bd8d65a5-7525-44d9-bbf1-22dc945d5702";
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
