# Local-network SSH

Hosts use their `hosts/<name>/` directory name for their local-network address
and SSH alias. The SSH username comes from that host's `meta.nix`. Existing
system hostnames remain unchanged so rebuild auto-detection keeps working.

| Alias           | Address               | User          |
| --------------- | --------------------- | ------------- |
| `mac-studio`    | `mac-studio.local`    | `bsteffaniak` |
| `macbook-air`   | `macbook-air.local`   | `braden`      |
| `bs-mbpro`      | `bs-mbpro.local`      | `braden`      |
| `nixos-desktop` | `nixos-desktop.local` | `braden`      |
| `ubuntu-laptop` | `ubuntu-laptop.local` | `braden`      |

This table illustrates the current inventory; configuration is generated from
host discovery, not this table. No IP reservations or router DNS entries are
needed.

## Managed hosts

The host builder sets Bonjour's `networking.localHostName` on Darwin and
`services.avahi.hostName` on NixOS. NixOS must also enable
`myConfig.services.avahi.enable` (already enabled on the desktop), which handles
advertising, `.local` resolution, and the mDNS firewall rule.

Home Manager generates aliases whenever `myConfig.shell.ssh.enable` is enabled.
Set `myConfig.shell.ssh.fleetAliases.enable = false` to opt out. An explicit
`myConfig.shell.ssh.matchBlocks.<alias>` replaces that generated alias block;
existing GitHub blocks are unaffected. Aliases do not enable an SSH server or
install keys. Existing SSH-server enablement and authentication settings are
unchanged. Private host files stay encrypted; their shared builder defaults can
only be fully validated on a machine where those files are unlocked.

Build before switching each destination's system configuration and each client's
Home Manager configuration. Nothing takes effect on other machines merely by
updating this checkout.

## Ubuntu (standalone Home Manager)

Home Manager configures the SSH client, not OS services. On the Ubuntu laptop,
install and enable mDNS through the OS (review these commands before running):

```sh
sudo apt install avahi-daemon avahi-utils libnss-mdns openssh-server
sudo systemctl enable --now avahi-daemon ssh
```

In the existing `[server]` section of `/etc/avahi/avahi-daemon.conf`, set:

```ini
[server]
host-name=ubuntu-laptop
```

Then restart Avahi with `sudo systemctl restart avahi-daemon`. Check that
`/etc/nsswitch.conf`'s `hosts:` line includes `mdns4_minimal [NOTFOUND=return]`
before `dns`; retain existing distro resolver entries. If using UFW, allow mDNS
(UDP 5353) and SSH only on the trusted LAN interface/subnet, not globally.
Do not enable incoming SSH if this machine should only be a client. Configure
its authorized public keys separately; never copy private keys between hosts.

## Verification

On a configured client:

```sh
ssh -G mac-studio # check hostname and user without connecting
ssh mac-studio
scp file.txt mac-studio:~/Downloads/
```

For name resolution, use `getent hosts mac-studio.local` on Linux or
`dns-sd -G v4v6 mac-studio.local` on macOS (stop with Ctrl-C). On a Mac, inspect
the advertised name with `scutil --get LocalHostName`; on NixOS, inspect
`systemctl status avahi-daemon`.

Bonjour/Avahi uses mDNS on the local network. Guest Wi-Fi isolation, multicast
filtering, VLAN boundaries, sleep, and duplicate names can prevent access or
cause a renamed advertisement. This is not remote access. Keep SSH host-key
verification enabled and verify unexpected key changes rather than bypassing it.
