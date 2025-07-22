# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      inputs.home-manager.nixosModules.default
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Enable IP forwarding globally
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.forwarding" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # Docker configuration
  virtualisation.docker = {
    enable = true;
  };

  # Firewall rules for NAT and forwarding
  networking.firewall = {
    enable = true;
  };

  # Enhanced vpnspace service with proper dependencies
  systemd.services.vpnspace = {
    description = "VPN Namespace + SOCKS5 Proxy Bridge";
    after = [ "network-online.target" "docker.service" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];

    path = with pkgs; [
      iproute2
      iptables
      coreutils
      gnused
      gawk
      procps
      socat
      dante
      openvpn
      bash
      docker
      util-linux  # for nsenter
      nettools
    ];

    serviceConfig = {
      Type = "simple";
      ExecStartPre = pkgs.writeShellScript "vpnspace-pre" ''
        # Clean up any existing namespace
        if ip netns list | grep -q vpnspace; then
          ip netns delete vpnspace
        fi

        # Clean up any existing veth pair
        ip link delete veth0 2>/dev/null || true

        # Create veth pair
        ip link add veth0 type veth peer name veth1
        ip addr add 10.200.1.1/24 dev veth0
        ip link set veth0 up

        # Enable proxy ARP on host side
        echo 1 > /proc/sys/net/ipv4/conf/veth0/proxy_arp

        # Create namespace
        ip netns add vpnspace

        # Move veth1 to namespace
        ip link set veth1 netns vpnspace

        # Configure veth1 in namespace
        ip netns exec vpnspace ip addr add 10.200.1.2/24 dev veth1
        ip netns exec vpnspace ip link set veth1 up
        ip netns exec vpnspace ip link set lo up
        ip netns exec vpnspace ip route add default via 10.200.1.1

        # Enable forwarding in namespace
        ip netns exec vpnspace sysctl -w net.ipv4.ip_forward=1
        ip netns exec vpnspace bash -c "echo 'nameserver 1.1.1.1' > /etc/resolv.conf"

        iptables -t nat -C POSTROUTING -s 10.200.1.0/24 -o $(ip route get 1.1.1.1 | awk '{for (i=1; i<NF; i++) if ($i == "dev") print $(i+1)}') -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s 10.200.1.0/24 -o $(ip route get 1.1.1.1 | awk '{for (i=1; i<NF; i++) if ($i == "dev") print $(i+1)}') -j MASQUERADE
      '';
      
      ExecStart = pkgs.writeShellScript "vpnspace-start" ''
        # Start OpenVPN in namespace
        ip netns exec vpnspace openvpn \
          --config /root/nixos/openvpn/express.conf \
          --auth-user-pass /root/nixos/openvpn/auth.txt \
          --daemon --writepid /run/vpnspace-openvpn.pid

        # Wait for tun0
        echo "[*] Waiting for VPN interface (tun0)..."
        for i in {1..20}; do
          if ip netns exec "vpnspace" ip a show dev tun0 &>/dev/null; then
            echo "[*] tun0 is up"
            break
          fi
          sleep 0.5
        done

        # Start SOCKS5 proxy
        ip netns exec vpnspace sockd -f /etc/danted.conf &
        SOCKD_PID=$!
        echo $SOCKD_PID > /run/vpnspace-sockd.pid

        # Start socat bridge
        socat TCP-LISTEN:1080,bind=0.0.0.0,reuseaddr,fork 'EXEC:"ip netns exec vpnspace socat STDIO TCP:127.0.0.1:1080"' &
        SOCAT_PID=$!
        echo $SOCAT_PID > /run/vpnspace-socat.pid

        # Keep service running
        tail -f /dev/null
      '';
      
      ExecStop = pkgs.writeShellScript "vpnspace-stop" ''
        # Kill processes
        [ -f /run/vpnspace-socat.pid ] && kill $(cat /run/vpnspace-socat.pid) || true
        [ -f /run/vpnspace-sockd.pid ] && kill $(cat /run/vpnspace-sockd.pid) || true
        [ -f /run/vpnspace-openvpn.pid ] && kill $(cat /run/vpnspace-openvpn.pid) || true

        # Clean up namespace
        ip netns delete vpnspace || true

        # Remove veth pair
        ip link delete veth0 || true

        # Clean up PID files
        rm -f /run/vpnspace-*.pid
      '';
      
      Restart = "always";
      RestartSec = 5;
    };
  };

  environment.etc."danted.conf".text = '' 
logoutput: /var/log/danted.log

internal: 127.0.0.1 port = 1080
external: tun0

method: username none
user.notprivileged: nobody

client pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  log: connect disconnect error
}

pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  protocol: tcp udp
  log: connect disconnect error
}
'';

  services.openvpn.servers = {
    express = {
      config = ''
        config /root/nixos/openvpn/express.conf
        auth-user-pass /root/nixos/openvpn/auth.txt
        script-security 2
        persist-key
        persist-tun
      '';
      updateResolvConf = true;
      autoStart = false;
    };
  };
  services.envfs.enable = true;
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    openssl
    xorg.libX11
    xorg.libXcursor
    xorg.libxcb
    xorg.libXi
    libxkbcommon
    libz
  ];

  boot.initrd.luks.devices = {
    root = {
      device = "/dev/nvme0n1p2";
      preLVM = true;
    };
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable network manager applet
  programs.nm-applet.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/HongKong";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
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

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.locate.enable = true;

  # Enable the LXQT Desktop Environment.
  # services.xserver.displayManager.lightdm.enable = true;
  # services.xserver.desktopManager.plasma6.enable = true;
  # services.displayManager.sddm.wayland.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;

  # Enable bluetooth.
  hardware.bluetooth.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.allada = {
    isNormalUser = true;
    description = "Blaise";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    users = {
      "allada" = import ./home.nix;
    };
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    ledger-live-desktop
    openvpn
    jq
    lld
    pkg-config
    kubectx
    kubernetes-helm
    fuse
    redisinsight
    fuse3
    gcc14
    pre-commit
    go
    claude-code
    docker
    yarn
    openssl
    nvidia-docker
    bun
    bazelisk
    bazel-buildtools
    awscli2
    slack
    terminator
    google-chrome
    spotify
    wget
    git
    vim
    pnpm
    python3Minimal
    nodejs_22
    htop
    nmon
    nload
    iftop
    mktemp
    rustup
    kubectl
    net-tools
    killall
    dante
    socat
    rocmPackages.llvm.clang
    (vscode-with-extensions.override {
      vscodeExtensions = with vscode-extensions; [
        github.copilot
        bbenoist.nix
        ms-python.python
        ms-azuretools.vscode-docker
        ms-vscode-remote.remote-ssh
        rust-lang.rust-analyzer
        golang.go
        vue.volar
        bazelbuild.vscode-bazel
	ms-vscode-remote.remote-containers
        ms-kubernetes-tools.vscode-kubernetes-tools
        redhat.vscode-yaml
      ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          name = "remote-ssh-edit";
          publisher = "ms-vscode-remote";
          version = "0.47.2";
          sha256 = "1hp6gjh4xp2m1xlm1jsdzxw9d8frkiidhph6nvl24d0h8z34w49g";
        }
        {
          name = "proto";
          publisher = "peterj";
          version = "0.0.4";
          sha256 = "O8z9VPrR/i83SeT1cF6pFiFQNLu25NmQSu9NAyjoLww=";
        }
      ];
    })
  ];

  programs.fuse.userAllowOther = true;

  hardware.ledger.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
