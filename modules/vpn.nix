{ config, pkgs, ... }: {
  # VPN namespace service with SOCKS5 proxy
  systemd.services.vpnspace = {
    description = "VPN Namespace + SOCKS5 Proxy Bridge";
    after = [ "network-online.target" "docker.service" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];

    path = with pkgs; [
      iproute2 iptables coreutils gnused gawk procps
      socat dante openvpn bash docker util-linux nettools
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

        # Set up NAT rules
        iptables -t nat -C POSTROUTING -s 10.200.1.0/24 -o $(ip route get 1.1.1.1 | awk '{for (i=1; i<NF; i++) if ($i == "dev") print $(i+1)}') -j MASQUERADE 2>/dev/null || \
        iptables -t nat -A POSTROUTING -s 10.200.1.0/24 -o $(ip route get 1.1.1.1 | awk '{for (i=1; i<NF; i++) if ($i == "dev") print $(i+1)}') -j MASQUERADE
      '';
      
      ExecStart = pkgs.writeShellScript "vpnspace-start" ''
        # Start OpenVPN in namespace
        ip netns exec vpnspace openvpn \
          --config /root/nixos/openvpn/express.conf \
          --auth-user-pass /root/nixos/openvpn/auth.txt \
          --daemon --writepid /run/vpnspace-openvpn.pid

        # Wait for VPN interface
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

        # Clean up namespace and network
        ip netns delete vpnspace || true
        ip link delete veth0 || true

        # Clean up PID files
        rm -f /run/vpnspace-*.pid
      '';
      
      Restart = "always";
      RestartSec = 5;
    };
  };

  # Dante SOCKS5 proxy configuration
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

  # OpenVPN service configuration
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
}
