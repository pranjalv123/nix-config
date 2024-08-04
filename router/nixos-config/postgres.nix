{
  config,
  lib,
  pkgs,
  ...
}:{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    settings.timezone = "America/New_York";

    authentication = pkgs.lib.mkOverride 10 ''
      #type database  DBuser  auth-method
      local all       all     trust
      host samerole all 127.0.0.1/32 md5
    '';
  };
}