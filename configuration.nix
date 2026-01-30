{ config, pkgs, inputs, ... }:

{
  imports = [
    # Hardware
    ./hardware-configuration.nix
    
    # Core system modules
    ./modules/boot.nix
    ./modules/networking.nix
    ./modules/users.nix
    ./modules/system.nix
    
    # Services
    ./modules/vpn.nix
    ./modules/desktop.nix
    ./modules/audio.nix
    ./modules/docker.nix
    
    # Programs and packages
    ./modules/programs.nix
    ./modules/packages.nix
    
    # Home manager
    inputs.home-manager.nixosModules.default
  ];

  # Global Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];


  # Home manager configuration
  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    backupFileExtension = "hm-bak";
    users = {
      "allada" = import ./home.nix;
    };
  };

  services.vpnspace = let
    vpnAuth = "/etc/nixos/secrets/vpn/auth.txt";
    vpnActivation = "/etc/nixos/secrets/vpn/activation_code";
    vpnDefaults = {
      authFile = vpnAuth;
      activationCodeFile = vpnActivation;
    };
  in {
    enable = true;
    instances = {
      # clusterId comes from the server URL at https://portal.expressvpn.com/setup#manual
      us = vpnDefaults // {
        enable = true;
        subnet = "10.230.1.0/24";
        hostAddress = "10.230.1.1/24";
        nsAddress = "10.230.1.254/24";
        tableId = 231;
        clusterId = 1;
      };
      jp = vpnDefaults // {
        enable = true;
        subnet = "10.230.2.0/24";
        hostAddress = "10.230.2.1/24";
        nsAddress = "10.230.2.254/24";
        tableId = 232;
        clusterId = 57;
      };
    };
  };

  # System version
  system.stateVersion = "24.05";
}
