#!/usr/bin/env bash
# start-ap.sh — Bring up the MQTT Hub access point + all supporting services.
# Run as root (or via sudo).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "==> Unblocking WiFi (rfkill)..."
rfkill unblock wifi || true

echo "==> Restarting dhcpcd..."
systemctl restart dhcpcd

echo "==> Starting hostapd (WiFi AP)..."
systemctl unmask hostapd
systemctl restart hostapd

echo "==> Starting dnsmasq (DHCP + DNS)..."
systemctl restart dnsmasq

echo "==> Starting mosquitto (MQTT broker)..."
systemctl restart mosquitto

echo "==> Starting nginx (web + captive portal)..."
systemctl restart nginx

echo "==> Applying iptables captive-portal redirects..."
bash "${REPO_ROOT}/config/iptables-captive.sh"

echo "==> MQTT Hub is up."
echo "    SSID:      MQTT Hub"
echo "    Gateway:   192.168.4.1"
echo "    Dashboard: http://192.168.4.1/"
echo "    MQTT:      192.168.4.1:1883 (TCP) / :9001 (WebSocket)"
