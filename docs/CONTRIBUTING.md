# Contributing

Thanks for considering a contribution to mqtt-hub! This is a small, focused
project — a Pi Zero W access point, MQTT broker, and a couple of web pages —
so the bar for contributions is mostly "does it work and does CI pass."

## Getting set up

You don't need a Raspberry Pi to work on most of this repo:

- **Web pages** (`web/`): open `web/index.html` / `web/wled.html` directly
  in a browser, or serve the `web/` directory with any static file server.
  You'll need a running Mosquitto broker with a WebSocket listener on 9001
  to actually test MQTT connectivity — `mosquitto` is available via most
  package managers (`apt`, `brew`, etc.) and Docker images exist too.
- **Config files** (`config/`): these can be validated without a Pi —
  `nginx -t` against `config/nginx-mqtt-hub`, or start Mosquitto with
  `-c config/mosquitto.conf`.
- **Shell scripts** (`scripts/`, `setup.sh`, `config/iptables-captive.sh`):
  lint locally with [ShellCheck](https://www.shellcheck.net/) before
  pushing — CI will run the same checks.

A real Pi Zero W (or any Linux box with `hostapd`/`dnsmasq` support) is only
needed to test the actual access-point behavior end-to-end.

## Making changes

1. Fork the repo and create a branch off `main`.
2. Make your change. Keep it scoped — small, focused PRs are much easier to
   review than sweeping ones.
3. Run the relevant checks locally where you can (see above).
4. Open a PR. CI runs automatically; all jobs need to pass before merge.

## Style

- **Shell**: `set -euo pipefail` at the top of every script, quote your
  variables, and keep ShellCheck happy (no `# shellcheck disable` without a
  comment explaining why).
- **HTML/CSS/JS**: no build step by design — plain HTML, vanilla JS, and
  hand-written CSS using the existing `:root` custom properties in
  `web/css/style.css`. Keep the terminal aesthetic consistent (green-on-black,
  monospace).
- **Config files**: comment non-obvious settings, especially anything
  security-relevant (e.g. why anonymous MQTT access is acceptable here).

## Reporting issues

Open a GitHub issue with:

- What you expected vs. what happened
- Output of `scripts/status.sh` if it's a service/networking issue
- Pi model, OS version, and WLED firmware version if relevant

See also [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) — your issue might
already have a documented fix.
