"""
simulator.py
────────────────────────────────────────────────────────────────────────────
Headless simulation engine for a single ESP32 helmet node.

Builds a ChirpStack-format JSON uplink and POSTs it to the local webhook
server (the same endpoint your real ChirpStack instance would call). All
LoRaWAN encoding is bypassed — we send the already-decoded `object` field.
────────────────────────────────────────────────────────────────────────────
"""
from __future__ import annotations

import math
import random
import threading
from dataclasses import dataclass
from typing import Callable, Optional

import requests

# Major Thai cities — preset GPS centers
THAI_PRESETS: dict[str, tuple[float, float]] = {
    "Bangkok":     (13.7563, 100.5018),
    "Chiang Mai":  (18.7883,  98.9853),
    "Phuket":      ( 7.8804,  98.3923),
    "Khon Kaen":   (16.4419, 102.8350),
    "Pattaya":     (12.9236, 100.8825),
    "Hat Yai":     ( 7.0167, 100.4747),
    "Ayutthaya":   (14.3692, 100.5876),
    "Udon Thani":  (17.4138, 102.7872),
    "Nakhon Si":   ( 8.4304,  99.9633),
    "Krabi":       ( 8.0863,  98.9063),
}

GPS_MODES = ("stationary", "random_walk", "route")


@dataclass
class SimConfig:
    # Connection
    webhook_url: str = "http://localhost:3000/chirpstack-webhook"
    auth_token: str = "smarthelmet"

    # Device identity
    helmet_id: str = "HLX-001"
    dev_eui: str = "0000000000000001"
    join_eui: str = "0000000000000000"
    app_key: str = "00000000000000000000000000000000"

    # GPS
    lat: float = 13.7563
    lng: float = 100.5018
    altitude: float = 12.0
    heading: float = 90.0       # degrees
    speed_mps: float = 3.0
    satellites: int = 9
    gps_mode: str = "random_walk"
    route_target_lat: float = 13.7700
    route_target_lng: float = 100.5200

    # Sensors
    battery: float = 85.0
    auto_drain: bool = False
    drain_rate: float = 0.1     # % per tick
    # LoRa signal
    rssi: float = -78.0          # dBm
    snr: float = 8.5             # dB
    rssi_jitter: bool = True

    # TX
    tx_interval_s: float = 10.0


class HelmetSimulator:
    """Threaded transmit loop. Each tick advances the simulated state and
    posts a ChirpStack-format JSON uplink to the configured webhook URL."""

    def __init__(self, config: SimConfig, log_fn: Callable[[str], None]):
        self.cfg = config
        self.log = log_fn
        self._thread: Optional[threading.Thread] = None
        self._stop = threading.Event()
        self.tx_count = 0
        self.last_status: str = "—"

    # ─── lifecycle ──────────────────────────────────────────────────────

    def start(self) -> None:
        if self.is_running():
            return
        self._stop.clear()
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()
        self.log("Simulator started")

    def stop(self) -> None:
        if not self.is_running():
            return
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=2)
        self.log("Simulator stopped")

    def is_running(self) -> bool:
        return self._thread is not None and self._thread.is_alive()

    def send_now(self) -> None:
        threading.Thread(target=self._tick, daemon=True).start()

    # ─── tick loop ──────────────────────────────────────────────────────

    def _run(self) -> None:
        while not self._stop.is_set():
            self._tick()
            self._stop.wait(max(1.0, float(self.cfg.tx_interval_s)))

    def _tick(self) -> None:
        try:
            self._step_gps(self.cfg.tx_interval_s)
            if self.cfg.rssi_jitter:
                self.cfg.rssi = max(-120, min(-30, self.cfg.rssi + random.uniform(-2, 2)))
                self.cfg.snr  = max(-10,  min(15,  self.cfg.snr  + random.uniform(-0.5, 0.5)))
            if self.cfg.auto_drain:
                self.cfg.battery = max(0.0, self.cfg.battery - self.cfg.drain_rate)
            self._send_uplink()
        except Exception as e:
            self.log(f"Tick error: {e}")

    # ─── GPS movement ───────────────────────────────────────────────────

    def _step_gps(self, dt: float) -> None:
        if self.cfg.gps_mode == "stationary":
            # Tiny GPS noise so it feels alive
            self.cfg.lat += random.uniform(-2e-5, 2e-5)
            self.cfg.lng += random.uniform(-2e-5, 2e-5)
            return

        if self.cfg.gps_mode == "route":
            tlat, tlng = self.cfg.route_target_lat, self.cfg.route_target_lng
            self.cfg.heading = self._bearing(self.cfg.lat, self.cfg.lng, tlat, tlng)
            d = self._dist_m(self.cfg.lat, self.cfg.lng, tlat, tlng)
            if d < max(20.0, self.cfg.speed_mps * dt * 1.2):
                # Bounce: swap target with current → walk back
                self.cfg.route_target_lat, self.cfg.lat = self.cfg.lat, tlat
                self.cfg.route_target_lng, self.cfg.lng = self.cfg.lng, tlng
                return

        elif self.cfg.gps_mode == "random_walk":
            self.cfg.heading = (self.cfg.heading + random.uniform(-15, 15)) % 360

        # Step forward `speed * dt` meters along current heading
        dist_m = self.cfg.speed_mps * dt
        rad = math.radians(self.cfg.heading)
        # Approx flat-earth conversion (good enough for short distances)
        dlat = (dist_m * math.cos(rad)) / 111_111.0
        cos_lat = max(0.01, math.cos(math.radians(self.cfg.lat)))
        dlng = (dist_m * math.sin(rad)) / (111_111.0 * cos_lat)
        self.cfg.lat += dlat
        self.cfg.lng += dlng

    @staticmethod
    def _dist_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
        R = 6_371_000.0
        p1, p2 = math.radians(lat1), math.radians(lat2)
        dp = math.radians(lat2 - lat1)
        dl = math.radians(lng2 - lng1)
        a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
        return 2 * R * math.asin(math.sqrt(a))

    @staticmethod
    def _bearing(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
        p1, p2 = math.radians(lat1), math.radians(lat2)
        dl = math.radians(lng2 - lng1)
        x = math.sin(dl) * math.cos(p2)
        y = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl)
        return (math.degrees(math.atan2(x, y)) + 360) % 360

    # ─── payload + transport ────────────────────────────────────────────

    def _build_payload(self) -> dict:
        """Build a ChirpStack v4 'up' event JSON. The webhook server reads
        `body.data || body`, so we send without the wrapper to match real
        ChirpStack v4 behaviour."""
        return {
            "deviceInfo": {
                "deviceName": self.cfg.helmet_id,
                "devEui": self.cfg.dev_eui,
            },
            "object": {
                "gps_1": {
                    "latitude":  round(self.cfg.lat, 6),
                    "longitude": round(self.cfg.lng, 6),
                    "altitude":  round(self.cfg.altitude, 1),
                },
                "analogOutput_2": round(self.cfg.speed_mps, 2),
                "analogOutput_3": round(self.cfg.heading, 1),
                "analogOutput_4": round(self.cfg.battery, 1),
                "digitalInput_5": int(self.cfg.satellites),
            },
            "rxInfo": [
                {
                    "rssi": int(round(self.cfg.rssi)),
                    "snr":  round(self.cfg.snr, 2),
                }
            ],
        }

    def _send_uplink(self) -> None:
        payload = self._build_payload()
        headers = {"X-Webhook-Token": self.cfg.auth_token}
        try:
            r = requests.post(
                self.cfg.webhook_url,
                json=payload,
                headers=headers,
                timeout=5,
            )
            self.tx_count += 1
            self.last_status = f"{r.status_code} {r.reason}"
            self.log(
                f"TX #{self.tx_count}  →  {self.last_status}   "
                f"lat={self.cfg.lat:.5f}  lng={self.cfg.lng:.5f}  "
                f"bat={self.cfg.battery:.0f}%  rssi={int(self.cfg.rssi)}"
            )
        except requests.RequestException as e:
            self.last_status = "ERR"
            self.log(f"TX failed: {e}")
