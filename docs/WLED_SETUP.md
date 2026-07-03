# WLED Setup

This project's WLED control page talks to your WLED devices entirely over
MQTT — no direct HTTP calls from the browser to each device. Here's how to
point a WLED device at the hub.

## 1. Get the device onto the `MQTT Hub` WiFi network

On first boot, WLED starts its own setup AP (`WLED-AP`). Connect to it and
configure it to join the `MQTT Hub` network:

- **WiFi Settings → SSID:** `MQTT Hub`
- **Password:** whatever you set in `config/hostapd.conf`

Since the Pi's DHCP range is `192.168.4.2`–`192.168.4.20`, you have room for
up to ~18 devices before you'd need to widen the range in
`config/dnsmasq.conf`.

## 2. Enable MQTT on the device

In the WLED web UI (once it has an IP from the hub): **Config → Sync
Interfaces → MQTT**

| Field | Value |
|---|---|
| Enable MQTT | ✅ on |
| Broker | `192.168.4.1` |
| Port | `1883` |
| Client ID | something unique, e.g. `livingroom` |
| Device Topic | `wled/livingroom` |
| Group Topic | `wled/all` (optional) |
| Username / Password | leave blank (broker allows anonymous access) |

The **device topic** is what shows up in the dashboard's device dropdown —
the control page listens on `wled/+/status` and `wled/+/v`, extracts the
segment between the slashes, and adds it as a selectable target.

## 3. Confirm discovery

Open the **WLED** tab on the dashboard (`http://192.168.4.1/wled.html`).
Within a few seconds of the device connecting to the broker, its topic
segment should appear as a chip under **Devices** and in the **Target**
dropdown.

If nothing appears:

- Check the device actually joined `MQTT Hub` WiFi (WLED's UI shows its IP
  under Wifi Settings once connected).
- Run `mosquitto_sub -h 192.168.4.1 -t 'wled/#' -v` from the Pi (or any MQTT
  client on the network) to see raw traffic — you should see `wled/<id>/status`
  publish on connect.
- Double check the broker address is `192.168.4.1` and port `1883`, not
  `9001` (that port is WebSocket-only, for browsers).

## 4. Controlling devices

- **Power**: the toggle publishes `{"on": true}` / `{"on": false}` to
  `wled/{device}/api`.
- **Brightness**: the slider publishes `{"bri": <0-255>}` on release.
- **Color**: the color picker publishes `{"seg": [{"col": [[r, g, b]]}]}`
  when you click **Apply Color**.
- **Preset**: publishes `{"ps": <slot>}` when you click **Apply Preset**. Set
  up preset slots 1–8 ahead of time in WLED's own Presets UI — this page
  just triggers them, it doesn't create them.
- Selecting **ALL** in the Target dropdown publishes to every discovered
  device's `wled/{device}/api` topic individually (or to `wled/all/api` if
  no group topic convention is set up and nothing has been discovered yet).

## Reference: WLED's MQTT API topics

WLED listens on `wled/{topic}/api` for raw JSON API commands, and publishes
state to `wled/{topic}/status` (full state JSON) and `wled/{topic}/v`
(power+brightness `on|X` shorthand some versions also publish). This project
follows WLED's own documented MQTT conventions — nothing custom on the
device side. If your WLED firmware uses a different convention, check its
version's docs and adjust the topic segment as needed.
