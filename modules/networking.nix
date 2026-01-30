{ config, pkgs, ... }:

{
  networking = {
    hostName = "nixos";
    hostId = "f42de4d4";
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

  # Network manager applet
  programs.nm-applet.enable = true;
}
