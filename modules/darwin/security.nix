{
  config,
  lib,
  ...
}:

let
  cfg = config.myConfig.darwin.security;
  devTools = cfg.developerTools;
  user = config.system.primaryUser;
  settingsUrl = "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_DevTools";
  # Remembers which installed apps the user was already sent to Settings for,
  # so a rebuild only reopens Settings when that set changes.
  stampFile = "/var/db/myconfig-developer-tools";
in
{
  options.myConfig.darwin.security = {
    touchId.enable = lib.mkEnableOption "Touch ID for sudo authentication";

    developerTools = {
      enable = lib.mkEnableOption ''
        prompting to mark apps as macOS Developer Tools. Processes launched from
        a Developer Tool skip the Gatekeeper/XProtect first-launch scan (the
        "Verifying..." dialog) that otherwise runs on every freshly built
        binary. The grant lives in the SIP-protected TCC database, so it cannot
        be applied declaratively; activation exposes the Settings pane and opens
        it when an installed app may still need to be switched on'';

      apps = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "com.mitchellh.ghostty" ];
        description = "Bundle identifiers to mark as Developer Tools. Apps that are not installed are skipped.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.touchId.enable {
      security.pam.services.sudo_local.touchIdAuth = true;
    })

    (lib.mkIf (devTools.enable && devTools.apps != [ ]) {
      system.activationScripts.postActivation.text = lib.mkAfter ''
        # Make the Developer Tools pane visible in System Settings.
        /usr/sbin/spctl developer-mode enable-terminal >/dev/null 2>&1 || true

        # Reading TCC.db needs Full Disk Access; without it every installed app
        # counts as pending and the stamp file stops repeat prompts.
        devtools_granted=""
        devtools_readable=0
        if devtools_granted=$(/usr/bin/sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
          "select client from access where service='kTCCServiceDeveloperTool' and auth_value=2" 2>/dev/null); then
          devtools_readable=1
        fi

        devtools_pending=""
        for devtools_id in ${lib.escapeShellArgs devTools.apps}; do
          devtools_app=$(/usr/bin/mdfind "kMDItemCFBundleIdentifier == '$devtools_id'" 2>/dev/null | head -n 1)
          [ -n "$devtools_app" ] || continue
          if [ "$devtools_readable" = 1 ] && printf '%s\n' "$devtools_granted" | grep -qxF "$devtools_id"; then
            continue
          fi
          echo "developer tools: enable $devtools_app in Privacy & Security > Developer Tools" >&2
          devtools_pending="$devtools_pending $devtools_id"
        done

        if [ -n "$devtools_pending" ]; then
          if [ "$devtools_readable" = 1 ] || [ "$(cat ${stampFile} 2>/dev/null)" != "$devtools_pending" ]; then
            /bin/launchctl asuser "$(id -u ${user})" \
              /usr/bin/sudo -u ${user} /usr/bin/open "${settingsUrl}" || true
          fi
          printf '%s' "$devtools_pending" > ${stampFile}
        fi
      '';
    })
  ];
}
