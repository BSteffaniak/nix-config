# Package fixes that only apply on Darwin.
{ inputs }:
final: prev:
if !prev.stdenv.isDarwin then
  { }
else
  {
    # Upstream postPatch removes a test file that doesn't exist on darwin.
    ollama = prev.ollama.overrideAttrs (old: {
      doCheck = false;
      postPatch =
        builtins.replaceStrings
          [ "rm model/models/nemotronh/model_omni_test.go" ]
          [ "rm -f model/models/nemotronh/model_omni_test.go" ]
          old.postPatch;
    });

    fishPlugins = prev.fishPlugins // {
      bass = prev.fishPlugins.bass.overrideAttrs (_: {
        doCheck = false;
      });
    };
  }
