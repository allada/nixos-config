{ config, pkgs, ... }: {
  # Timezone and locale
  time.timeZone = "Asia/HongKong";
  
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  # Hardware support
  hardware = {
    bluetooth.enable = true;
    ledger.enable = true;
  };

  # Security and permissions
  security.rtkit.enable = true;
  programs.fuse.userAllowOther = true;

  # System services
  services = {
    locate.enable = true;
    printing.enable = true;
  };

  # Development environment
  services.envfs.enable = true;
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      openssl
      xorg.libX11
      xorg.libXcursor
      xorg.libxcb
      xorg.libXi
      libxkbcommon
      libz
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
}
