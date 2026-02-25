# Overlay for cronstrue
# Enable with: enableCronstrue = true
#
# Dependency hash managed by: ./scripts/source-build.sh update cronstrue
# Hash file: lib/source-builds/hashes/cronstrue.json
{
  inputs,
  enable ? true,
  mkGitInput ? null,
}:
if !enable then
  [ ]
else
  let
    cronstrue-input = inputs.cronstrue or null;
    cronstrue-src =
      if mkGitInput != null && cronstrue-input != null then
        mkGitInput "cronstrue" cronstrue-input
      else
        null;

    hashFile = ../source-builds/hashes/cronstrue.json;
    hasHashFile = builtins.pathExists hashFile;
  in
  if cronstrue-src == null then
    [ ]
  else if !hasHashFile then
    builtins.trace
      "WARNING: cronstrue hash file not found. Run: ./scripts/source-build.sh update cronstrue"
      [ ]
  else
    let
      hashData = builtins.fromJSON (builtins.readFile hashFile);
    in
    [
      (
        final: prev:
        let
          lockedRev = cronstrue-src.rev;
          _ =
            if hashData.rev != lockedRev then
              throw ''
                cronstrue: hash file is stale.
                  flake.lock rev: ${lockedRev}
                  hash file rev:  ${hashData.rev}
                Run: ./scripts/source-build.sh update cronstrue
              ''
            else
              null;

          narHashShort =
            if cronstrue-src.narHash != "" then builtins.substring 7 8 cronstrue-src.narHash else "unknown";
        in
        {
          cronstrue-custom = final.buildNpmPackage rec {
            pname = "cronstrue";
            version = "${cronstrue-src.ref}-${narHashShort}-${builtins.substring 0 7 cronstrue-src.rev}";

            src = cronstrue-src.src;

            npmDepsHash = hashData.npmDepsHash;
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
      )
    ]
