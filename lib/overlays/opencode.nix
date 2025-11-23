# Auto-discovered overlay for OpenCode
# Enable with: enableOpencode = true
{
  inputs,
  enable ? true,
  mkGitInput ? null,
}:
if !enable then
  [ ]
else
  let
    opencode-release-info = inputs.opencode-release-info or null;
  in
  if opencode-release-info == null then
    [ ]
  else
    [
      (final: prev: {
        opencode-dev =
          let
            # Parse the GitHub API release JSON
            releaseData = builtins.fromJSON (builtins.readFile opencode-release-info);
            version = builtins.replaceStrings [ "v" ] [ "" ] releaseData.tag_name;

            # Map Nix system to GitHub release asset names
            platformAssetMap = {
              x86_64-linux = "opencode-linux-x64.tar.gz";
              aarch64-linux = "opencode-linux-arm64.tar.gz";
              x86_64-darwin = "opencode-darwin-x64.zip";
              aarch64-darwin = "opencode-darwin-arm64.zip";
            };

            assetName =
              platformAssetMap.${final.stdenv.system} or (throw "Unsupported platform: ${final.stdenv.system}");

            # Find the matching asset in the release
            matchingAssets = builtins.filter (asset: asset.name == assetName) releaseData.assets;

            asset =
              if builtins.length matchingAssets > 0 then
                builtins.head matchingAssets
              else
                throw "Asset ${assetName} not found in release ${releaseData.tag_name}";

            # Extract sha256 from "sha256:xxxxx" format
            sha256Hash = builtins.replaceStrings [ "sha256:" ] [ "" ] asset.digest;

            # Determine if this is a tar.gz or zip archive
            isTarGz = final.lib.hasSuffix ".tar.gz" assetName;

          in
          final.stdenv.mkDerivation {
            pname = "opencode-dev";
            inherit version;

            src = final.fetchurl {
              url = asset.browser_download_url;
              sha256 = sha256Hash;
            };

            nativeBuildInputs =
              (if isTarGz then [ ] else [ final.unzip ])
              ++ final.lib.optionals final.stdenv.isLinux [
                final.autoPatchelfHook
              ];

            buildInputs = final.lib.optionals final.stdenv.isLinux [
              final.stdenv.cc.cc.lib
            ];

            unpackPhase = if isTarGz then ''
              tar xzf $src
            '' else ''
              unzip $src
            '';

            dontBuild = true;
            dontStrip = true;

            installPhase = ''
              mkdir -p $out/bin

              # Find the opencode binary in the extracted zip
              if [ -f opencode ]; then
                cp opencode $out/bin/opencode-dev
              elif [ -f bin/opencode ]; then
                cp bin/opencode $out/bin/opencode-dev
              elif [ -f */opencode ]; then
                cp */opencode $out/bin/opencode-dev
              else
                echo "Error: Could not find opencode binary in extracted archive"
                echo "Archive contents:"
                ls -la
                find . -name "opencode*" -o -name "*.exe"
                exit 1
              fi

              chmod +x $out/bin/opencode-dev
            '';

            meta = with final.lib; {
              description = "OpenCode CLI (latest from GitHub releases)";
              homepage = "https://github.com/sst/opencode";
              license = licenses.mit;
              platforms = [
                "x86_64-linux"
                "aarch64-linux"
                "x86_64-darwin"
                "aarch64-darwin"
              ];
              mainProgram = "opencode-dev";
            };
          };
      })
    ]
