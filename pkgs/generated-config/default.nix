{
  lib,
  runCommand,
  python3,
}:
{
  source,
  target,
  repositoryPath,
}:
let
  # NixOS /etc sources may select a directory's contents with a trailing /*.
  # Annotate the directory, then preserve that selection for the /etc builder;
  # passing the wildcard to Python instead creates a dangling literal symlink.
  contents = lib.hasSuffix "/*" (toString source);
  wrapped =
    runCommand "managed-${lib.strings.sanitizeDerivationName (baseNameOf target)}"
      {
        source = lib.removeSuffix "/*" (toString source);
        inherit target repositoryPath;
        nativeBuildInputs = [ python3 ];
        preferLocalBuild = true;
        allowSubstitutes = false;
      }
      ''
        python ${./add-header.py}
      '';
in
if contents then "${wrapped}/*" else wrapped
