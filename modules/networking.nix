{ config, pkgs, ... }:

{
  networking = {
    hostName = "nixos";
    networkmanager.enable = true;
    enableIPv6 = false;
    
    # Firewall configuration
    firewall = {
      enable = true;
      # Add specific ports here as needed
      allowedTCPPortRanges = [
        { from = 4000; to = 4010; }
        { from = 2222; to = 2222; }
      ];
      allowedUDPPortRanges = [
        { from = 4000; to = 4010; }
      ];
    };
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

  # Network manager applet
  programs.nm-applet.enable = true;
}
