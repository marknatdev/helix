from __future__ import annotations

import json
import threading
import time
from typing import Callable, Optional
import requests
import serial
import serial.tools.list_ports

class SerialBridge:
    """
    Listens to a serial port for LoRa gateway messages prefixed with '[BRIDGE_JSON]:'
    and forwards them to the local Express webhook server.
    """
    def __init__(
        self,
        port: str,
        baudrate: int,
        webhook_url: str,
        auth_token: str,
        log_fn: Callable[[str], None]
    ) -> None:
        self.port = port
        self.baudrate = baudrate
        self.webhook_url = webhook_url
        self.auth_token = auth_token
        self.log = log_fn
        self._thread: Optional[threading.Thread] = None
        self._stop = threading.Event()
        self.is_connected = False

    def start(self) -> None:
        if self.is_running():
            return
        self._stop.clear()
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=2)
        self.is_connected = False

    def is_running(self) -> bool:
        return self._thread is not None and self._thread.is_alive()

    def _run(self) -> None:
        self.log(f"Bridge: Connecting to {self.port} at {self.baudrate} baud...")
        try:
            ser = serial.Serial(self.port, self.baudrate, timeout=1)
            self.is_connected = True
            self.log(f"Bridge: Connected to {self.port}!")
        except Exception as e:
            self.log(f"Bridge connection failed: {e}")
            self.is_connected = False
            return

        while not self._stop.is_set():
            try:
                if ser.in_waiting > 0:
                    line = ser.readline().decode('utf-8', errors='ignore').strip()
                    if not line:
                        continue
                    if line.startswith("[BRIDGE_JSON]:"):
                        json_str = line[len("[BRIDGE_JSON]:"):].strip()
                        self.log(f"Bridge RX Serial: {json_str}")
                        self._forward_payload(json_str)
                    elif line:
                        # Forward other debug messages from receiver to the log
                        self.log(f"ESP Receiver: {line}")
            except Exception as e:
                self.log(f"Bridge error: {e}")
                break
            time.sleep(0.01)

        try:
            ser.close()
        except Exception:
            pass
        self.is_connected = False
        self.log("Bridge: Disconnected.")

    def _forward_payload(self, json_str: str) -> None:
        try:
            payload = json.loads(json_str)
        except Exception as e:
            self.log(f"Bridge JSON parse error: {e}")
            return

        # Prepare headers
        headers = {
            "Content-Type": "application/json",
            "X-Webhook-Token": self.auth_token
        }

        # The endpoint expects /lora-uplink flat JSON structure
        # (lat, lng, alt, speed, heading, battery, satellites, rssi, snr, helmetId)
        # Note: receiver.ino outputs:
        # doc["helmetId"], doc["lat"], doc["lng"], doc["alt"], doc["speed"], doc["heading"], doc["battery"], doc["satellites"], doc["rssi"], doc["snr"], doc["seqNum"]
        url = self.webhook_url
        if "/chirpstack-webhook" in url:
            # Auto-replace/route to the lora-uplink endpoint since we're forwarding flat JSON from ESP receiver
            url = url.replace("/chirpstack-webhook", "/lora-uplink")

        try:
            self.log(f"Bridge forwarding to {url}...")
            r = requests.post(url, json=payload, headers=headers, timeout=5)
            self.log(f"Bridge POST response: {r.status_code} {r.reason}")
        except Exception as e:
            self.log(f"Bridge POST failed: {e}")

def get_serial_ports() -> list[str]:
    ports = serial.tools.list_ports.comports()
    return sorted([p.device for p in ports])
