#!/usr/bin/env bash
# iptables-captive.sh — Redirect HTTP/HTTPS/DNS traffic on wlan0 to the Pi
# so every connected client is forced through the captive portal.
#
# Run as root. Called by scripts/start-ap.sh on boot / AP start.

set -euo pipefail

WLAN_IF="wlan0"
PI_IP="192.168.4.1"

echo "[iptables-captive] Flushing existing nat rules on ${WLAN_IF}..."
iptables -t nat -F PREROUTING

echo "[iptables-captive] Redirecting HTTP (80) -> local Nginx..."
iptables -t nat -A PREROUTING -i "${WLAN_IF}" -p tcp --dport 80 -j DNAT --to-destination "${PI_IP}:80"

echo "[iptables-captive] Redirecting HTTPS (443) -> local Nginx (captive portal catch)..."
iptables -t nat -A PREROUTING -i "${WLAN_IF}" -p tcp --dport 443 -j DNAT --to-destination "${PI_IP}:80"

echo "[iptables-captive] Redirecting DNS (53) -> local dnsmasq..."
iptables -t nat -A PREROUTING -i "${WLAN_IF}" -p udp --dport 53 -j DNAT --to-destination "${PI_IP}:53"
iptables -t nat -A PREROUTING -i "${WLAN_IF}" -p tcp --dport 53 -j DNAT --to-destination "${PI_IP}:53"

echo "[iptables-captive] Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null

echo "[iptables-captive] Done. Current NAT table:"
iptables -t nat -L PREROUTING -n -v
