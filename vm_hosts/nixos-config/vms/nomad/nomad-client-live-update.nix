{
  modulesPath,
  config,
  lib,
  pkgs,
  ...
}:
{
    boot.loader.grub.devices = ["/dev/vda"];

boot.initrd.availableKernelModules = [ "ahci" "virtio_pci" "xhci_pci" "virtio_blk" ];
     boot.initrd.kernelModules = [ ];
     boot.kernelModules = [ "kvm-amd" ];
     boot.extraModulePackages = [ ];

     fileSystems."/" =
     lib.mkDefault
       { device = "/dev/disk/by-label/nixos";
         fsType = "ext4";
       };

     fileSystems."/persist" =
     lib.mkDefault
       { device = "persist";
         fsType = "virtiofs";
       };

     fileSystems."/boot" =
     lib.mkDefault
       { device = "/dev/vda1";
         fsType = "vfat";
         options = [ "fmask=0077" "dmask=0077" ];
       };}