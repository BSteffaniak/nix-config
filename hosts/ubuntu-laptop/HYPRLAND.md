# Ubuntu laptop: experimental Hyprland session

Ubuntu 24.04 keeps GNOME and GDM; Nix supplies an additional Hyprland session.
Enable it with `myConfig.desktop.hyprland.standalone.enable` in the host's
`home.nix`.
The standalone module uses Home Manager's generic-Linux GPU integration with
Nixpkgs Mesa drivers for the Intel GPU. No third-party apt repository or nixGL
input is required. Do not enable the shared `desktop.hyprland.enable` alongside
this option: that config has different desktop assumptions.

## Install

Install the host's PAM-integrated locker first. On Ubuntu:

```bash
sudo apt-get install swaylock
```

The generic setup does not install system packages or check the distribution
name. It requires systemd, sudo, a display manager using
`/usr/share/wayland-sessions`, and an executable system locker. Other
systemd-based distributions can use the same module, but must provide these
prerequisites themselves. GPU defaults here target Mesa; proprietary NVIDIA
requires separate matching-driver configuration.

The locker defaults to `/usr/bin/swaylock` with `-f -c 202020`. Override
`myConfig.desktop.hyprland.standalone.lockerExecutable` and `lockerArguments`
for another host-integrated locker. Presence checks cannot verify its PAM
configuration: test locking and unlocking before relying on it.

```bash
./rebuild.sh -b backup
setup-hyprland
```

Run setup as your normal user. It validates prerequisites before requesting sudo
to:

- Install/update Home Manager's `non-nixos-gpu.service`, including a GC root,
  to expose Nix graphics drivers at `/run/opengl-driver` across reboots.
- Register `/usr/share/wayland-sessions/hyprland-nix.desktop` using your stable
  Home Manager profile launcher.

It does not restart GDM, replace GNOME, or change your default session. After
setup, log out, select your account, use GDM's gear menu to select **Hyprland
(Nix)**, and log in. Save work before logging out.

If activation reports that GPU drivers need an update after a Nixpkgs update,
rerun `setup-hyprland` before entering a new Hyprland session.

## Controls

- Super+Q: Ghostty terminal
- Super+R: application launcher (Fuzzel)
- Super+C: close focused window
- Super+F: fullscreen
- Super+V: toggle floating
- Super+arrows: focus windows
- Super+1–9: workspace; add Shift to move a window
- Super+left/right mouse drag: move/resize
- Super+L: lock; idle lock also runs after ten minutes and before suspend
- Super+Shift+E: exit the session

Wi-Fi can be configured with Ubuntu Settings or `nmcli`; use `pavucontrol` for
audio. This is a minimal laptop session, not the shared desktop's wallpaper and
monitor layout. Brightness and volume keys are configured. Waybar,
notifications,
and a Polkit authentication agent start with the Hyprland session.

## Validate and recover

The Nix build and Hyprland config parser can be checked without starting a
compositor. Hardware acceleration, portal screen sharing, authentication,
brightness keys, and lock/suspend behavior still need an actual login test.
In particular, confirm locking and suspend work before relying on this session.

If anything fails, return to the login screen and select **Ubuntu** instead.
If necessary, switch to a text console (Ctrl+Alt+F3), log in, and inspect:

```bash
journalctl --user -b -u waybar -u swayidle -u hyprland-polkit-agent -u hyprland-mako
journalctl --user -b -u xdg-desktop-portal -u xdg-desktop-portal-hyprland
systemctl status non-nixos-gpu.service
```

To remove the login-screen entry:

```bash
sudo rm /usr/share/wayland-sessions/hyprland-nix.desktop
```

Then disable `myConfig.desktop.hyprland.standalone.enable` and rebuild. The GPU
service can remain for other Nix graphical applications; don't remove it while
such applications are running. GNOME and its original session entries are not
removed by this setup.
