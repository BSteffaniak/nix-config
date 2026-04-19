# Sledge keyboard-remap daemon configuration.
#
# Structured with a universal block + per-OS blocks so a future Linux
# backend for sledge can drop in as an additional mkIf branch without
# restructuring the module.
#
# macOS path:
#   - pkgs.sledge on PATH (produced by the source-build overlay).
#   - ~/.config/sledge/config.toml written from configs/sledge/config.toml.
#   - ~/Library/LaunchAgents/com.braden.sledge.plist (via home-manager's
#     launchd.agents module) launches the daemon at login.
#   - home.activation.installSledgeApp ensures a signing identity exists
#     in the login keychain, copies the bundle to /Applications/Sledge.app,
#     re-signs it with the per-host self-signed identity, and kicks the
#     LaunchAgent so it picks up the new binary.
#
# Linux path (future):
#   - Currently a no-op. See the commented block at the bottom of this file
#     for the expected shape once sledge ships a Linux backend.
#   - The option itself is declarable on Linux so a Linux host can flip it
#     on aspirationally; nothing else happens until the guard at the top of
#     the macOS block is relaxed.
#
# Why home-manager rather than nix-darwin's system.activationScripts?
#   The activation script needs the user's login keychain (for signing)
#   and writes to /Applications (group-writable by admin). system-level
#   activation runs as root, where $HOME=/var/root and the user's keychain
#   is inaccessible, which forced ugly `sudo --user=braden` wrapping for
#   every step. home-manager activation runs as the user naturally, so
#   everything just works.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.desktop.sledge;
in
{
  options.myConfig.desktop.sledge = {
    enable = mkEnableOption "Sledge keyboard remap daemon";
  };

  config = mkMerge [
    # -----------------------------------------------------------------
    # Universal configuration
    # -----------------------------------------------------------------
    # The option is declarable on any platform so a Linux host can set
    # it aspirationally today. Installation + LaunchAgent setup is
    # gated per-platform below.
    (mkIf cfg.enable {
      # Package is only built for macOS at present. The isDarwin guard
      # keeps Linux hosts evaluating cleanly even when cfg.enable = true;
      # drop it once sledge ships a Linux backend.
      home.packages = mkIf pkgs.stdenv.isDarwin [ pkgs.sledge ];

      # Config file. Currently macOS-only because the daemon only runs
      # there; same `isDarwin` guard pattern as above.
      xdg.configFile."sledge/config.toml" = mkIf pkgs.stdenv.isDarwin {
        source = ../../../configs/sledge/config.toml;
        onChange = ''
          # The sledge daemon has its own file watcher that applies
          # config changes within ~250ms. SIGHUP here is a deterministic
          # sync point at rebuild boundaries (redundant in the common
          # case, but helpful if the watcher is ever broken).
          /usr/bin/pkill -HUP -x sledge 2>/dev/null || true
        '';
      };
    })

    # -----------------------------------------------------------------
    # macOS-specific: LaunchAgent + /Applications install + signing
    # -----------------------------------------------------------------
    (mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
      # Exclude Sledge.app from mkalias's Finder-alias creation loop.
      # mkalias otherwise sees ${pkgs.sledge}/Applications/Sledge.app
      # (linked under ~/.nix-profile/Applications via home.packages)
      # and creates a Finder alias at /Applications/Sledge.app. That
      # conflicts with our real bundle install below: ditto refuses to
      # copy a directory onto an existing file, and subsequent rebuilds
      # would produce a constant fight between the two modules.
      myConfig.desktop.mkalias.excludeApps = [ "Sledge.app" ];

      launchd.agents.sledge = {
        enable = true;
        config = {
          Label = "com.braden.sledge";
          ProgramArguments = [
            "/Applications/Sledge.app/Contents/MacOS/sledge"
            "run"
          ];
          RunAtLoad = true;
          KeepAlive = {
            Crashed = true;
            SuccessfulExit = false;
          };
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/sledge.launchd.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/sledge.launchd.err.log";
        };
      };

      # Install /Applications/Sledge.app by copying from the nix store
      # and re-signing with the host's self-signed "Sledge Local Signing"
      # identity. Per-host identity + stable cert hash = stable TCC
      # grants across rebuilds. The identity is created on demand
      # (idempotent) by setup-signing-identity.sh.
      #
      # Runs as the user (home.activation contract), so $HOME points at
      # the user's home directory and keychain access works without sudo.
      home.activation.installSledgeApp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        echo "installing Sledge.app..." >&2

        # Create/verify the signing identity (idempotent).
        run /bin/sh ${pkgs.sledge}/share/sledge/scripts/setup-signing-identity.sh

        # If any prior install (Finder alias file, stale directory, or
        # an older nix-store copy) exists at the install path, clear it
        # first. A bundle copied from the read-only nix store inherits
        # r-xr-xr-x permissions, which prevents rm from traversing it;
        # chmod writable first so the cleanup succeeds.
        if [ -e /Applications/Sledge.app ]; then
          run /bin/chmod -R u+w /Applications/Sledge.app
          run /bin/rm -rf /Applications/Sledge.app
        fi

        # Copy the nix-store bundle to /Applications. The user is an
        # admin on this host and /Applications is group-writable
        # (admin:755), so ditto succeeds without sudo.
        run /usr/bin/ditto \
          "${pkgs.sledge}/Applications/Sledge.app" \
          /Applications/Sledge.app

        # The new copy inherited r-xr-xr-x from the nix store. Make it
        # writable so xattr and codesign can modify it (codesign
        # patches the Mach-O header and rewrites
        # Contents/_CodeSignature/).
        run /bin/chmod -R u+w /Applications/Sledge.app

        run /usr/bin/xattr -cr /Applications/Sledge.app || true

        # Resolve the local identity's SHA-1 from the user's login
        # keychain. We match "Sledge Local Signing" by substring in the
        # awk line because the CN contains whitespace and splitting on
        # $3 would truncate it.
        #
        # Absolute paths are used throughout this activation script
        # because home-manager's activation PATH does not include
        # /usr/bin by default. Setting PATH at the top of the script
        # would work but leaks into subsequent activation stages
        # (notably linkGeneration, which depends on a GNU readlink from
        # the activation PATH's coreutils and breaks if /usr/bin's BSD
        # readlink is earlier in PATH).
        IDENTITY_HASH="$(/usr/bin/security find-identity -v -p codesigning \
          "$HOME/Library/Keychains/login.keychain-db" \
          | /usr/bin/awk '
              index($0, "\"Sledge Local Signing\"") {
                for (i = 1; i <= NF; i++)
                  if ($i ~ /^[0-9A-F]{40}$/) { print $i; exit }
              }')"

        if [ -z "$IDENTITY_HASH" ]; then
          echo "ERROR: Sledge Local Signing identity missing; aborting activation" >&2
          exit 1
        fi

        # Re-sign the installed bundle with the local identity. We
        # deliberately do NOT pass --options runtime: hardened runtime
        # enables library validation, which rejects nix-store dylibs
        # signed by nix's build infrastructure. Using a stable self-
        # signed cert without hardened runtime is sufficient for TCC
        # stability across rebuilds because the designated requirement
        # includes the certificate leaf hash, which stays the same as
        # long as we re-use the same identity in the login keychain.
        run /usr/bin/codesign --sign "$IDENTITY_HASH" \
          --identifier com.braden.sledge \
          --force --deep --timestamp=none \
          /Applications/Sledge.app

        # Kick the LaunchAgent so it picks up the new binary. home-
        # manager reloads the agent on plist changes, but our bundle
        # swap is orthogonal to plist content, so we trigger the
        # restart ourselves. Tolerate the "not bootstrapped yet" case
        # on first enable.
        /bin/launchctl kickstart -k "gui/$(/usr/bin/id -u)/com.braden.sledge" 2>/dev/null || true
      '';
    })

    # -----------------------------------------------------------------
    # Linux-specific: placeholder for the future Linux backend.
    # -----------------------------------------------------------------
    # Uncomment and adapt once sledge has a Linux backend. Also relax
    # the `isDarwin` guards in the universal block above so pkgs.sledge
    # is installed and the config file is deployed on Linux too.
    #
    # (mkIf (cfg.enable && pkgs.stdenv.isLinux) {
    #   systemd.user.services.sledge = {
    #     Unit.Description = "Sledge keyboard remap daemon";
    #     Service = {
    #       ExecStart = "${pkgs.sledge}/bin/sledge run";
    #       Restart = "on-failure";
    #     };
    #     Install.WantedBy = [ "default.target" ];
    #   };
    # })
  ];
}
