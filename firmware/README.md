# HELIX Firmware — LoRa Point-to-Point

Two firmwares for Heltec WiFi LoRa 32 V2 (ESP32 + SX1276):

| Board | Role | Folder |
|---|---|---|
| **Sender** | Helmet node — reads GPS/battery, transmits via LoRa | `firmware/sender/` |
| **Receiver** | Gateway — receives LoRa, POSTs to webhook server via WiFi | `firmware/receiver/` |

## Architecture

```
[Helmet Board]                [Receiver Board]             [PC / Server]
sender.ino                    receiver.ino
 ├─ GPS (NEO-M8U, future)     ├─ WiFi → LAN
 ├─ Battery ADC                ├─ LoRa RX → parse struct
 ├─ OLED status                ├─ HTTP POST (JSON)
 └─ SX1276 TX ──── 923MHz ──→ └─ OLED status
                                       │
                                       ▼
                                functions/index.js
                                POST /lora-uplink
                                       │
                                       ▼
                                 Firestore → Flutter app
```

## Hardware

| Component | Model | Notes |
|---|---|---|
| MCU + LoRa | Heltec WiFi LoRa 32 V2 (×2) | ESP32 + SX1276 + 0.96" OLED |
| GPS | u-blox NEO-M8U (future) | UART, 9600 baud |
| Battery | 3.7 V LiPo (1S) | JST connector on Heltec board |

## Heltec V2 Pinout

| Function | GPIO |
|---|---|
| LoRa NSS | 18 |
| LoRa DIO0 (IRQ) | 26 |
| LoRa RST | 14 |
| LoRa DIO1 | 35 |
| SPI SCK | 5 |
| SPI MISO | 19 |
| SPI MOSI | 27 |
| OLED SDA | 4 |
| OLED SCL | 15 |
| OLED RST | 16 |
| Vext (OLED power) | 21 |
| VBAT ADC | 37 |
| GPS RX (future) | 13 |
| GPS TX (future) | 12 |

## GPS Wiring (when ready)

```
Heltec GPIO 13 (RX) ←── GPS TX
Heltec GPIO 12 (TX) ──→ GPS RX
Heltec 3.3V         ──→ GPS VCC
Heltec GND          ──→ GPS GND
```

Then set `USE_REAL_GPS` to `true` in `sender/config.h`.

## Arduino IDE Setup (both boards)

1. **Board package**: ESP32 by Espressif
   - URL: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
2. **Board**: `ESP32 Dev Module`
3. **Libraries** (install via Library Manager):
   - `RadioLib` by Jan Gromes
   - `ESP8266 and ESP32 OLED driver for SSD1306 displays` by ThingPulse
   - `TinyGPSPlus` by Mikal Hart *(sender only, when GPS connected)*
   - `ArduinoJson` by Benoit Blanchon *(receiver only)*

## Configuration

### Sender (`sender/config.h`)
- `HELMET_ID` — device name (shows in Flutter app)
- `LORA_FREQ` — must match receiver (default 923.0 MHz)
- `USE_REAL_GPS` — set `true` when NEO-M8U is wired
- `TX_INTERVAL_S` — seconds between transmissions

### Receiver (`receiver/config.h`)
- `WIFI_SSID` / `WIFI_PASS` — your WiFi network
- `WEBHOOK_URL` — your server IP (e.g. `http://192.168.1.100:3000/lora-uplink`)
- `WEBHOOK_TOKEN` — must match `CHIRPSTACK_WEBHOOK_SECRET` in `functions/.env`
- `LORA_FREQ` — must match sender

## LoRa Settings (must match on both boards)

| Parameter | Default |
|---|---|
| Frequency | 923.0 MHz (AS923) |
| Bandwidth | 125 kHz |
| Spreading Factor | 7 |
| Coding Rate | 4/5 |
| Sync Word | 0x12 |
| Preamble | 8 |

## Packet Format (32 bytes)

| Offset | Size | Type | Field |
|---|---|---|---|
| 0 | 8 | char[] | helmetId |
| 8 | 4 | float | latitude |
| 12 | 4 | float | longitude |
| 16 | 4 | float | altitude (m) |
| 20 | 4 | float | speed (m/s) |
| 24 | 4 | float | heading (deg) |
| 28 | 1 | uint8 | battery (%) |
| 29 | 1 | uint8 | satellites |
| 30 | 2 | uint16 | sequence number |

## Quick Start

1. Flash `sender/sender.ino` to helmet board
2. Flash `receiver/receiver.ino` to gateway board
3. Edit `receiver/config.h` — set WiFi credentials and webhook server IP
4. Start webhook server: `cd functions && node index.js`
5. Power on both boards — sender transmits every 10s, receiver forwards to Firestore
6. Flutter app shows live data via Firestore streams
