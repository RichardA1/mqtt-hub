# Troubleshooting

## Run this first

```bash
sudo scripts/status.sh
```

It checks all four services (`hostapd`, `dnsmasq`, `mosquitto`, `nginx`),
the ports they should be listening on, connected WiFi clients, and `wlan0`'s
IP address. Most problems below show up here first.

---

## The `MQTT Hub` network doesn't appear at all

- `hostapd` isn't running: `sudo systemctl status hostapd`. Check
  `sudo journalctl -u hostapd -n 50` for errors.
- Common cause: `wlan0` is rfkill-blocked. Run `rfkill list` — if `wlan0`
  shows `Soft blocked: yes`, run `sudo rfkill unblock wifi`.
- Another common cause: `dhcpcd` or `wpa_supplicant` still "owns" `wlan0`
  and is fighting hostapd for the interface. Confirm the `nohook
  wpa_supplicant` line made it into `/etc/dhcpcd.conf` (see
  `config/dhcpcd.conf`) and reboot.
- Check the country code in `config/hostapd.conf` (`country_code=US` by
  default) — a wrong regulatory domain can silently prevent the radio from
  broadcasting on some channels.

## Clients can join WiFi but get no IP address

- `dnsmasq` isn't running or isn't bound to `wlan0`:
  `sudo systemctl status dnsmasq`, `sudo journalctl -u dnsmasq -n 50`.
- Confirm `wlan0` actually has `192.168.4.1` — `ip -4 addr show wlan0`. If
  it doesn't, the dhcpcd static-IP block (`config/dhcpcd.conf`) isn't
  applied; dnsmasq needs that interface to already have an address before it
  will serve DHCP on it.
- Check for a leftover `dnsmasq` install fighting with `systemd-resolved` on
  port 53 — `sudo ss -tulpn | grep :53` should show only one process bound.

## No captive-portal popup on my phone/laptop

- This is often fine — browse directly to `http://192.168.4.1/`. Different
  OS versions are inconsistent about triggering the popup.
- Confirm DNS hijacking is working: `dig @192.168.4.1 example.com` from a
  connected client should return `192.168.4.1` for *any* domain (see
  `address=/#/192.168.4.1` in `config/dnsmasq.conf`).
- Confirm Nginx is answering the OS-specific check URLs, e.g.:
  `curl -I http://192.168.4.1/generate_204` should return `302`.
- Confirm the iptables redirect is active:
  `sudo iptables -t nat -L PREROUTING -n -v` should show DNAT rules for ports
  80/443/53 on `wlan0`. If it's empty, re-run
  `sudo bash config/iptables-captive.sh`.

## Dashboard loads but won't connect to MQTT

- Open the browser console — a WebSocket connection error to
  `ws://<host>:9001/mqtt` usually means Nginx's `/mqtt` proxy or Mosquitto's
  `9001` listener isn't up.
- `sudo systemctl status mosquitto` and check
  `sudo journalctl -u mosquitto -n 50` for a bind failure on 9001.
- Confirm Mosquitto has two listeners active:
  `sudo ss -tulpn | grep -E '1883|9001'`.
- If you access the dashboard by an IP other than `192.168.4.1` (e.g. via
  hostname), remember `app.js` connects to `window.location.hostname` — that
  has to be reachable, and reachable specifically on port `9001` via the
  Nginx proxy at `/mqtt`, not directly.

## WLED devices never show up in the dashboard

See the discovery-troubleshooting section in
[`WLED_SETUP.md`](WLED_SETUP.md#3-confirm-discovery) — short version: verify
the device joined the WiFi network, confirm its MQTT broker/port settings,
and watch raw traffic with `mosquitto_sub -h 192.168.4.1 -t 'wled/#' -v`.

## Everything worked, then stopped after a reboot

The iptables captive-portal rules (`config/iptables-captive.sh`) are **not**
persistent by default — they're applied by `scripts/start-ap.sh`, not saved
to disk. Options:

- Add `scripts/start-ap.sh` to a `cron @reboot` entry or a systemd oneshot
  unit, or
- `sudo apt-get install iptables-persistent` and run
  `sudo netfilter-persistent save` after applying the rules once.

## SD card / performance concerns on a Pi Zero W

The Pi Zero W's single core and limited RAM mean:

- Keep `mosquitto.conf`'s `log_type` lines minimal in production (drop
  `notice`/`connection_messages` if you don't need them) to reduce SD-card
  wear.
- `dnsmasq.conf` has `log-queries` and `log-dhcp` on for visibility during
  setup — consider disabling both once things are stable.
- If the AP feels sluggish with more than a handful of clients, that's
  expected; the Zero W's WiFi chip is not built for high client counts.
