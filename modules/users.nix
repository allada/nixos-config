{ config, pkgs, ... }: {
  users.users.allada = {
    isNormalUser = true;
    description = "Blaise";
    extraGroups = [ "networkmanager" "wheel" "docker" "adbusers" ];
    packages = with pkgs; [
      # User-specific packages can go here
    ];
  };
}
