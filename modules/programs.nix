{ config, pkgs, ... }: {
  programs = {
    # System programs
    firefox.enable = true;
    # adb.enable = true;

    # Shell tooling
    direnv.enable = true;
    direnv.nix-direnv.enable = true;
  };
}
