#!/usr/bin/env bash
# stop-ap.sh — Tear down the MQTT Hub access point and supporting services.
# Run as root (or via sudo).

set -euo pipefail

echo "==> Flushing captive-portal iptables rules..."
iptables -t nat -F PREROUTING || true

echo "==> Stopping nginx..."
systemctl stop nginx || true

echo "==> Stopping mosquitto..."
systemctl stop mosquitto || true

echo "==> Stopping dnsmasq..."
systemctl stop dnsmasq || true

echo "==> Stopping hostapd..."
systemctl stop hostapd || true

echo "==> MQTT Hub stopped. WiFi radio left up; run 'rfkill block wifi' to fully disable."
