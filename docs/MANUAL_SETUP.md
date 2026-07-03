# Manual Setup

This walks through everything `setup.sh` automates, step by step, for anyone
who wants to understand or customize the install instead of running the
script blind.

Target platform: Raspberry Pi Zero W, Raspberry Pi OS Lite (Bullseye or
Bookworm), fresh install with SSH access.

## 1. Update the system

```bash
sudo apt-get update && sudo apt-get upgrade -y
```

## 2. Install packages

```bash
sudo apt-get install -y hostapd dnsmasq mosquitto mosquitto-clients nginx iptables
```

## 3. Configure hostapd (the WiFi AP)

Copy `config/hostapd.conf` to `/etc/hostapd/hostapd.conf`. Before doing so,
**change the `wpa_passphrase` line** away from the placeholder
`ChangeMe_MqttHub!`.

```bash
sudo cp config/hostapd.conf /etc/hostapd/hostapd.conf
```

Point the hostapd daemon at this file:

```bash
echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' | sudo tee -a /etc/default/hostapd
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
```

## 4. Configure dnsmasq (DHCP + DNS hijack)

```bash
sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.orig   # back up the original
sudo cp config/dnsmasq.conf /etc/dnsmasq.conf
sudo systemctl enable dnsmasq
```

## 5. Give wlan0 a static IP

Append the contents of `config/dhcpcd.conf` to `/etc/dhcpcd.conf`:

```bash
cat config/dhcpcd.conf | sudo tee -a /etc/dhcpcd.conf
```

This takes `wlan0` out of client mode (`nohook wpa_supplicant`) and pins it
to `192.168.4.1/24`.

## 6. Configure Mosquitto

```bash
sudo cp config/mosquitto.conf /etc/mosquitto/conf.d/mqtt-hub.conf
sudo systemctl enable mosquitto
```

This opens `1883` (raw MQTT, for WLED devices) and `9001` (MQTT over
WebSocket, for the browser dashboard).

## 7. Deploy the web dashboard

```bash
sudo mkdir -p /var/www/mqtt-hub
sudo cp -r web/* /var/www/mqtt-hub/
```

## 8. Configure Nginx

```bash
sudo cp config/nginx-mqtt-hub /etc/nginx/sites-available/mqtt-hub
sudo ln -sf /etc/nginx/sites-available/mqtt-hub /etc/nginx/sites-enabled/mqtt-hub
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable nginx
```

`nginx -t` should report the config is fine before you proceed. This site
serves the dashboard on `/`, proxies MQTT-over-WebSocket at `/mqtt`, and
returns 302s for every OS's captive-portal check URL (see the file for the
full list).

## 9. Apply captive-portal iptables rules

```bash
sudo bash config/iptables-captive.sh
```

This DNATs port 80/443 to Nginx and port 53 to dnsmasq for anything arriving
on `wlan0`, so clients can't dodge the portal by hardcoding a DNS server.

Note: these rules are **not persistent** across reboots by default. Either
run `scripts/start-ap.sh` on boot (e.g. via a systemd unit or `cron @reboot`)
or install `iptables-persistent` and save the rules with `netfilter-persistent
save`.

## 10. Bring it all up

```bash
sudo reboot
```

or, without rebooting:

```bash
sudo scripts/start-ap.sh
```

## 11. Verify

```bash
sudo scripts/status.sh
```

You should see `hostapd`, `dnsmasq`, `mosquitto`, and `nginx` all `[ OK ]`,
and ports `80`, `1883`, `9001`, and `53` listening.

Join the `MQTT Hub` WiFi network from another device — you should get a
captive-portal prompt within a few seconds, or you can browse directly to
`http://192.168.4.1/`.
