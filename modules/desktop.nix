{ config, pkgs, ... }: {
  services.desktopManager.gnome.enable = true;

  # X11 and desktop environment
  services.xserver = {
    enable = true;
    
    # Keyboard configuration
    xkb = {
      layout = "us";
      variant = "";
    };
  };
}
