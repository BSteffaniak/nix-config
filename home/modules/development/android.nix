{
  config,
  lib,
  pkgs,
  ...
}:

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
    enable = lib.mkEnableOption "Android development environment";
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      lib.optionals (!pkgs.stdenv.isDarwin) [ android.androidsdk ]
      ++ lib.optionals (
        !pkgs.stdenv.isDarwin && lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.android-studio
      ) [ pkgs.android-studio ];

    home.sessionVariables = lib.mkMerge [
      (lib.mkIf pkgs.stdenv.isDarwin {
        ANDROID_HOME = darwinSdkRoot;
        ANDROID_SDK_ROOT = darwinSdkRoot;
        ANDROID_NDK_HOME = "${android.androidsdk}/libexec/android-sdk/ndk-bundle";
        ANDROID_NDK_ROOT = "${android.androidsdk}/libexec/android-sdk/ndk-bundle";
        NDK_HOME = "${android.androidsdk}/libexec/android-sdk/ndk-bundle";
      })
      (lib.mkIf (!pkgs.stdenv.isDarwin) {
        ANDROID_HOME = "${android.androidsdk}/libexec/android-sdk";
        ANDROID_SDK_ROOT = "${android.androidsdk}/libexec/android-sdk";
        NDK_HOME = "${android.androidsdk}/libexec/android-sdk/ndk-bundle";
      })
    ];

    home.sessionPath = lib.mkIf pkgs.stdenv.isDarwin [
      "${darwinSdkRoot}/emulator"
      "${darwinSdkRoot}/platform-tools"
      "${darwinSdkRoot}/cmdline-tools/latest/bin"
    ];
  };
}
