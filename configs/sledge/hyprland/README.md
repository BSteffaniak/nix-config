# Sledge on this Hyprland host

Enable `myConfig.desktop.sledge.enable` in the host Home Manager configuration.
NixOS registers the matching ordered login package with GDM and makes
**Hyprland (Sledge)** the default. GDM may remember a previous session
selection;
choose that entry once if it still selects ordinary Hyprland. After that, log in
normally: no startup command is required. Ordinary **Hyprland** remains
recovery.

Build before switching. Native/plugin/compiler/compositor changes must match an
accepted bundle; incompatible updates fail closed. Do not load the plugin or run
the session launcher inside an existing desktop. Build does not activate
anything.
The manual `sledge-hyprland-session` helper is internal/recovery plumbing, not
the
normal user workflow.

Both Linux and macOS use `configs/sledge/config.toml`, deployed as
`~/.config/sledge/config.toml` (or under `XDG_CONFIG_HOME`). It includes global
triple-tap RightAlt → Ctrl+Enter and terminal-scoped Ctrl+; → Ctrl+s, Alt+k
→ Alt+t.
Taps use a 600ms maximum gap between consecutive releases. Input-source actions
are unsupported by this backend. Inspect application classes before adding
aliases.

Inside the session, ordinary commands work without private socket arguments:

```sh
sledge status
sledge reload
```

A private session marker is published only after supported operational
readiness.
Explicit `--socket` wins; unsafe/stale session selection fails without searching
other sessions. Running from a TTY without session environment is not discovery
of
an arbitrary desktop.

Startup validates config/artifact bindings before loading and launches remaining
apps only after readiness. Errors identify the retained session diagnostics.
Controlled wrapper logout drains/detaches and requires acknowledged unload
before
signaling the compositor; a drain timeout retains potentially owning components.
Abrupt compositor death is separately supervised with pidfds. No blind restart,
forced plugin unload or automatic fallback is used. `sledge-hyprland-drain`
remains
an advanced helper, not a substitute for normal login/logout integration.

`hyprland/{contract,evidence,acceptance}.json` are internal maintainer-reviewed
bundle inputs, not user-editable compatibility settings. The exact native plugin
passed independent VM tap/lock/IME checks. Fresh actual packaged Desktop Exec
validation also passed inherited CLI status/reload, repeated taps, same-file
reload and ordered detach → exact daemon exit → unload → compositor exit.
Evidence: `/hdd/sledge-usability-vm/vm5.log` (SHA256
`87d8ee84c67f438f2a44575cdd3d05597b03a86b15a137f0cba57b7959f33c76`).
Actual physical-host GDM authentication/login remains unverified.
No claim of broad ABI support or complete macOS parity is made.

The local `sledge-hyprland-src` input is `/hdd/GitHub/sledge`. Refreshing its
lock
updates the daemon/helpers; native edits require new qualified artifacts. This
local dependency is intentionally not portable to your other hosts. Keep the
checkout available or publish/pin the reviewed source before moving machines.

Git-backed flakes omit untracked files. Stage new integration files yourself
before your usual rebuild, or use an explicit `path:/home/braden/.config/nix`
flake reference while validating the working tree. The agent does not stage or
commit files.
