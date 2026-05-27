# HELIX ESP32 Simulator

A standalone Python desktop app that simulates a Heltec LoRa 32 v2 helmet
node and posts ChirpStack-format uplinks directly to your local webhook
server. Test the full pipeline (webhook → Firestore → Flutter app) without
any LoRa hardware.

```
[Simulator UI]  ──HTTP POST──▶  [Local webhook server]  ──▶  [Firestore]  ──▶  [Flutter app]
```

## Features

- Clean dark UI built with **customtkinter**
- 10 Thai city presets (Bangkok, Chiang Mai, Phuket, …)
- 3 GPS movement modes:
  - **Stationary** — fixed point with tiny GPS noise
  - **Random walk** — heading drifts ±15° per tick
  - **Route** — bounces between two waypoints
- Configurable **battery** with optional auto-drain
- Configurable **RSSI / SNR** with optional auto-jitter
- Adjustable **TX interval** (1 – 60 s)
- Manual **Send Now** button for one-shot tests
- Live **activity log** with HTTP response status
- **TR005 QR code generator** — scan in ChirpStack to import the device

## Setup

```powershell
cd d:\helix\simulator
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

## Run

Make sure your local webhook server is running first:

```powershell
cd d:\helix\functions
node index.js
```

Then in another terminal:

```powershell
cd d:\helix\simulator
.\.venv\Scripts\Activate.ps1
python main.py
```

## Usage

1. **Connection** — paste the same `X-Webhook-Token` value you set in
   `functions/.env`. The default URL targets `http://localhost:3000`.
2. **Device** — set a unique `Helmet ID` (e.g., `HLX-001`) and `DevEUI`.
   Each helmet ID becomes one document in Firestore at `helmets/<id>`.
3. **GPS** — pick a Thai city preset, choose a movement mode, and set
   speed / heading.
4. **Sensors / Signal** — set battery, heart rate, RSSI, SNR.
5. Click **▶ Start** to begin transmitting on the configured interval, or
   **⚡ Send Now** for a single immediate uplink.

## ChirpStack QR Code

Click **📱 Generate ChirpStack QR Code** in the Device section to open a
popup with a QR code in the **LoRa Alliance TR005** schema. Scan it in:

> ChirpStack web UI → Devices → **Add device** → **Scan QR code**

This auto-fills DevEUI and JoinEUI. The AppKey is shown in the popup —
copy/paste it into ChirpStack manually after scanning (it's not embedded
in the QR for security).

You can also save the QR as a PNG to print or share.

## Multiple helmets

Run multiple instances (each in its own terminal) with different
`Helmet ID` values. Each will appear as a separate helmet card in the
Flutter app.

## Serial Bridge (ESP Receiver)

If you are using a physical Heltec LoRa 32 V2 receiver connected to your PC over USB, you can use the **Serial Bridge** feature to read the incoming LoRa packets from the receiver and forward them directly to the local Express webhook server:

1. Flash the updated `firmware/receiver/receiver.ino` to the receiver board.
2. Connect the receiver board to your PC via a USB cable.
3. Open the Simulator App.
4. Under the **Serial Bridge · ESP Receiver** section:
   - Click **🔄 Refresh** to scan for connected COM/serial ports.
   - Choose the correct port for the receiver (e.g., `COM3` on Windows).
   - Select `115200` baud rate.
   - Click **▶ Start Bridge**.
5. Telemetry received by the physical board over LoRa will be printed to Serial as JSON, read by the bridge, and forwarded to the local webhook.

## Files

| File | Purpose |
|---|---|
| `main.py` | Entry point |
| `app.py` | customtkinter UI |
| `simulator.py` | Headless TX engine (GPS + payload + HTTP) |
| `serial_bridge.py` | Serial bridge engine to link ESP receiver |
| `qr_generator.py` | TR005 QR string + PIL image renderer |
| `requirements.txt` | Python dependencies |
