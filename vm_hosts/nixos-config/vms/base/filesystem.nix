{
  modulesPath,
  config,
  lib,
  pkgs,
  ...
}: {
  systemd.services.mount_fs = {
    wantedBy = ["basic.target"];

    # Without an explicit Type this defaulted to "simple", so systemd considered
    # the unit started the moment the script forked. Everything ordered
    # After=mount_fs.service therefore raced the mount and saw an empty /persist
    # (copy_ssh_keys died on `ls /persist/ssh_keys`). oneshot + RemainAfterExit
    # makes the ordering mean what it looks like it means.
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      mkdir -p /persist
      if ! ${pkgs.util-linux}/bin/mountpoint -q /persist; then
        /run/current-system/sw/bin/mount -t virtiofs persist /persist
      fi
    '';
  };
}
