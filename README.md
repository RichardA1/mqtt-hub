# mqtt-hub

[![CI](https://github.com/YOUR_USERNAME/mqtt-hub/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/mqtt-hub/actions/workflows/ci.yml)
[![Release](https://github.com/YOUR_USERNAME/mqtt-hub/actions/workflows/release.yml/badge.svg)](https://github.com/YOUR_USERNAME/mqtt-hub/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> Replace `YOUR_USERNAME` above with your GitHub username once this repo is pushed.

A self-contained WiFi Access Point + MQTT Broker + WLED LED Controller +
Captive Portal, designed to run on a Raspberry Pi Zero W with no internet
uplink required. Power it on, join the `MQTT Hub` WiFi network, and your
phone/laptop pops a captive-portal sign-in page straight into an MQTT
dashboard and WLED controller.

## Architecture

```
                     ┌─────────────────────────────────────────┐
                     │        Raspberry Pi Zero W               │
                     │                                           │
   phone/laptop      │  ┌─────────┐   ┌──────────┐  ┌─────────┐ │
  ┌───────────┐ WiFi │  │ hostapd │   │ dnsmasq  │  │ iptables│ │
  │  client   │◄────►│  │  (AP)   │   │ DHCP+DNS │  │ NAT/redir│ │
  └───────────┘      │  └────┬────┘   └────┬─────┘  └────┬────┘ │
        ▲            │       │             │             │      │
        │  HTTP/WS   │       └──────┬──────┴─────────────┘      │
        └────────────┼──────────────▼───────────────────────┐   │
                      │        ┌───────────┐   ┌───────────┐ │   │
                      │        │  Nginx    │◄─►│ Mosquitto │ │   │
                      │        │ :80 (web) │   │ :1883 mqtt│ │   │
                      │        │ /mqtt ws  │   │ :9001 ws  │ │   │
                      │        └───────────┘   └───────────┘ │   │
                      │                              ▲        │   │
                      └──────────────────────────────┼────────┘   │
                                                       │            │
                                              ┌────────┴────────┐   │
                                              │  WLED devices    │  │
                                              │  (ESP8266/32)    │  │
                                              └───────────────────┘ │
                                                                      │
                                                                      ▼
                     192.168.4.0/24  ·  gateway 192.168.4.1  ·  no WAN
```

- **hostapd** broadcasts the `MQTT Hub` WiFi network and hands the Pi the
  static address `192.168.4.1`.
- **dnsmasq** serves DHCP (`192.168.4.2`–`192.168.4.20`) and resolves *every*
  hostname to `192.168.4.1`, which is what triggers each OS's captive-portal
  popup.
- **iptables** transparently redirects port 80/443/53 traffic on `wlan0` to
  the Pi so clients can't accidentally bypass the portal.
- **Nginx** serves the dashboard, answers OS connectivity-check URLs with
  302s, and reverse-proxies MQTT-over-WebSocket at `/mqtt`.
- **Mosquitto** is the MQTT broker: TCP on `1883` for WLED devices, WebSocket
  on `9001` for the browser dashboard (via Nginx).

## Quick start

```bash
git clone https://github.com/YOUR_USERNAME/mqtt-hub.git
cd mqtt-hub
sudo ./setup.sh
```

The installer will prompt you to confirm, then install packages, deploy
configs, and bring the AP up. Afterwards:

1. Join WiFi network **`MQTT Hub`** (see `config/hostapd.conf` for the
   password — change it from the placeholder before deploying!).
2. Your device should pop a "sign in to network" prompt automatically. If it
   doesn't, browse to `http://192.168.4.1/`.
3. Use the **Dashboard** tab to subscribe/publish raw MQTT, or the **WLED**
   tab to control any WLED devices on the network.

To stop or restart the AP without re-running the full installer:

```bash
sudo scripts/stop-ap.sh
sudo scripts/start-ap.sh
sudo scripts/status.sh   # health check
```

## Project layout

```
mqtt-hub/
├── .github/workflows/   # CI + release automation
├── config/              # hostapd, dnsmasq, dhcpcd, mosquitto, nginx, iptables
├── web/                 # dashboard + WLED control pages (HTML/CSS/JS)
├── scripts/             # start/stop/status helpers
├── docs/                # manual setup, WLED setup, troubleshooting, contributing
├── setup.sh             # one-shot automated installer
└── LICENSE              # MIT
```

See [`docs/MANUAL_SETUP.md`](docs/MANUAL_SETUP.md) for a step-by-step manual
install (useful if you want to understand or customize each piece), and
[`docs/WLED_SETUP.md`](docs/WLED_SETUP.md) for configuring your WLED devices
to talk to this broker.

## CI

Every push runs: ShellCheck on all shell scripts, HTML validation on both
pages, `nginx -t` against the shipped config, a Mosquitto config smoke test,
ESLint on `app.js`, stylelint on `style.css`, and a full integration test
that spins up the stack on `ubuntu-latest` and verifies the dashboard,
captive-portal redirects, MQTT pub/sub, and the WebSocket listener all work
end-to-end. See [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

Tagging a release (`git tag v1.0.0 && git push --tags`) builds a `.tar.gz`
and publishes a GitHub Release — see
[`.github/workflows/release.yml`](.github/workflows/release.yml).

## License

MIT — see [LICENSE](LICENSE).
