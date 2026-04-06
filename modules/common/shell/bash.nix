{
  lib,
  config,
  ...
}:

with lib;

{
  options.myConfig.shell.bash.enable = mkEnableOption "Bash shell";
}
