{ config, pkgs, ... }: {
  users.users.allada = {
    isNormalUser = true;
    description = "Blaise";
    extraGroups = [ "networkmanager" "wheel" "docker" "adbusers" ];
    packages = with pkgs; [
      # User-specific packages can go here
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPuPw1rBr2mEK4s8mbeSQwd03SYAHCngdYTleaTC7q9z allada@nixos"
    ];
  };
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "unlimited";
    }
    {
      domain = "*";
      type = "hard";
      item = "nofile";
      value = "unlimited";
    }
  ];
}
