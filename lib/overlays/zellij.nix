# Overlay for Zellij (custom fork)
# Enable with: enableZellijFork = true
#
# Dependency hash managed by: ./scripts/source-build.sh update zellij
# Hash file: lib/source-builds/hashes/zellij.json
{
  inputs,
  enable ? false,
  mkGitInput ? null,
}:
if !enable then
  [ ]
else
  let
    zellij-fork-input = inputs.zellij-fork or null;
    zellij-fork =
      if mkGitInput != null && zellij-fork-input != null then
        mkGitInput "zellij-fork" zellij-fork-input
      else
        null;

    hashFile = ../source-builds/hashes/zellij.json;
    hasHashFile = builtins.pathExists hashFile;
  in
  if zellij-fork == null then
    [ ]
  else if !hasHashFile then
    builtins.trace "WARNING: zellij hash file not found. Run: ./scripts/source-build.sh update zellij"
      [ ]
  else
    let
      hashData = builtins.fromJSON (builtins.readFile hashFile);
    in
    [
      (
        final: prev:
        let
          lockedRev = zellij-fork.rev;
          _ =
            if hashData.rev != lockedRev then
              throw ''
                zellij: hash file is stale.
                  flake.lock rev: ${lockedRev}
                  hash file rev:  ${hashData.rev}
                Run: ./scripts/source-build.sh update zellij
              ''
            else
              null;

          narHashShort =
            if zellij-fork.narHash != "" then builtins.substring 7 8 zellij-fork.narHash else "unknown";
        in
        {
          zellij-custom =
            let
              rust-toolchain = final.rust-bin.stable."1.90.0".default.override {
                extensions = [
                  "rust-src"
                  "clippy"
                  "rustfmt"
                ];
                targets = [
                  "wasm32-wasip1"
                  "x86_64-unknown-linux-gnu"
                ];
              };

              customRustPlatform = final.makeRustPlatform {
                cargo = rust-toolchain;
                rustc = rust-toolchain;
              };
            in
            customRustPlatform.buildRustPackage rec {
              pname = "zellij";
              version = "0.44.0-${zellij-fork.ref}-${narHashShort}-${builtins.substring 0 7 zellij-fork.rev}";

              src = zellij-fork.src;

              postPatch = ''
                sed -i 's|env!("CARGO_PKG_VERSION")|"${version}"|' zellij-utils/src/consts.rs
              '';

              cargoHash = hashData.cargoHash;

              nativeBuildInputs = with final; [
                pkg-config
                installShellFiles
                copyDesktopItems
                makeWrapper
                perl
              ];

              buildInputs = with final; [
                openssl
                openssl.dev
                curl
                zstd
              ];

              OPENSSL_NO_VENDOR = "1";
              PKG_CONFIG_PATH = "${final.openssl.dev}/lib/pkgconfig";

              doCheck = false;

              preConfigure = ''
                export HOME=$TMPDIR
              '';

              postInstall = ''
                installShellCompletion --cmd zellij \
                  --bash <($out/bin/zellij setup --generate-completion bash) \
                  --fish <($out/bin/zellij setup --generate-completion fish) \
                  --zsh <($out/bin/zellij setup --generate-completion zsh)

                mandir=$out/share/man
                mkdir -p $mandir/man1
              '';

              meta = with final.lib; {
                description = "Zellij - A terminal workspace (custom fork with ToggleSession support)";
                homepage = "https://zellij.dev";
                changelog = "https://github.com/zellij-org/zellij/blob/v${version}/CHANGELOG.md";
                license = licenses.mit;
                mainProgram = "zellij";
                maintainers = [ ];
                platforms = platforms.unix;
              };
            };
        }
      )
    ]
