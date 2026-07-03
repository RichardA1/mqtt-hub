/* MQTT Hub Dashboard — app.js
 * Uses Paho MQTT JS client over WebSocket (port 9001, path /mqtt via Nginx proxy).
 * Auto-detects the broker host from window.location.hostname so this works
 * whether you're at 192.168.4.1 or a hostname the captive portal resolved.
 */

(function () {
  "use strict";

  const MAX_FEED_ENTRIES = 200;
  const CLIENT_ID = "hub-dash-" + Math.random().toString(16).slice(2, 10);

  const state = {
    client: null,
    connected: false,
    subscriptions: new Map(), // topic -> qos
  };

  const el = {
    statusDot: document.getElementById("status-dot"),
    statusText: document.getElementById("status-text"),
    connectBtn: document.getElementById("btn-connect"),
    disconnectBtn: document.getElementById("btn-disconnect"),
    brokerHost: document.getElementById("broker-host"),

    subTopic: document.getElementById("sub-topic"),
    subQos: document.getElementById("sub-qos"),
    subBtn: document.getElementById("btn-subscribe"),
    subList: document.getElementById("sub-list"),

    pubTopic: document.getElementById("pub-topic"),
    pubPayload: document.getElementById("pub-payload"),
    pubQos: document.getElementById("pub-qos"),
    pubRetain: document.getElementById("pub-retain"),
    pubBtn: document.getElementById("btn-publish"),

    feed: document.getElementById("feed"),
    clearFeedBtn: document.getElementById("btn-clear-feed"),
  };

  function setStatus(connected) {
    state.connected = connected;
    el.statusDot.classList.toggle("online", connected);
    el.statusDot.classList.toggle("offline", !connected);
    el.statusText.textContent = connected ? "connected" : "disconnected";
    el.connectBtn.disabled = connected;
    el.disconnectBtn.disabled = !connected;
    el.subBtn.disabled = !connected;
    el.pubBtn.disabled = !connected;
  }

  function nowStamp() {
    const d = new Date();
    return d.toTimeString().split(" ")[0];
  }

  function addFeedEntry({ topic, payload, kind }) {
    const entry = document.createElement("div");
    entry.className = "feed-entry" + (kind ? " " + kind : "");

    const ts = document.createElement("span");
    ts.className = "ts";
    ts.textContent = "[" + nowStamp() + "]";
    entry.appendChild(ts);

    if (topic) {
      const t = document.createElement("span");
      t.className = "topic";
      t.textContent = topic;
      entry.appendChild(t);
    }

    const p = document.createElement("span");
    p.className = "payload";
    p.textContent = payload;
    entry.appendChild(p);

    el.feed.insertBefore(entry, el.feed.firstChild);

    while (el.feed.children.length > MAX_FEED_ENTRIES) {
      el.feed.removeChild(el.feed.lastChild);
    }
  }

  function logSystem(msg) {
    addFeedEntry({ payload: msg, kind: "system" });
  }

  function logError(msg) {
    addFeedEntry({ payload: msg, kind: "error" });
  }

  function connect() {
    const host = window.location.hostname || "192.168.4.1";
    el.brokerHost.textContent = host + ":9001/mqtt";

    const client = new Paho.MQTT.Client(host, Number(9001), "/mqtt", CLIENT_ID);

    client.onConnectionLost = function (resp) {
      setStatus(false);
      if (resp.errorCode !== 0) {
        logError("connection lost: " + resp.errorMessage);
      }
    };

    client.onMessageArrived = function (message) {
      addFeedEntry({
        topic: message.destinationName,
        payload: message.payloadString,
      });
    };

    client.connect({
      useSSL: window.location.protocol === "https:",
      timeout: 8,
      onSuccess: function () {
        setStatus(true);
        logSystem("connected to " + host);
        // Re-subscribe to anything the user had before a reconnect
        state.subscriptions.forEach((qos, topic) => {
          client.subscribe(topic, { qos });
        });
      },
      onFailure: function (err) {
        setStatus(false);
        logError("connect failed: " + err.errorMessage);
      },
    });

    state.client = client;
  }

  function disconnect() {
    if (state.client && state.connected) {
      state.client.disconnect();
      setStatus(false);
      logSystem("disconnected");
    }
  }

  function renderSubList() {
    el.subList.innerHTML = "";
    state.subscriptions.forEach((qos, topic) => {
      const li = document.createElement("li");

      const label = document.createElement("span");
      const badge = document.createElement("span");
      badge.className = "qos-badge";
      badge.textContent = "QoS " + qos;
      label.appendChild(badge);
      label.appendChild(document.createTextNode(topic));

      const unsubBtn = document.createElement("button");
      unsubBtn.className = "small danger";
      unsubBtn.textContent = "unsubscribe";
      unsubBtn.onclick = function () {
        if (state.client && state.connected) {
          state.client.unsubscribe(topic);
        }
        state.subscriptions.delete(topic);
        renderSubList();
        logSystem("unsubscribed from " + topic);
      };

      li.appendChild(label);
      li.appendChild(unsubBtn);
      el.subList.appendChild(li);
    });
  }

  function subscribe() {
    const topic = el.subTopic.value.trim();
    if (!topic) return;
    const qos = Number(el.subQos.value);

    state.client.subscribe(topic, {
      qos,
      onSuccess: function () {
        state.subscriptions.set(topic, qos);
        renderSubList();
        logSystem("subscribed to " + topic + " (QoS " + qos + ")");
      },
      onFailure: function (err) {
        logError("subscribe failed: " + err.errorMessage);
      },
    });

    el.subTopic.value = "";
  }

  function publish() {
    const topic = el.pubTopic.value.trim();
    if (!topic) return;
    const payload = el.pubPayload.value;
    const qos = Number(el.pubQos.value);
    const retain = el.pubRetain.checked;

    const message = new Paho.MQTT.Message(payload);
    message.destinationName = topic;
    message.qos = qos;
    message.retained = retain;

    state.client.send(message);
    logSystem(
      "published to " + topic + " (QoS " + qos + (retain ? ", retained" : "") + ")"
    );
  }

  el.connectBtn.addEventListener("click", connect);
  el.disconnectBtn.addEventListener("click", disconnect);
  el.subBtn.addEventListener("click", subscribe);
  el.pubBtn.addEventListener("click", publish);
  el.clearFeedBtn.addEventListener("click", function () {
    el.feed.innerHTML = "";
  });

  setStatus(false);
  logSystem("ready — click Connect to reach the broker");
})();
