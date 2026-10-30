# Shared public enrollment data. Never put private keys here.
# Managed identities come from hosts/*/meta.nix; only external hosts need identity data.
# The Macs and NixOS retain their existing client keys until dedicated-key enrollment.
{
  keys = {
    scar = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILwWidMp+nkWG5YU7/qxqUqcq0X6IMYWo9FYMTqCkpeN";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE5fHd3wdBw2WWpjCaSZYGoesCZDHHfoaVll+BJKDTk3";
    };
    nixos-desktop = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAB5PaZhj+szrHa9R+HLl1KsE//vo94NCoG1fjMmeW1s";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4bmG26A3jHhRzs+/ndbThThA/8gKxgZAlRf/ywfLBx";
    };
    macbook-air = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOvAhRTBNQsPhx5wvwaSKz2A5uFwybJwdKkVVY0Cjx1m";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxIpVnoIm3dH6fwL7QXCU3IHQteGty6MLK03gpMlVLH";
    };
    mac-studio = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB83E3j6v6bJdfUrzuid93KlLog60ke6NIQqHCWvmHjl";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICotB16Zn/uZoUJr0ZxQUzsbTRJv+lJCBsc77kJo0QgG";
    };
    windows-desktop = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE3d+IwaU22iepYcAz2NhZQ7gHI/4Eymx52pTVzXTGQn";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDZySxzEv9eHGyfcGHhqsGK/z7Qq21Ksjmj3uip1Vpz6";
    };
    ubuntu-laptop = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICB9kRSg8pc0N1Vt68W+IOKr8TgH2XS/pFl4xsyey3HA";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGP5c6F4QDNg/C1plqGwMIt6gyGPhPo9ebDbFw2+7csR";
    };
  };
  externalHosts = {
    scar = {
      hostname = "scar.local";
      username = "brade";
    };
    windows-desktop = {
      hostname = "desktop-tko79vi.local";
      username = "brade";
    };
  };
}
