{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.devops.cloud;

  # `includeAWSVault` predates the `awsVault` submodule and is kept working so
  # existing host configs keep installing the package.
  awsVaultEnabled = cfg.awsVault.enable || cfg.includeAWSVault;
  awsVaultKeychain = cfg.awsVault.keychain;

  manageAwsVaultKeychain =
    awsVaultEnabled && awsVaultKeychain.manageSettings && pkgs.stdenv.hostPlatform.isDarwin;

  # Omitting -l is what disables lock-on-sleep; there is no explicit "off"
  # flag. -u would prompt to unlock, which must not happen during activation.
  awsVaultKeychainFlags = lib.concatStringsSep " " (
    (lib.optional awsVaultKeychain.lockOnSleep "-l")
    ++ (lib.optional (
      awsVaultKeychain.lockTimeout != null
    ) "-t ${toString awsVaultKeychain.lockTimeout}")
  );
in
{
  options.myConfig.devops.cloud = {
    enable = lib.mkEnableOption "Cloud provider CLI tools";

    includeAWS = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include AWS CLI and SAM CLI";
    };

    includeAWSVault = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Include aws-vault (secure AWS credential storage).

        Deprecated alias for `awsVault.enable`; either option installs the
        package. Prefer `awsVault.enable` so the TTL and keychain settings
        below are configured alongside it.
      '';
    };

    # aws-vault stores AWS master credentials in a dedicated macOS keychain
    # (~/Library/Keychains/aws-vault.keychain-db) rather than the login
    # keychain. That keychain has its own auto-lock policy, independent of the
    # login session, so it re-locks and prompts for a password well before the
    # login keychain would. The `keychain` options below relax that policy; the
    # TTL options reduce how often aws-vault needs to read the keychain at all.
    awsVault = {
      enable = lib.mkEnableOption "aws-vault (secure AWS credential storage)";

      sessionTokenTTL = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "12h";
        description = ''
          Sets AWS_SESSION_TOKEN_TTL, the lifetime of GetSessionToken
          credentials. aws-vault defaults to 1h. Requires a unit suffix
          (e.g. "12h" or "43200s"). null leaves the upstream default.

          Longer values mean fewer MFA prompts but a wider window of exposure
          if a cached session is compromised.
        '';
      };

      assumeRoleTTL = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "12h";
        description = ''
          Sets AWS_ASSUME_ROLE_TTL, the lifetime of AssumeRole credentials.
          aws-vault defaults to 1h. Requires a unit suffix. null leaves the
          upstream default.
        '';
      };

      keychain = {
        manageSettings = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Apply the lock settings below to the aws-vault keychain during
            home-manager activation (darwin only).

            When enabled with `lockTimeout = null` and `lockOnSleep = true`,
            this resets the keychain to macOS defaults, which is likely not
            what you want -- set `lockTimeout` explicitly.
          '';
        };

        lockTimeout = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          example = 28800;
          description = ''
            Inactivity timeout in seconds before the aws-vault keychain
            re-locks. null means no timeout (the keychain stays unlocked
            until sleep or logout).
          '';
        };

        lockOnSleep = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Lock the aws-vault keychain when the machine sleeps. Setting this
            false is what avoids a password prompt after every lid close, at
            the cost of leaving credentials unlocked across sleep.
          '';
        };
      };
    };

    includeDigitalOcean = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include doctl (DigitalOcean CLI)";
    };

    includeGCP = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include Google Cloud SDK";
    };

    includeAzure = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include Azure CLI";
    };

    includeFlyctl = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include flyctl (Fly.io CLI)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      [ ]
      ++ (lib.optionals cfg.includeAWS [
        awscli2
        # aws-sam-cli  # TODO: broken in 25.11 - dependency version mismatches
      ])
      ++ (lib.optional awsVaultEnabled aws-vault)
      ++ (lib.optional cfg.includeDigitalOcean doctl)
      ++ (lib.optional cfg.includeGCP google-cloud-sdk)
      ++ (lib.optional cfg.includeAzure azure-cli)
      ++ (lib.optional cfg.includeFlyctl flyctl);

    # Contributed through the shared shell channel rather than
    # home.sessionVariables directly: nushell (the default shell on some hosts)
    # builds its environment from myConfig.shell.contrib.sessionVariables and
    # would not otherwise see these. home/modules/shell/shared.nix folds this
    # channel back into home.sessionVariables for the POSIX shells.
    myConfig.shell.contrib.sessionVariables = lib.mkIf awsVaultEnabled (
      (lib.optionalAttrs (cfg.awsVault.sessionTokenTTL != null) {
        AWS_SESSION_TOKEN_TTL = cfg.awsVault.sessionTokenTTL;
      })
      // (lib.optionalAttrs (cfg.awsVault.assumeRoleTTL != null) {
        AWS_ASSUME_ROLE_TTL = cfg.awsVault.assumeRoleTTL;
      })
    );

    # Absolute /usr/bin/security path and home-manager (rather than
    # system.activationScripts) for the same reasons documented in
    # home/modules/desktop/sledge.nix: activation PATH lacks /usr/bin, and
    # setting PATH here leaks into later activation stages; and the keychain
    # belongs to the user, which root-run system activation cannot reach.
    #
    # The existence guard keeps this a no-op before `aws-vault add` has ever
    # created the keychain. If the keychain is currently locked, macOS may
    # prompt once here -- and the new settings only govern future locks, so an
    # already-locked keychain still needs one manual unlock.
    home.activation = lib.mkIf manageAwsVaultKeychain {
      awsVaultKeychainSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        aws_vault_keychain="$HOME/Library/Keychains/aws-vault.keychain-db"
        if [ -e "$aws_vault_keychain" ]; then
          run /usr/bin/security set-keychain-settings ${awsVaultKeychainFlags} "$aws_vault_keychain"
        fi
      '';
    };
  };
}
