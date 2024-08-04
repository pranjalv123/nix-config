{
  modulesPath,
  config,
  lib,
  pkgs,
  ...
}: {
  systemd.services.mount_fs = {
    wantedBy = ["basic.target"];

    script = ''
      mkdir -p /persist
      /run/current-system/sw/bin/mount -t virtiofs persist /persist
    '';
  };
}
