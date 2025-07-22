{ config, pkgs, ... }: {
  # Disable PulseAudio in favor of PipeWire
  services.pulseaudio.enable = false;
  
  # PipeWire configuration
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # Uncomment for JACK applications
    # jack.enable = true;
  };
}
