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
    geyserMC = pkgs.minecraftPlugins.geysermc;
    floodgate = pkgs.minecraftPlugins.floodgate;
    viaVersion = pkgs.minecraftPlugins.viaversion;
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
