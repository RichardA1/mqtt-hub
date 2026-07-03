#!/usr/bin/env bash
# start-ap.sh — Bring up the MQTT Hub access point + all supporting services.
# Run as root (or via sudo).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "==> Unblocking WiFi (rfkill)..."
rfkill unblock wifi || true
sleep 1

# Modern Raspberry Pi OS (Bookworm/Trixie) uses NetworkManager and has no
# dhcpcd.service at all. Older Raspberry Pi OS (Bullseye and earlier) uses
# dhcpcd. Detect which is present and do the right thing for each.
if systemctl list-unit-files dhcpcd.service &>/dev/null; then
  echo "==> dhcpcd detected — restarting it to apply the static wlan0 IP..."
  systemctl restart dhcpcd

elif systemctl list-unit-files NetworkManager.service &>/dev/null; then
  echo "==> NetworkManager detected — configuring wlan0 as unmanaged..."
  UNMANAGED_CONF="/etc/NetworkManager/conf.d/unmanaged-wlan0.conf"
  if [[ ! -f "$UNMANAGED_CONF" ]]; then
    cp "${REPO_ROOT}/config/networkmanager-unmanaged.conf" "$UNMANAGED_CONF"
    systemctl restart NetworkManager
    sleep 2
  fi

  echo "==> Assigning static IP to wlan0..."
  ip addr flush dev wlan0
  ip addr add 192.168.4.1/24 dev wlan0
  ip link set wlan0 up

else
  echo "!! Neither dhcpcd nor NetworkManager found — you'll need to set"
  echo "!! wlan0's static IP (192.168.4.1/24) manually for your network stack."
fi

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
