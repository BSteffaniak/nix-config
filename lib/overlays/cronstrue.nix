# Auto-discovered overlay for cronstrue
# Enable with: enableCronstrue = true
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
  in
  if cronstrue-src == null then
    [ ]
  else
    [
      (
        final: prev:
        let
          # Use narHash to ensure version changes when source content changes
          # Extract first 8 chars of narHash for compact version string
          # This is PURE and guaranteed to change when source changes
          narHashShort =
            if cronstrue-src.narHash != "" then
              builtins.substring 7 8 cronstrue-src.narHash # Skip "sha256-" prefix
            else
              "unknown";
        in
        {
          cronstrue-custom = final.buildNpmPackage rec {
            pname = "cronstrue";
            # Version uses git metadata which changes with ANY source change
            # This guarantees a rebuild when you update the flake input
            version = "${cronstrue-src.ref}-${narHashShort}-${builtins.substring 0 7 cronstrue-src.rev}";

            src = cronstrue-src.src;

            # The hash of the npm dependencies
            # This will need to be updated if package-lock.json changes
            # Run `nix build` and it will tell you the correct hash if this is wrong
            npmDepsHash = "sha256-jfSlHEOjU6OLB46rbbu1btwm1AJVXsq1EF6tSlvx1CA=";

            # Don't run npm audit during build (it requires network access)
            npmFlags = [ "--legacy-peer-deps" ];

            # Build phase - compile TypeScript and bundle with webpack
            buildPhase = ''
              runHook preBuild

              # Compile TypeScript declarations
              npm run build

              # Bundle with webpack to create dist files
              npx webpack

              runHook postBuild
            '';

            # Install the compiled library and CLI
            installPhase = ''
              runHook preInstall

              # Create output directories
              mkdir -p $out/bin
              mkdir -p $out/lib/node_modules/cronstrue

              # Copy the built artifacts
              cp -r dist $out/lib/node_modules/cronstrue/
              cp -r locales $out/lib/node_modules/cronstrue/
              cp -r bin $out/lib/node_modules/cronstrue/
              cp package.json $out/lib/node_modules/cronstrue/
              cp i18n.js $out/lib/node_modules/cronstrue/
              cp i18n.d.ts $out/lib/node_modules/cronstrue/

              # Make the CLI executable and link it
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
