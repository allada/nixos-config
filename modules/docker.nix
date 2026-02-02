{ config, pkgs, ... }: {
  # Docker configuration
  virtualisation.docker = {
    enable = true;
    # Required for NVIDIA CDI device injection on NixOS.
    daemon.settings.features.cdi = true;
  };

  # Enable NVIDIA Container Toolkit for GPU-aware containers.
  hardware.nvidia-container-toolkit.enable = true;
}
