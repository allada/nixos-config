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

  # Hardware support
  hardware = {
    bluetooth.enable = true;
    ledger.enable = true;
  };

hardware.graphics = {
  enable = true;
  extraPackages = with pkgs; [
    vulkan-loader
    vulkan-validation-layers
  ];
};  
# (use hardware.opengl.enable = true; on older releases)

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    open = false; # set explicitly if you need proprietary vs open module behavior
    nvidiaSettings = true;
  };

  environment.sessionVariables = {
    LD_LIBRARY_PATH = "/run/opengl-driver/lib";
  };

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
