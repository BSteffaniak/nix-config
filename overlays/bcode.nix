# Bcode embeds BMUX's Mermaid renderer too; share the explicitly built guest.
{ inputs }:
final: prev: {
  bcode = prev.bcode.overrideAttrs (old: {
    BMUX_MERMAID_WASM_PATH = "${final.bmux.mermaidGuest}/lib/mermaid.wasm";
    preBuild = (old.preBuild or "") + ''
      # Never silently embed a guest from a different renderer revision.
      if ! grep -Fq 'git+https://github.com/BSteffaniak/bmux?branch=master#${inputs.bmux-src.rev}' Cargo.lock; then
        echo "bcode's locked BMUX revision must match the bmux-src flake input" >&2
        echo "Update bcode's BMUX dependency and the bmux-src pin together." >&2
        exit 1
      fi
    '';
  });
}
