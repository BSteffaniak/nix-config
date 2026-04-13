{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.development.android;
  darwinSdkRoot = "$HOME/Library/Android/sdk";

  android = pkgs.androidenv.composeAndroidPackages {
    cmdLineToolsVersion = "13.0";
    toolsVersion = "26.1.1";
    platformToolsVersion = "35.0.2";
    buildToolsVersions = [
      "30.0.3"
      "34.0.0"
    ];
    platformVersions = [
      "33"
      "34"
    ];
    includeEmulator = true;
    emulatorVersion = "35.2.5";
    includeSystemImages = true;
    systemImageTypes = [ "google_apis" ];
    abiVersions = [
      "arm64-v8a"
      "armeabi-v7a"
      "x86"
      "x86_64"
    ];
    includeSources = false;
    includeNDK = true;
    useGoogleAPIs = true;
    useGoogleTVAddOns = false;
    includeExtras = [ ];
    extraLicenses = [ ];
  };
in
{
  options.myConfig.development.android = {
    enable = mkEnableOption "Android development environment";
  };

  config = mkIf cfg.enable {
    home.packages =
      optionals (!pkgs.stdenv.isDarwin) [ android.androidsdk ]
      ++ optionals (
        !pkgs.stdenv.isDarwin && meta.availableOn pkgs.stdenv.hostPlatform pkgs.android-studio
      ) [ pkgs.android-studio ];

    home.sessionVariables = mkMerge [
      (mkIf pkgs.stdenv.isDarwin {
        ANDROID_HOME = darwinSdkRoot;
        ANDROID_SDK_ROOT = darwinSdkRoot;
      })
      (mkIf (!pkgs.stdenv.isDarwin) {
        ANDROID_HOME = "${android.androidsdk}/libexec/android-sdk";
        ANDROID_SDK_ROOT = "${android.androidsdk}/libexec/android-sdk";
        NDK_HOME = "${android.androidsdk}/libexec/android-sdk/ndk-bundle";
      })
    ];

    home.sessionPath = mkIf pkgs.stdenv.isDarwin [
      "${darwinSdkRoot}/emulator"
      "${darwinSdkRoot}/platform-tools"
      "${darwinSdkRoot}/cmdline-tools/latest/bin"
    ];
  };
}
