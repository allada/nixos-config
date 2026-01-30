{ config, pkgs, ... }: {
  # Timezone and locale
  time.timeZone = "America/Chicago";
  
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

  environment.sessionVariables = {
    LD_LIBRARY_PATH = "/run/opengl-driver/lib";
  };

  hardware.ledger.enable = true;

  # Security and permissions
  security.rtkit.enable = true;
  programs.fuse.userAllowOther = true;

  # System services
  services = {
    locate.enable = true;
    printing.enable = true;
    fail2ban.enable = true;
  };

  services.openssh = {
    enable = true;
    ports = [ 2222 ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "allada" ];
    };
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
      vulkan-loader
      libz
    ];
  };

  # Allow unfree packages + enable CUDA support where available
  nixpkgs.config = {
    allowUnfree = true;
    cudaSupport = true;
  };
}
