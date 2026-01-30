{ config, pkgs, ... }: {
  # LUKS encryption
#  boot.initrd.luks.devices = {
#    root = {
#      device = "/dev/nvme0n1p2";
#      preLVM = true;
#    };
#  };

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages;

}
