#!/usr/bin/env bash
# setup.sh — Automated installer for MQTT Hub on a Raspberry Pi Zero W
# running Raspberry Pi OS (Bullseye/Bookworm, Debian-based).
#
# What this does:
#   1. apt-get installs hostapd, dnsmasq, mosquitto, nginx, iptables
#   2. Copies config/ files into place
#   3. Copies web/ into /var/www/mqtt-hub
#   4. Enables + starts services
#   5. Applies the captive-portal iptables rules
#
# Run as root:  sudo ./setup.sh

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo ./setup.sh" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_ROOT="/var/www/mqtt-hub"

echo "############################################"
echo "#  MQTT Hub — Pi Zero W setup               #"
echo "############################################"
echo ""
echo "!! Remember to change the WiFi password in config/hostapd.conf"
echo "!! before (or right after) running this script. It currently ships"
echo "!! with the placeholder passphrase 'ChangeMe_MqttHub!'."
echo ""
read -r -p "Continue with install? [y/N] " confirm
if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

echo "==> Updating apt and installing packages..."
apt-get update
apt-get install -y hostapd dnsmasq mosquitto mosquitto-clients nginx iptables dnsutils

echo "==> Stopping services while we configure them..."
systemctl stop hostapd dnsmasq mosquitto nginx || true

echo "==> Installing hostapd.conf..."
cp "${REPO_ROOT}/config/hostapd.conf" /etc/hostapd/hostapd.conf
sed -i 's|^#DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd 2>/dev/null || \
  echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' >> /etc/default/hostapd

echo "==> Installing dnsmasq.conf..."
if [[ -f /etc/dnsmasq.conf && ! -f /etc/dnsmasq.conf.orig ]]; then
  cp /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
fi
cp "${REPO_ROOT}/config/dnsmasq.conf" /etc/dnsmasq.conf

echo "==> Appending static-IP block to dhcpcd.conf..."
if ! grep -q "MQTT Hub static wlan0" /etc/dhcpcd.conf 2>/dev/null; then
  {
    echo ""
    echo "# --- MQTT Hub static wlan0 ---"
    cat "${REPO_ROOT}/config/dhcpcd.conf"
  } >> /etc/dhcpcd.conf
fi

echo "==> Installing mosquitto.conf..."
cp "${REPO_ROOT}/config/mosquitto.conf" /etc/mosquitto/conf.d/mqtt-hub.conf

echo "==> Installing nginx site config..."
cp "${REPO_ROOT}/config/nginx-mqtt-hub" /etc/nginx/sites-available/mqtt-hub
ln -sf /etc/nginx/sites-available/mqtt-hub /etc/nginx/sites-enabled/mqtt-hub
rm -f /etc/nginx/sites-enabled/default

echo "==> Deploying web assets to ${WEB_ROOT}..."
mkdir -p "${WEB_ROOT}"
cp -r "${REPO_ROOT}/web/"* "${WEB_ROOT}/"

echo "==> Validating nginx config..."
nginx -t

echo "==> Enabling services on boot..."
systemctl unmask hostapd
systemctl enable hostapd dnsmasq mosquitto nginx

echo "==> Starting services..."
bash "${REPO_ROOT}/scripts/start-ap.sh"

echo ""
echo "############################################"
echo "#  Setup complete!                          #"
echo "############################################"
echo "SSID:      MQTT Hub"
echo "Password:  (see config/hostapd.conf — change it!)"
echo "Dashboard: http://192.168.4.1/"
echo ""
echo "Run scripts/status.sh any time to check service health."
