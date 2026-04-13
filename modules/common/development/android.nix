{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
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

  config = mkIf config.myConfig.development.android.enable {
    environment.systemPackages =
      optionals (!pkgs.stdenv.isDarwin) [ android.androidsdk ]
      ++ optionals (
        !pkgs.stdenv.isDarwin && meta.availableOn pkgs.stdenv.hostPlatform pkgs.android-studio
      ) [ pkgs.android-studio ];

    environment.variables = mkMerge [
      (mkIf pkgs.stdenv.isDarwin {
        ANDROID_HOME = "/Users/${config.myConfig.username}/Library/Android/sdk";
        ANDROID_SDK_ROOT = "/Users/${config.myConfig.username}/Library/Android/sdk";
      })
      (mkIf (!pkgs.stdenv.isDarwin) {
        ANDROID_HOME = "${android.androidsdk}/libexec/android-sdk";
        ANDROID_SDK_ROOT = "${android.androidsdk}/libexec/android-sdk";
        NDK_HOME = "${android.androidsdk}/libexec/android-sdk/ndk-bundle";
      })
    ];
  };
}
