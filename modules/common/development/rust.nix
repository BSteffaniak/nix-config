{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.development.rust;

  # Determine which Rust packages to include based on configuration
  rustPackages =
    let
      hasStable = cfg.includeStable;
      hasNightly = cfg.includeNightly;

      # Cargo development tools
      cargoUtils =
        with pkgs;
        (optional cfg.cargoTools.includeBinstall cargo-binstall)
        ++ (optional cfg.cargoTools.includeNextest cargo-nextest)
        ++ (optional cfg.cargoTools.includeLambda cargo-lambda)
        ++ (optional cfg.cargoTools.includeRaMultiplex ra-multiplex-latest);

      # Build toolchains with rust-src configuration
      stableToolchain = pkgs.mkRustStable { includeRustSrc = cfg.includeRustSrc; };
      nightlyToolchain = pkgs.mkRustNightly { includeRustSrc = cfg.includeRustSrc; };

      # Rust toolchain packages based on configuration
      rustToolchains =
        if hasStable && hasNightly then
          # Both stable and nightly: use wrappers
          [
            (pkgs.mkCargoWrapper {
              rustStable = stableToolchain;
              rustNightly = nightlyToolchain;
            })
            (pkgs.mkRustcWrapper {
              rustStable = stableToolchain;
              rustNightly = nightlyToolchain;
            })
            stableToolchain # Keep stable for rust-analyzer
          ]
        else if hasStable then
          # Stable only: use direct packages
          [
            stableToolchain
          ]
        else if hasNightly then
          # Nightly only: use direct packages
          [
            nightlyToolchain
          ]
        else
          # Neither enabled: empty list
          [ ];
    in
    rustToolchains ++ cargoUtils;
in
{
  options.myConfig.development.rust = {
    enable = mkEnableOption "Rust development environment";

    includeStable = mkOption {
      type = types.bool;
      default = true;
      description = "Include Rust stable toolchain";
    };

    includeNightly = mkOption {
      type = types.bool;
      default = false;
      description = "Include Rust nightly toolchain";
    };

    includeRustSrc = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Include rust-src component in the Rust toolchain.
        This provides Rust standard library source code, which is needed for:
        - IDE features like "go to definition" for standard library items
        - Cross-compilation
        - Building the standard library from source
      '';
    };

    cargoTools = {
      includeBinstall = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Include cargo-binstall for binary crate installation.
          Allows installing cargo binaries without building from source.
        '';
      };

      includeNextest = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Include cargo-nextest, a next-generation test runner.
          Provides faster test execution and better output.
        '';
      };

      includeLambda = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Include cargo-lambda for AWS Lambda development.
          Only needed if you're developing Rust applications for AWS Lambda.
        '';
      };

      includeRaMultiplex = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Include ra-multiplex (rust-analyzer multiplexer).
          Useful for managing multiple rust-analyzer instances in monorepos.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = rustPackages;

    # Warn if neither stable nor nightly is enabled
    warnings = optional (
      !cfg.includeStable && !cfg.includeNightly
    ) "Rust development environment is enabled but neither stable nor nightly toolchain is included.";
  };
}
