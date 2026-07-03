#!/usr/bin/env bash
# status.sh — Quick health check for all MQTT Hub services.

set -uo pipefail

services=(hostapd dnsmasq mosquitto nginx)

echo "=== MQTT Hub status ==="
for svc in "${services[@]}"; do
  if systemctl is-active --quiet "$svc"; then
    printf "  [ OK  ] %s\n" "$svc"
  else
    printf "  [DOWN ] %s\n" "$svc"
  fi
done

echo ""
echo "=== Listening ports ==="
ss -tulpn 2>/dev/null | grep -E ':(80|1883|9001|53)\b' || echo "  (none of the expected ports are listening)"

echo ""
echo "=== Connected WiFi clients ==="
if command -v iw >/dev/null 2>&1; then
  iw dev wlan0 station dump | grep -E 'Station|signal' || echo "  (no clients associated)"
else
  echo "  'iw' not installed, skipping"
fi

echo ""
echo "=== wlan0 address ==="
ip -4 addr show wlan0 2>/dev/null | grep inet || echo "  wlan0 has no IPv4 address"
