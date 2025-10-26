{ config, pkgs, ... }: {
  # System programs
  programs = {
    firefox.enable = true;
    
    adb.enable = true;

    # Development tools
    nm-applet.enable = true;
  };
}
