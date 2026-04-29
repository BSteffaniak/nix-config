# Main overlay entry point
# Simplifies passing flake inputs to the automatic overlay discovery system
#
# Source-built packages are auto-discovered from lib/source-builds/configs/*.json.
# Only complex/custom overlays need explicit wiring here.
{
  lib,
  nixpkgs-unstable,
  # All flake inputs -- source-build auto-discovery looks up inputs by name
  flakeInputs,
  # Complex overlays that need explicit input wiring
  rust-overlay ? null,
  zellij-fork ? null,
  cronstrue-src ? null,
  firefox-darwin ? null,
  # Optional overlay configuration
  enableRust ? true,
  enableGithubReleases ? true,
  enablePiClipboard ? true,
  enableSourceBuilds ? true,
  enableZellijFork ? false,
  enableCronstrue ? true,
  enableFirefoxDarwin ? true,
  enableMinecraftPlugins ? true,
}:
let
  # Bundle inputs for overlays that need them
  # Source-builds auto-discovery uses flakeInputs directly
  # Complex overlays use named inputs
  inputs = {
    inherit
      nixpkgs-unstable
      rust-overlay
      zellij-fork
      firefox-darwin
      ;
    cronstrue = cronstrue-src;
  }
  // flakeInputs;

  # Helper to extract git input metadata from flake.lock
  # Always uses root flake.lock with unified flake structure
  mkGitInput = import ./mk-git-input.nix { lockFile = ../flake.lock; };

  # Import all overlay functions (these must be imported here, not in mkOverlays.nix)
  overlayFunctions = {
    rust = import ./overlays/rust.nix;
    github-releases = import ./overlays/github-releases.nix;
    pi-clipboard =
      {
        inputs,
        enable,
        mkGitInput,
      }:
      if !enable then
        [ ]
      else
        [
          (
            final: prev:
            let
              # Keep using the GitHub release artifact for Pi itself, but add
              # the optional native clipboard sidecar module that Pi loads at
              # runtime for interactive image paste on macOS.
              clipboardVersion = "0.3.3";

              clipboard = final.fetchurl {
                url = "https://registry.npmjs.org/@mariozechner/clipboard/-/clipboard-${clipboardVersion}.tgz";
                hash = "sha256-cm9PbGqbn2H9hCxiZv7pKQBLeVHH9A/DDeBjndnGW9E=";
              };

              clipboardDarwinUniversal = final.fetchurl {
                url = "https://registry.npmjs.org/@mariozechner/clipboard-darwin-universal/-/clipboard-darwin-universal-${clipboardVersion}.tgz";
                hash = "sha256-qFFIblihuU7VkNOFoz516i0hv4ylFnwsAotFsbhE8L4=";
              };

              installNpmTgz = src: target: ''
                mkdir -p "$out/libexec/pi/node_modules/${target}"
                tar -xzf ${src} --strip-components=1 -C "$out/libexec/pi/node_modules/${target}"
              '';
            in
            {
              pi = prev.pi.overrideAttrs (old: {
                installPhase =
                  old.installPhase
                  + final.lib.optionalString final.stdenv.isDarwin ''
                    ${installNpmTgz clipboard "@mariozechner/clipboard"}
                    ${installNpmTgz clipboardDarwinUniversal "@mariozechner/clipboard-darwin-universal"}

                    # Pi is a Bun-compiled binary, so its dynamic createRequire()
                    # calls resolve from Bun's virtual filesystem instead of this
                    # package directory. Expose the sidecar node_modules through
                    # NODE_PATH so @mariozechner/clipboard can be found at runtime.
                    cat > "$out/bin/pi" <<'EOF'
                    #!/bin/sh
                    export NODE_PATH="@out@/libexec/pi/node_modules''${NODE_PATH:+:$NODE_PATH}"
                    exec "@out@/libexec/pi/pi" "$@"
                    EOF
                    substituteInPlace "$out/bin/pi" --replace-fail @out@ "$out"
                    chmod +x "$out/bin/pi"
                  '';
              });
            }
          )
        ];
    source-builds = import ./overlays/source-builds.nix;
    zellij = import ./overlays/zellij.nix;
    cronstrue = import ./overlays/cronstrue.nix;
    firefox-darwin = import ./overlays/firefox-darwin.nix;
    minecraft-plugins = import ./overlays/minecraft-plugins.nix;
  };

  mkOverlaysLib = import ./mkOverlays.nix {
    inherit
      lib
      inputs
      mkGitInput
      overlayFunctions
      ;
  };
in
mkOverlaysLib.mkOverlays {
  inherit
    enableRust
    enableGithubReleases
    enablePiClipboard
    enableSourceBuilds
    enableZellijFork
    enableCronstrue
    enableFirefoxDarwin
    enableMinecraftPlugins
    ;
}
