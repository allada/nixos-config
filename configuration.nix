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
    users = {
      "allada" = import ./home.nix;
    };
  };

  # System version
  system.stateVersion = "24.05";
}
