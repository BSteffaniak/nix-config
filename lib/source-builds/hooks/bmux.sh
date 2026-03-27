# Install bmux bundled plugins alongside the binary.
#
# bmux discovers bundled plugins at <executable_dir>/plugins/<name>/plugin.toml
# and loads the cdylib specified by the 'entry' field in each manifest.
#
# In a Nix install the binary lives at $out/bin/bmux, so plugins go under
# $out/bin/plugins/<name>/.
#
# The plugin.toml manifests in the source tree hardcode .dylib extensions.
# This hook rewrites the entry to match the current platform.
#
# By the time postInstall runs, Nix's cargo-install-hook has already copied
# cdylibs to $out/lib/. We source them from there.

if [ "$(uname)" = "Darwin" ]; then
  dylib_ext="dylib"
else
  dylib_ext="so"
fi

for plugin_dir in $src/plugins/bundled/*/; do
  [ -d "$plugin_dir" ] || continue
  plugin_name=$(basename "$plugin_dir")

  # Read the entry field from the manifest (e.g. "libbmux_windows_plugin.dylib")
  # Use sed for portability (grep -P is not available on macOS in Nix sandbox)
  entry=$(sed -n 's/^entry[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$plugin_dir/plugin.toml" | head -1)
  [ -z "$entry" ] && continue

  # Derive the platform-correct filename
  # Strip any known dylib extension and re-add the correct one
  base=$(echo "$entry" | sed 's/\.\(dylib\|so\|dll\)$//')
  platform_entry="${base}.${dylib_ext}"

  # The cargo-install-hook already copied cdylibs to $out/lib/
  if [ ! -f "$out/lib/$platform_entry" ]; then
    echo "bmux postInstall: WARNING - could not find cdylib for plugin '${plugin_name}' at $out/lib/$platform_entry"
    continue
  fi

  mkdir -p "$out/bin/plugins/$plugin_name"
  cp "$plugin_dir/plugin.toml" "$out/bin/plugins/$plugin_name/"
  cp "$out/lib/$platform_entry" "$out/bin/plugins/$plugin_name/$platform_entry"

  # Rewrite the entry field to match the platform extension
  sed -i "s|^entry.*=.*|entry = \"${platform_entry}\"|" \
    "$out/bin/plugins/$plugin_name/plugin.toml"
done
