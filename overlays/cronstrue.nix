# cronstrue CLI built from source with npm.
# Hash managed by: ./scripts/source-build.sh update cronstrue
{ inputs }:
final: prev:
let
  source = import ../lib/locked-source.nix { inherit (prev) lib; } {
    inherit inputs;
    inputName = "cronstrue-src";
    hashFile = ../pkgs/source-builds/hashes/cronstrue.json;
    updateCommand = "./scripts/source-build.sh update cronstrue";
  };
in
if source == null then
  { }
else
  let
    narHashShort = if source.narHash != "" then builtins.substring 7 8 source.narHash else "unknown";
  in
  {
    cronstrue-custom = final.buildNpmPackage {
      pname = "cronstrue";
      version = "${source.ref}-${narHashShort}-${source.shortRev}";

      inherit (source) src;

      npmDepsHash = source.hashes.npmDepsHash;
      npmFlags = [ "--legacy-peer-deps" ];

      buildPhase = ''
        runHook preBuild
        npm run build
        npx webpack
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        mkdir -p $out/bin
        mkdir -p $out/lib/node_modules/cronstrue

        cp -r dist $out/lib/node_modules/cronstrue/
        cp -r locales $out/lib/node_modules/cronstrue/
        cp -r bin $out/lib/node_modules/cronstrue/
        cp package.json $out/lib/node_modules/cronstrue/
        cp i18n.js $out/lib/node_modules/cronstrue/
        cp i18n.d.ts $out/lib/node_modules/cronstrue/

        chmod +x $out/lib/node_modules/cronstrue/bin/cli.js
        ln -s $out/lib/node_modules/cronstrue/bin/cli.js $out/bin/cronstrue

        runHook postInstall
      '';

      meta = with final.lib; {
        description = "JavaScript library that translates Cron expressions into human readable descriptions";
        homepage = "https://github.com/bradymholt/cronstrue";
        license = licenses.mit;
        mainProgram = "cronstrue";
        maintainers = [ ];
        platforms = platforms.all;
      };
    };
  }
