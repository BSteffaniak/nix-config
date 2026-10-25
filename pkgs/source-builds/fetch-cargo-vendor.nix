# Keep the network-facing fixed-output staging fetch unchanged. Patch only the
# assembly utility, so existing cargoHash values and cached downloads stay valid.
{
  pkgs,
  rustPlatform ? pkgs.rustPlatform,
}:
args:
let
  isVendorUtil = input: pkgs.lib.getName input == "fetch-cargo-vendor-util";
in
(rustPlatform.fetchCargoVendor args).overrideAttrs (old: {
  nativeBuildInputs =
    assert builtins.length (builtins.filter isVendorUtil old.nativeBuildInputs) == 1;
    map (
      input:
      if isVendorUtil input then
        pkgs.runCommand "fetch-cargo-vendor-util" { nativeBuildInputs = [ pkgs.patch ]; } ''
          mkdir -p "$out/bin"
          cp ${input}/bin/fetch-cargo-vendor-util "$out/bin/"
          chmod u+w "$out/bin/fetch-cargo-vendor-util"
          patch --batch --fuzz=0 "$out/bin/fetch-cargo-vendor-util" < ${./cargo-vendor-sources.patch}
        ''
      else
        input
    ) old.nativeBuildInputs;
})
