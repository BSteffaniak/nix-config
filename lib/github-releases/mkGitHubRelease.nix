# mkGitHubRelease - Generic builder for GitHub release binaries
#
# Takes a per-project config and auto-generated version data, and produces
# a derivation that downloads and installs the pre-built binary.
#
# Usage in an overlay:
#   let
#     mkGitHubRelease = import ../github-releases/mkGitHubRelease.nix { pkgs = final; };
#     config = builtins.fromJSON (builtins.readFile ../github-releases/configs/foo.json);
#     versionData = builtins.fromJSON (builtins.readFile ../github-releases/versions/foo.json);
#   in
#   mkGitHubRelease { inherit config versionData; }
#
{ pkgs }:

{ config, versionData }:

let
  system = pkgs.stdenv.hostPlatform.system;

  platformData =
    versionData.platforms.${system}
      or (throw "Unsupported platform '${system}' for ${config.pname}. Available: ${builtins.concatStringsSep ", " (builtins.attrNames versionData.platforms)}");

  isTarGz = pkgs.lib.hasSuffix ".tar.gz" platformData.url;
  isZip = pkgs.lib.hasSuffix ".zip" platformData.url;

  binaryName = config.binaryName or config.pname;
  installedBinaryName = config.installedBinaryName or config.pname;

  # Map license string to nixpkgs license attribute
  licenseMap = {
    "mit" = pkgs.lib.licenses.mit;
    "asl20" = pkgs.lib.licenses.asl20;
    "bsd2" = pkgs.lib.licenses.bsd2;
    "bsd3" = pkgs.lib.licenses.bsd3;
    "gpl2" = pkgs.lib.licenses.gpl2;
    "gpl3" = pkgs.lib.licenses.gpl3;
    "lgpl21" = pkgs.lib.licenses.lgpl21;
    "lgpl3" = pkgs.lib.licenses.lgpl3;
    "mpl20" = pkgs.lib.licenses.mpl20;
    "isc" = pkgs.lib.licenses.isc;
    "unlicense" = pkgs.lib.licenses.unlicense;
    "unfree" = pkgs.lib.licenses.unfree;
  };

  license = licenseMap.${config.meta.license or "unfree"} or pkgs.lib.licenses.unfree;

in
pkgs.stdenv.mkDerivation {
  pname = config.pname;
  version = versionData.version;

  src = pkgs.fetchurl {
    url = platformData.url;
    sha256 = platformData.sha256;
  };

  nativeBuildInputs =
    (if isZip then [ pkgs.unzip ] else [ ])
    ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
      pkgs.autoPatchelfHook
    ];

  buildInputs = pkgs.lib.optionals pkgs.stdenv.isLinux [
    pkgs.stdenv.cc.cc.lib
  ];

  unpackPhase =
    if isTarGz then
      ''
        tar xzf $src
      ''
    else if isZip then
      ''
        unzip $src
      ''
    else
      throw "Unsupported archive format for ${platformData.url}";

  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    mkdir -p $out/bin

    # Search common locations for the binary
    if [ -f "${binaryName}" ]; then
      cp "${binaryName}" "$out/bin/${installedBinaryName}"
    elif [ -f "bin/${binaryName}" ]; then
      cp "bin/${binaryName}" "$out/bin/${installedBinaryName}"
    elif [ -f */"${binaryName}" ]; then
      cp */"${binaryName}" "$out/bin/${installedBinaryName}"
    else
      echo "Error: Could not find '${binaryName}' binary in extracted archive"
      echo "Archive contents:"
      find . -type f | head -50
      exit 1
    fi

    chmod +x "$out/bin/${installedBinaryName}"
  '';

  meta = {
    description = config.meta.description or "${config.pname} (from GitHub releases)";
    homepage = config.meta.homepage or "https://github.com/${config.owner}/${config.repo}";
    inherit license;
    platforms = builtins.attrNames versionData.platforms;
    mainProgram = installedBinaryName;
  };
}
