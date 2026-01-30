{ config, lib, pkgs, ... }:

let
  cfg = config.services.vpnspace;
  inherit (lib) mkEnableOption mkOption types mkIf mkMerge mkAfter;

  instanceType = types.submodule ({ name, config, ... }: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable this VPN namespace instance.";
      };

      netnsName = mkOption {
        type = types.str;
        default = "vpn-${name}";
        description = "Network namespace name.";
      };

      bridgeName = mkOption {
        type = types.str;
        default = "vpnbr-${name}";
        description = "Linux bridge name used by Docker.";
      };

      vethHost = mkOption {
        type = types.str;
        default = "veth-${name}h";
        description = "Host-side veth name (<=15 chars).";
      };

      vethNs = mkOption {
        type = types.str;
        default = "veth-${name}n";
        description = "Namespace-side veth name (<=15 chars).";
      };

      subnet = mkOption {
        type = types.str;
        example = "10.210.1.0/24";
        description = "Subnet used by the bridge and Docker network.";
      };

      hostAddress = mkOption {
        type = types.str;
        example = "10.210.1.1/24";
        description = "Bridge IP address (CIDR).";
      };

      nsAddress = mkOption {
        type = types.str;
        example = "10.210.1.2/24";
        description = "Namespace IP address (CIDR).";
      };

      gateway = mkOption {
        type = types.str;
        default = lib.head (lib.splitString "/" config.hostAddress);
        description = "Gateway IP inside the bridge subnet.";
      };

      tableId = mkOption {
        type = types.int;
        example = 210;
        description = "Policy routing table ID for this subnet.";
      };

      rulePrefMain = mkOption {
        type = types.int;
        default = config.tableId;
        description = "Policy rule preference for namespace IP -> main table.";
      };

      rulePrefSubnet = mkOption {
        type = types.int;
        default = config.tableId + 1;
        description = "Policy rule preference for subnet -> custom table.";
      };

      dnsServers = mkOption {
        type = types.listOf types.str;
        default = [ "1.1.1.1" "8.8.8.8" ];
        description = "DNS servers to write into /etc/resolv.conf inside the namespace.";
      };

      vpnIfName = mkOption {
        type = types.str;
        default = "tun0";
        description = "VPN interface name created by OpenVPN inside the namespace.";
      };

      openvpnConfigFile = mkOption {
        type = types.str;
        default = "/etc/nixos/openvpn/${name}.conf";
        description = "Path to the OpenVPN config file.";
      };

      authFile = mkOption {
        type = types.str;
        description = "Path to the OpenVPN auth-user-pass file.";
      };

      clusterId = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "ExpressVPN cluster_id used to download the .ovpn file when set.";
      };

      activationCodeFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Activation code file to use when downloading the .ovpn file.";
      };

      socks = mkOption {
        type = types.submodule {
          options = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Expose a SOCKS5 proxy for this VPN instance.";
            };

            bindAddress = mkOption {
              type = types.str;
              default = "127.0.0.1";
              description = "Host bind address for the SOCKS proxy.";
            };

            port = mkOption {
              type = types.int;
              default = 1080 + config.tableId;
              description = "Host port for the SOCKS proxy.";
            };

            internalPort = mkOption {
              type = types.int;
              default = 1080;
              description = "Port used by sockd inside the namespace.";
            };
          };
        };
        default = { };
        description = "SOCKS5 proxy settings for this VPN instance.";
      };

      openvpnExtraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Extra args passed to OpenVPN.";
      };

      dockerNetworkName = mkOption {
        type = types.str;
        default = "vpn-${name}";
        description = "Docker network name bound to the bridge.";
      };

      enableDockerNetwork = mkOption {
        type = types.bool;
        default = true;
        description = "Create a Docker network that uses the VPN bridge.";
      };
    };
  });

  enabledInstances = lib.filterAttrs (_: inst: inst.enable) cfg.instances;
  instanceList = lib.attrValues enabledInstances;

  mkVpnService = name: inst:
    let
      dnsConfig = lib.concatStringsSep "\n" (map (d: "nameserver ${d}") inst.dnsServers);
      dnsConfigEscaped = lib.escapeShellArg dnsConfig;
      openvpnArgs = lib.concatStringsSep " " (map lib.escapeShellArg inst.openvpnExtraArgs);
      activationCodeFile = if inst.activationCodeFile == null then cfg.activationCodeFile else inst.activationCodeFile;
      clusterIdStr = if inst.clusterId == null then "" else toString inst.clusterId;
    in {
      name = "vpn-${name}";
      value = {
        description = "VPN namespace (${name})";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        path = with pkgs; [
          bash
          iproute2
          iptables
          coreutils
          gawk
          gnused
          procps
          util-linux
          openvpn
          curl
        ];

        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = 5;
        };

        preStart = ''
          set -euo pipefail

          NS="${inst.netnsName}"
          BR="${inst.bridgeName}"
          VETH_HOST="${inst.vethHost}"
          VETH_NS="${inst.vethNs}"
          SUBNET="${inst.subnet}"
          HOST_ADDR="${inst.hostAddress}"
          NS_ADDR="${inst.nsAddress}"
          GW="${inst.gateway}"
          TABLE="${toString inst.tableId}"
          RULE_MAIN="${toString inst.rulePrefMain}"
          RULE_SUB="${toString inst.rulePrefSubnet}"

          NS_IP="''${NS_ADDR%/*}"

          if [ -n "${clusterIdStr}" ]; then
            OUT="${inst.openvpnConfigFile}"
            OUT_DIR="$(dirname "''${OUT}")"
            install -d -m 0700 "''${OUT_DIR}"

            if [ -z "${activationCodeFile}" ]; then
              echo "activationCodeFile must be set to download OpenVPN config" >&2
              exit 1
            fi
            CODE="$(tr -d '\n' < "${activationCodeFile}")"
            URL="https://www.expressvpn.com/custom_installer?cluster_id=${clusterIdStr}&code=$CODE&os=linux&source=web"
            curl -fsSL "''${URL}" -o "''${OUT}"
            if ! grep -q '^remote ' "''${OUT}"; then
              echo "Downloaded config missing remote line: ''${OUT}" >&2
              exit 1
            fi

            chmod 0400 "''${OUT}"
            chown root:root "''${OUT}"
          fi

          if ip netns list | grep -q "^''${NS}\\b"; then
            ip netns delete "''${NS}"
          fi

          ip link delete "''${VETH_HOST}" 2>/dev/null || true

          if ! ip link show "''${BR}" &>/dev/null; then
            ip link add name "''${BR}" type bridge
          fi
          ip addr replace "''${HOST_ADDR}" dev "''${BR}"
          ip link set "''${BR}" up

          ip link add "''${VETH_HOST}" type veth peer name "''${VETH_NS}"
          ip link set "''${VETH_HOST}" master "''${BR}"
          ip link set "''${VETH_HOST}" up

          ip netns add "''${NS}"
          ip link set "''${VETH_NS}" netns "''${NS}"
          ip netns exec "''${NS}" ip addr add "''${NS_ADDR}" dev "''${VETH_NS}"
          ip netns exec "''${NS}" ip link set "''${VETH_NS}" up
          ip netns exec "''${NS}" ip link set lo up
          ip netns exec "''${NS}" ip route add default via "''${GW}"

          ip netns exec "''${NS}" sysctl -w net.ipv4.ip_forward=1 >/dev/null
          ip netns exec "''${NS}" bash -c "printf '%s\n' ${dnsConfigEscaped} > /etc/resolv.conf"

          ip rule del pref "''${RULE_MAIN}" from "''${NS_IP}/32" table main 2>/dev/null || true
          ip rule del pref "''${RULE_SUB}" from "''${SUBNET}" table "''${TABLE}" 2>/dev/null || true
          ip route flush table "''${TABLE}" 2>/dev/null || true
          ip route add default via "''${NS_IP}" dev "''${BR}" table "''${TABLE}"
          ip rule add pref "''${RULE_MAIN}" from "''${NS_IP}/32" table main
          ip rule add pref "''${RULE_SUB}" from "''${SUBNET}" table "''${TABLE}"

          EXT_IF="$(ip -4 route get 1.1.1.1 | awk '{for (i=1; i<=NF; i++) if ($i == "dev") {print $(i+1); exit}}')"
          iptables -t nat -C POSTROUTING -s "''${NS_IP}/32" -o "''${EXT_IF}" -j MASQUERADE 2>/dev/null || \
          iptables -t nat -A POSTROUTING -s "''${NS_IP}/32" -o "''${EXT_IF}" -j MASQUERADE
        '';

        script = ''
          set -euo pipefail
          NS="${inst.netnsName}"

          exec ip netns exec "''${NS}" openvpn \
            --config ${lib.escapeShellArg inst.openvpnConfigFile} \
            --auth-user-pass ${lib.escapeShellArg inst.authFile} \
            ${openvpnArgs}
        '';

        postStart = ''
          set -euo pipefail

          NS="${inst.netnsName}"
          VETH_NS="${inst.vethNs}"
          SUBNET="${inst.subnet}"
          VPN_IF="${inst.vpnIfName}"

          for i in $(seq 1 40); do
            if ip netns exec "''${NS}" ip link show "''${VPN_IF}" &>/dev/null; then
              break
            fi
            sleep 0.5
          done

          if ! ip netns exec "''${NS}" ip link show "''${VPN_IF}" &>/dev/null; then
            echo "VPN interface ''${VPN_IF} not found in namespace ''${NS}" >&2
            exit 1
          fi

          ip netns exec "''${NS}" iptables -t nat -C POSTROUTING -s "''${SUBNET}" -o "''${VPN_IF}" -j MASQUERADE 2>/dev/null || \
          ip netns exec "''${NS}" iptables -t nat -A POSTROUTING -s "''${SUBNET}" -o "''${VPN_IF}" -j MASQUERADE
          ip netns exec "''${NS}" iptables -C FORWARD -i "''${VETH_NS}" -o "''${VPN_IF}" -j ACCEPT 2>/dev/null || \
          ip netns exec "''${NS}" iptables -A FORWARD -i "''${VETH_NS}" -o "''${VPN_IF}" -j ACCEPT
          ip netns exec "''${NS}" iptables -C FORWARD -i "''${VPN_IF}" -o "''${VETH_NS}" -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
          ip netns exec "''${NS}" iptables -A FORWARD -i "''${VPN_IF}" -o "''${VETH_NS}" -m state --state ESTABLISHED,RELATED -j ACCEPT
        '';

        postStop = ''
          set -euo pipefail

          NS="${inst.netnsName}"
          BR="${inst.bridgeName}"
          VETH_HOST="${inst.vethHost}"
          SUBNET="${inst.subnet}"
          NS_ADDR="${inst.nsAddress}"
          TABLE="${toString inst.tableId}"
          RULE_MAIN="${toString inst.rulePrefMain}"
          RULE_SUB="${toString inst.rulePrefSubnet}"

          NS_IP="''${NS_ADDR%/*}"

          EXT_IF="$(ip -4 route get 1.1.1.1 | awk '{for (i=1; i<=NF; i++) if ($i == "dev") {print $(i+1); exit}}')"
          iptables -t nat -D POSTROUTING -s "''${NS_IP}/32" -o "''${EXT_IF}" -j MASQUERADE 2>/dev/null || true

          ip rule del pref "''${RULE_MAIN}" from "''${NS_IP}/32" table main 2>/dev/null || true
          ip rule del pref "''${RULE_SUB}" from "''${SUBNET}" table "''${TABLE}" 2>/dev/null || true
          ip route flush table "''${TABLE}" 2>/dev/null || true

          ip netns delete "''${NS}" 2>/dev/null || true
          ip link delete "''${VETH_HOST}" 2>/dev/null || true

          ip link show "''${BR}" &>/dev/null && ip addr flush dev "''${BR}" || true
        '';
      };
    };

  mkDockerNetService = name: inst: {
    name = "vpn-${name}-docker-net";
    value = {
      description = "Docker network for VPN namespace (${name})";
      after = [ "docker.service" "vpn-${name}.service" ];
      requires = [ "docker.service" "vpn-${name}.service" ];
      wantedBy = [ "multi-user.target" ];

      path = with pkgs; [ docker ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail
        NET="${inst.dockerNetworkName}"
        BR="${inst.bridgeName}"
        SUBNET="${inst.subnet}"
        GW="${inst.gateway}"

        if ! docker network inspect "''${NET}" >/dev/null 2>&1; then
          docker network create \
            --driver=bridge \
            --subnet="''${SUBNET}" \
            --gateway="''${GW}" \
            -o com.docker.network.bridge.name="''${BR}" \
            -o com.docker.network.bridge.enable_ip_masquerade=false \
            "''${NET}"
        fi
      '';
    };
  };

  mkSocksService = name: inst: {
    name = "vpn-${name}-socks";
    value = {
      description = "SOCKS5 proxy for VPN namespace (${name})";
      after = [ "vpn-${name}.service" ];
      requires = [ "vpn-${name}.service" ];
      wantedBy = [ "multi-user.target" ];

      path = with pkgs; [
        bash
        coreutils
        iproute2
        dante
        socat
      ];

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 2;
      };

      script = ''
        set -euo pipefail

        NS="${inst.netnsName}"
        SOCKS_BIND="${inst.socks.bindAddress}"
        SOCKS_PORT="${toString inst.socks.port}"
        INTERNAL_PORT="${toString inst.socks.internalPort}"
        CONF="/run/vpn-${name}-danted.conf"

        cat > "''${CONF}" <<EOF
logoutput: stderr

internal: 127.0.0.1 port = ''${INTERNAL_PORT}
external: ${inst.vpnIfName}

socksmethod: none
clientmethod: none
user.notprivileged: nobody

client pass {
  from: 127.0.0.1/32 to: 0.0.0.0/0
  log: connect disconnect error
}

socks pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  protocol: tcp udp
  log: connect disconnect error
}
EOF

        chmod 0600 "''${CONF}"

        ip netns exec "''${NS}" sockd -f "''${CONF}" &
        SOCKD_PID=$!

        socat TCP-LISTEN:"''${SOCKS_PORT}",bind="''${SOCKS_BIND}",reuseaddr,fork \
          EXEC:"'ip netns exec ''${NS} socat STDIO TCP:127.0.0.1:''${INTERNAL_PORT}'" &
        SOCAT_PID=$!

        trap 'kill "''${SOCKD_PID}" "''${SOCAT_PID}" 2>/dev/null || true' INT TERM
        wait "''${SOCKD_PID}" "''${SOCAT_PID}"
      '';
    };
  };

in {
  options.services.vpnspace = {
    enable = mkEnableOption "VPN namespaces for region-specific Docker networking";

    activationCodeFile = mkOption {
      type = types.nullOr types.str;
      default = "/root/nixos/openvpn/activation_code";
      description = "Default activation code file used for cluster_id downloads.";
    };

    instances = mkOption {
      type = types.attrsOf instanceType;
      default = { };
      description = "VPN namespace instances keyed by region name.";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.trustedInterfaces =
      mkAfter (map (inst: inst.bridgeName) instanceList);

    systemd.services = mkMerge [
      (lib.mapAttrs' mkVpnService enabledInstances)
      (lib.mapAttrs' (name: inst: mkDockerNetService name inst) (lib.filterAttrs (_: inst: inst.enableDockerNetwork) enabledInstances))
      (lib.mapAttrs' (name: inst: mkSocksService name inst) (lib.filterAttrs (_: inst: inst.socks.enable) enabledInstances))
    ];
  };
}
