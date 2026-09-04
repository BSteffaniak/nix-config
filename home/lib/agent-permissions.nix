{ lib }:

{
  mkPermissions =
    {
      permissionsDir,
      cfg,
      basePermissionConfig ? { },
      overrides ? [ ],
    }:
    let
      allPermissionFiles = builtins.attrNames (builtins.readDir permissionsDir);
      jsonPermissionFiles = builtins.filter (f: lib.hasSuffix ".json" f) allPermissionFiles;
      allNames = map (f: lib.removeSuffix ".json" f) jsonPermissionFiles;

      isVariant = name: lib.hasSuffix "-restricted" name || lib.hasSuffix "-yolo" name;
      baseNames = builtins.filter (name: !(isVariant name)) allNames;

      resolvePermissionFile =
        name:
        if builtins.elem name cfg.yolo then
          "${name}-yolo"
        else if builtins.elem name cfg.restricted then
          "${name}-restricted"
        else
          name;

      discoveredNames =
        let
          base = if cfg.autoDiscover then baseNames else cfg.include;
        in
        builtins.filter (name: !(builtins.elem name cfg.exclude)) base;

      resolvedNames = map resolvePermissionFile discoveredNames;

      permissionConfigs = map (
        name: builtins.fromJSON (builtins.readFile (permissionsDir + "/${name}.json"))
      ) (builtins.sort (a: b: a < b) resolvedNames);

      overrideConfigs = map (f: builtins.fromJSON (builtins.readFile f)) overrides;
    in
    lib.foldl' lib.recursiveUpdate basePermissionConfig (permissionConfigs ++ overrideConfigs);
}
