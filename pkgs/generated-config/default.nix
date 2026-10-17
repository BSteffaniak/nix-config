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
runCommand "managed-${lib.strings.sanitizeDerivationName (baseNameOf target)}"
  {
    inherit source target repositoryPath;
    nativeBuildInputs = [ python3 ];
    preferLocalBuild = true;
    allowSubstitutes = false;
  }
  ''
    python ${./add-header.py}
  ''
