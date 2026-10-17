{ lib }:
let
  p = import ../agent-permissions.nix { inherit lib; };
  cfg = {
    autoDiscover = true;
    include = [ ];
    exclude = [ ];
    restricted = [ ];
    yolo = [ ];
  };
  generate =
    c:
    p.mkPermissions {
      permissionsDir = ../../../configs/agents/permissions;
      cfg = c;
      basePermissionConfig.agent = {
        build.permission.bash."*" = "allow";
        plan.permission.bash."*" = "deny";
      };
    };
in
builtins.mapAttrs
  (
    _: c:
    let
      shared = generate c;
    in
    {
      bcode = p.forBcode shared;
      pi = p.legacyJSON "pi" (p.forLegacyTarget "pi" shared);
      opencode = p.legacyJSON "opencode" (p.forLegacyTarget "opencode" shared);
    }
  )
  {
    normal = cfg;
    restricted = cfg // {
      restricted = [
        "git"
        "brew"
      ];
    };
    yolo = cfg // {
      yolo = [
        "git"
        "brew"
      ];
    };
  }
