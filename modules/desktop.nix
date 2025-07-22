{ config, pkgs, ... }: {
  # X11 and desktop environment
  services.xserver = {
    enable = true;
    desktopManager.gnome.enable = true;
    
    # Keyboard configuration
    xkb = {
      layout = "us";
      variant = "";
    };
  };
}
