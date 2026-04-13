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
    systemImageTypes = [ "default" ];
    abiVersions = [
      "arm64-v8a"
      "armeabi-v7a"
      "x86"
      "x86_64"
    ];
    includeSources = false;
    includeNDK = true;
    useGoogleAPIs = false;
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
    environment.systemPackages = [
      android.androidsdk
    ]
    ++ optional (meta.availableOn pkgs.stdenv.hostPlatform pkgs.android-studio) pkgs.android-studio;

    environment.variables = {
      ANDROID_HOME = "${android.androidsdk}/libexec/android-sdk";
      NDK_HOME = "${android.androidsdk}/libexec/android-sdk/ndk-bundle";
    };
  };
}
