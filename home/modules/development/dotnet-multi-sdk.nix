# Custom .NET SDK package builder that copies all runtimes into each SDK location
# This enables cross-SDK test execution (e.g., SDK 10 can run tests for net8.0/net9.0)
#
# Problem: dotnetCorePackages.combinePackages creates symlinks, which get resolved
# at runtime, causing test hosts to only find runtimes in their own SDK location.
#
# Solution: Physically copy all runtime directories into each SDK's shared folder.

{
  lib,
  stdenv,
  symlinkJoin,
}:

{ sdks, runtimes }:

let
  inherit (lib) concatMapStringsSep optionalString;

  # Create base combined SDK structure using symlinkJoin
  baseCombined = symlinkJoin {
    name = "dotnet-base-combined";
    paths = sdks;
  };

in
stdenv.mkDerivation rec {
  name = "dotnet-multi-sdk-${lib.concatStringsSep "-" (map (sdk: sdk.version or "unknown") sdks)}";

  # No source needed - we're combining existing packages
  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    echo "Creating multi-SDK dotnet structure..."
    mkdir -p $out/share/dotnet

    # Use first SDK as the base (for dotnet binary, host, etc.)
    echo "Copying base structure from first SDK..."
    cp -rL ${builtins.head sdks}/share/dotnet/* $out/share/dotnet/

    # Make everything writable so we can add more SDKs and runtimes
    chmod -R u+w $out/share/dotnet

    # Explicitly copy SDK directories from ALL SDK packages
    echo "Copying SDK directories from all packages..."
    ${concatMapStringsSep "\n" (sdk: ''
      if [ -d "${sdk}/share/dotnet/sdk" ]; then
        echo "Processing SDK from ${sdk}..."
        for sdkVersion in ${sdk}/share/dotnet/sdk/*; do
          if [ -d "$sdkVersion" ]; then
            versionName=$(basename "$sdkVersion")
            echo "  Copying SDK version: $versionName"
            mkdir -p $out/share/dotnet/sdk
            cp -rL "$sdkVersion" $out/share/dotnet/sdk/
          fi
        done
      fi
    '') sdks}

    # Collect all runtime versions from all SDK/runtime packages
    echo "Collecting runtime directories..."
    ${concatMapStringsSep "\n" (runtime: ''
      # Copy Microsoft.NETCore.App runtimes
      if [ -d "${runtime}/share/dotnet/shared/Microsoft.NETCore.App" ]; then
        echo "Processing NETCore.App from ${runtime}..."
        for runtimeVersion in ${runtime}/share/dotnet/shared/Microsoft.NETCore.App/*; do
          if [ -d "$runtimeVersion" ]; then
            versionName=$(basename "$runtimeVersion")
            echo "  Found runtime version: $versionName"

            # Copy this runtime into the combined shared location
            mkdir -p $out/share/dotnet/shared/Microsoft.NETCore.App
            cp -rL "$runtimeVersion" $out/share/dotnet/shared/Microsoft.NETCore.App/ || true
          fi
        done
      fi

      # Copy Microsoft.AspNetCore.App runtimes
      if [ -d "${runtime}/share/dotnet/shared/Microsoft.AspNetCore.App" ]; then
        echo "Processing AspNetCore.App from ${runtime}..."
        for runtimeVersion in ${runtime}/share/dotnet/shared/Microsoft.AspNetCore.App/*; do
          if [ -d "$runtimeVersion" ]; then
            versionName=$(basename "$runtimeVersion")
            echo "  Found ASP.NET Core version: $versionName"

            # Copy this runtime into the combined shared location
            mkdir -p $out/share/dotnet/shared/Microsoft.AspNetCore.App
            cp -rL "$runtimeVersion" $out/share/dotnet/shared/Microsoft.AspNetCore.App/ || true
          fi
        done
      fi
    '') runtimes}

    # Create bin directory with dotnet symlink for PATH integration
    echo "Creating bin/dotnet symlink..."
    mkdir -p $out/bin
    ln -s $out/share/dotnet/dotnet $out/bin/dotnet

    echo "Dotnet multi-SDK package created successfully"
    echo "Available SDKs:"
    ls -1 $out/share/dotnet/sdk/
    echo "Available runtimes:"
    ls -1 $out/share/dotnet/shared/Microsoft.NETCore.App/ || echo "  (none found)"

    runHook postInstall
  '';

  # Pass through metadata for debugging
  passthru = {
    inherit sdks runtimes;
    type = "multi-sdk-combined";
  };

  meta = with lib; {
    description = "Combined .NET SDK package with all runtimes available to all SDKs";
    platforms = platforms.unix;
  };
}
