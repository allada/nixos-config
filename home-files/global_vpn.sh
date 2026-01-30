#!/bin/env bash
set -e

if (( EUID != 0 )); then
  echo "Error: This script must be run with sudo or as root." >&2
  exit 1
fi

exec openvpn \
    --config /etc/openvpn/us.conf \
    --auth-user-pass /etc/nixos/secrets/vpn/auth.txt \
    --writepid /run/global-vpnspace-openvpn.pid
