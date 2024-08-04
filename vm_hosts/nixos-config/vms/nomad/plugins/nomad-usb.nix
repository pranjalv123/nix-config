{
  stdenv,
  fetchzip,
  pkgs,
  buildGoModule
}:

buildGoModule {
  pname = "nomad-usb";
  version = "v0.4.0";

  src = fetchzip {
    url = "https://gitlab.com/CarbonCollins/nomad-usb-device-plugin/-/archive/0.4.0/nomad-usb-device-plugin-0.4.0.zip";
    sha256 = "k5L07CzQkY80kHszCLhqtZ0LfGGuV07LrHjvdgy04bk=";
  };
  buildInputs = [ pkgs.go pkgs.nomad pkgs.libusb1 ];
  nativeBuildInputs = [ pkgs.pkg-config pkgs.libusb1 ];
  vendorHash = "sha256-gf2E7DTAGTjoo3nEjcix3qWjHJHudlR7x9XJODvb2sk=";
#
#  configurePhase = ''
#    echo "Configuring...";
#    whoami;
#    mkdir /tmp/tmp-build;
#    export HOME=/tmp/tmp-build;
#  '';
}