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
  boot.supportedFilesystems = ["zfs"];

  boot.extraModprobeConfig = ''
    options zfs zfs_arc_max=8589934592
  '';
  boot.zfs.extraPools = [ "tank" ];

  # ZFS services
  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
    autoSnapshot.enable = false;
  };

  # Kernel parameters for networking
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.forwarding" = 1;
    "net.ipv6.conf.all.forwarding" = 0;
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
    "net.ipv6.conf.lo.disable_ipv6" = 1;
    "net.ipv4.conf.all.proxy_arp" = 1;
    "fs.file-max" = 10000000;
  };
}
