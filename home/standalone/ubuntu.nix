# Ubuntu-specific tweaks for standalone home-manager.
{
  lib,
  pkgs,
  ...
}:

{
  # Help Nix-built programs find locale data on Ubuntu
  home.sessionVariables.LOCALE_ARCHIVE = lib.mkIf pkgs.stdenv.isLinux "${pkgs.glibcLocales}/lib/locale/locale-archive";

  # Ubuntu uses systemd for user services
  systemd.user.startServices = "sd-switch";
}
