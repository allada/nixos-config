{ config, pkgs, ... }:

{
  networking = {
    hostName = "nixos";
    networkmanager.enable = true;
    
    # Firewall configuration
    firewall = {
      enable = true;
      # Add specific ports here as needed
      # allowedTCPPorts = [ ... ];
      # allowedUDPPorts = [ ... ];
    };
  };

  # Network manager applet
  programs.nm-applet.enable = true;
}
