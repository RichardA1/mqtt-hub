#!/bin/bash
# Quick Prep Script for Pi Zero W - MQTT Hub Installation
# Run this on your Pi with: bash pi-prep-quickstart.sh

set -e

echo "=========================================="
echo "MQTT Hub - Pi Zero W Prep Script"
echo "=========================================="
echo ""

# Step 1: Update system
echo "[1/6] Updating system..."
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get autoremove -y
sudo apt-get autoclean

# Step 2: Install dependencies
echo "[2/6] Installing dependencies..."
sudo apt-get install -y \
  hostapd \
  dnsmasq \
  mosquitto \
  mosquitto-clients \
  nginx-light \
  iptables-persistent \
  git \
  curl \
  wget \
  rfkill \
  wireless-tools \
  wpasupplicant

# Step 3: Detect network stack
echo "[3/6] Detecting network stack..."
if sudo systemctl list-unit-files | grep -q "^NetworkManager.service.*enabled"; then
  echo "  ✓ NetworkManager detected (modern Bookworm/Trixie)"
  NETWORK_STACK="NetworkManager"
  
  # Create NetworkManager unmanaged config
  sudo mkdir -p /etc/NetworkManager/conf.d
  echo "  ✓ Creating unmanaged interface config..."
  sudo tee /etc/NetworkManager/conf.d/99-mqtt-hub-unmanaged.conf > /dev/null << 'EOF'
[keyfile]
unmanaged-devices=interface-name:wlan0
EOF
  
  sudo systemctl restart NetworkManager
  echo "  ✓ NetworkManager restarted"
else
  echo "  ✓ dhcpcd detected (older Raspberry Pi OS)"
  NETWORK_STACK="dhcpcd"
  sudo systemctl enable dhcpcd
  sudo systemctl start dhcpcd
  echo "  ✓ dhcpcd enabled and started"
fi

# Step 4: Check WiFi hardware
echo "[4/6] Checking WiFi hardware..."
if ip link show wlan0 > /dev/null 2>&1; then
  echo "  ✓ wlan0 interface found"
else
  echo "  ✗ wlan0 not found - you may need to set WiFi country"
  echo "    Run: sudo raspi-config"
  echo "    Then: Localisation Options → WiFi Country"
fi

if sudo rfkill list | grep -q "phy0.*Soft blocked: yes"; then
  echo "  ⚠ WiFi is soft-blocked, unblocking..."
  sudo rfkill unblock wifi
fi

# Step 5: Stop conflicting services
echo "[5/6] Stopping conflicting services..."
sudo systemctl stop hostapd 2>/dev/null || true
sudo systemctl disable hostapd 2>/dev/null || true
sudo systemctl stop dnsmasq 2>/dev/null || true
sudo systemctl disable dnsmasq 2>/dev/null || true
echo "  ✓ Services stopped and disabled"

# Step 6: Verify ethernet
echo "[6/6] Verifying internet connectivity (USB Ethernet)..."
if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
  echo "  ✓ Internet connectivity confirmed"
else
  echo "  ⚠ Warning: Could not reach 8.8.8.8"
  echo "    Check your USB ethernet adapter is connected"
fi

echo ""
echo "=========================================="
echo "Prep Complete! Next Steps:"
echo "=========================================="
echo ""
echo "1. Download or generate mqtt-hub project"
echo "2. Copy mqtt-hub to ~/projects/mqtt-hub"
echo "3. Run: sudo ~/projects/mqtt-hub/setup.sh"
echo "4. Verify with: sudo systemctl status mqtt-hub.service"
echo ""
echo "Network Stack Detected: $NETWORK_STACK"
echo ""
echo "Questions? Check:"
echo "  • sudo journalctl -xe (for errors)"
echo "  • /var/log/syslog (system log)"
echo "=========================================="
