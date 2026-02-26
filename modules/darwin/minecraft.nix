{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.darwin.minecraft;

  dataDir = "minecraft-server";

  plugins = {
    geyserMC = pkgs.fetchurl {
      url = "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot";
      hash = "sha256-1w5Iy8DkpbQds1Ha6r+rOQGJ/KVit3PmIBJvhNqOWGE=";
    };
    floodgate = pkgs.fetchurl {
      url = "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot";
      hash = "sha256-AelUlBDvIOJk75r2tDxp89HPJOl1b/9mc4KgScPKjTk=";
    };
    viaVersion = pkgs.fetchurl {
      url = "https://github.com/ViaVersion/ViaVersion/releases/tag/5.4.2/download/ViaVersion-5.4.2.jar";
      hash = "sha256-i/wiKjWnaMQjNZ8VByNtrbPD80WRWRueIMoSOCWN8TU=";
    };
  };

  serverPackage = pkgs.paperServers.paper;

  minecraft-server-start = pkgs.writeShellScriptBin "minecraft-server-start" ''
    SERVER_DIR="$HOME/${dataDir}"
    PLUGINS_DIR="$SERVER_DIR/plugins"

    # Create directories
    mkdir -p "$PLUGINS_DIR"

    # Accept EULA
    echo "eula=true" > "$SERVER_DIR/eula.txt"

    # Symlink plugins (force-overwrite to stay declarative)
    ln -sf "${plugins.geyserMC}" "$PLUGINS_DIR/GeyserMC.jar"
    ln -sf "${plugins.floodgate}" "$PLUGINS_DIR/Floodgate.jar"
    ln -sf "${plugins.viaVersion}" "$PLUGINS_DIR/ViaVersion.jar"

    echo "Starting Minecraft Paper server in $SERVER_DIR..."
    echo "  Java clients:   localhost:25565"
    echo "  Bedrock clients: localhost:19132"
    echo ""

    cd "$SERVER_DIR"
    exec ${serverPackage}/bin/minecraft-server -Xms4G -Xmx8G
  '';
in
{
  options.myConfig.darwin.minecraft = {
    enable = mkEnableOption "Minecraft Paper server with Bedrock crossplay (GeyserMC + Floodgate + ViaVersion)";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      serverPackage
      minecraft-server-start
    ];
  };
}
