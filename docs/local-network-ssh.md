# Local-network SSH

Hosts use their `hosts/<name>/` directory name for their local-network address
and SSH alias. The SSH username comes from that host's `meta.nix`. Existing
system hostnames remain unchanged so rebuild auto-detection keeps working.

| Alias           | Address               | User          |
| --------------- | --------------------- | ------------- |
| `mac-studio`    | `mac-studio.local`    | `bsteffaniak` |
| `macbook-air`   | `macbook-air.local`   | `braden`      |
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

## Dedicated fleet credentials (Home Manager)

`myConfig.shell.ssh.fleet.enable = true` enables a dedicated
`~/.ssh/id_ed25519_fleet` identity. Ubuntu opts in first; leave other hosts on
existing identities until their new public keys have been enrolled. Generation
runs locally during activation, not during evaluation or builds. The key has no
passphrase for unattended LAN logins; the private file is mode 0600 and never
belongs in Git or the Nix store. Existing keys are not replaced. A lost private
key requires explicit re-enrollment; an orphaned public key is not silently
rotated.

Enrollment is a two-pass process:

1. Build and activate Home Manager on the originating computer to generate its
   key. Read only `~/.ssh/id_ed25519_fleet.pub` for enrollment.
2. Add that public key to `myConfig.shell.ssh.fleet.peers.<alias>.publicKey`
   on the receiving computers. Rebuild and activate those configurations before
   testing the dedicated identity. Add shared public enrollment data to a shared
   home module only when it is not host-private content.

For example (replace the illustrative key strings with real public keys):

```nix
myConfig.shell.ssh.fleet = {
  enable = true;
  peers.mac-studio = {
    publicKey = "ssh-ed25519 <client-public-key>";
    hostKey = "ssh-ed25519 <verified-server-public-key>";
    hostNames = [ "mac-studio" "mac-studio.local" ];
  };
};
```

Verify server fingerprints on the destination's console before enrolling
`hostKey`; `ssh-keyscan` alone does not authenticate a server. Home Manager
writes
public server keys to `.ssh/fleet_known_hosts` and enables strict verification
for fleet aliases, retaining the normal known-hosts file as a fallback. Fleet
identities are limited to the generated aliases (including the Windows aliases),
not GitHub or arbitrary SSH destinations. Explicit identity settings remain
usable as overrides.

Authorized keys are maintained in a marked block within `authorized_keys`;
other entries are preserved and changed files are backed up. Removing a peer
revokes its entry in that block on the next activation. Copies previously added
outside the block remain authorized and must be separately reviewed for full
revocation. A symlinked `authorized_keys` is refused rather than overwritten.
Disabling the feature does not delete credentials or revoke access; remove peer
entries and activate while enabled before disabling it.

Windows is not managed by Home Manager: retain its locally generated dedicated
fleet key and install enrolled client keys in the SSH server's configured
authorization file with its existing ACLs. The Ubuntu SSH server, Avahi, and
firewall still need the OS setup below. This feature does not enable a server.

Regression checks: `python3 scripts/test-ssh-fleet.py`. After enrollment, test
fresh connections with `BatchMode=yes`, `ControlPath=none`, and
`StrictHostKeyChecking=yes`; installed keys alone do not prove connectivity.

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

## Windows desktop

The external Windows host already runs Bonjour and resolves as
`desktop-tko79vi.local`. Shared Home Manager configuration provides the
`windows-desktop` alias with user `brade`, without representing Windows as a
Nix-managed host or renaming its computer. Activate the client configuration
before using `ssh windows-desktop`. Each client needs its own public key
installed on Windows; alias generation does not grant access. For this Windows
administrator account, the existing SSH configuration uses
`C:\ProgramData\ssh\administrators_authorized_keys` (shared across administrator
accounts), with access restricted to SYSTEM and Administrators.

## Scar laptop

The Windows laptop `Scar` resolves as `scar.local`; the shared `scar` alias logs
in as `brade`. Activate the client configuration before using `ssh scar`.
Its existing OpenSSH firewall rule permits Private networks only. On trusted
home Wi-Fi, mark the connection Private rather than adding a duplicate firewall
rule; leave public/untrusted networks Public. Key authorization is separate from
network discovery, and each client must have its public key installed.

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
