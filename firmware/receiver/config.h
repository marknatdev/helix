#pragma once
#include <stdint.h>

// ─── WiFi ────────────────────────────────────────────────────────────────────
#define WIFI_SSID     "True-2_2.4G"
#define WIFI_PASS     "0819563643"

// ─── Webhook Server ──────────────────────────────────────────────────────────
// URL of the local Express server running functions/index.js
#define WEBHOOK_URL   "http://192.168.1.100:3000/lora-uplink"
#define WEBHOOK_TOKEN "smarthelmet"    // must match WEBHOOK_SECRET in functions/.env

// ─── LoRa Radio (SX1276, Heltec WiFi LoRa 32 V2) ───────────────────────────
// MUST match sender settings exactly!
#define LORA_FREQ       923.0f        // MHz
#define LORA_BW         125.0f        // kHz bandwidth
#define LORA_SF         7             // Spreading factor
#define LORA_CR         5             // Coding rate (5 = 4/5)
#define LORA_SYNC_WORD  0x12          // Must match sender
#define LORA_PREAMBLE   8

// ─── SX1276 Pins (Heltec V2) ────────────────────────────────────────────────
#define LORA_NSS   18
#define LORA_DIO0  26
#define LORA_RST   14
#define LORA_DIO1  35

// ─── SPI Pins (Heltec V2 non-default) ───────────────────────────────────────
#define LORA_SCK   5
#define LORA_MISO  19
#define LORA_MOSI  27

// ─── OLED Display (SSD1306 128x64) ──────────────────────────────────────────
#define OLED_SDA   4
#define OLED_SCL   15
#define OLED_RST   16
#define OLED_ADDR  0x3C

// ─── Vext Power ──────────────────────────────────────────────────────────────
#define VEXT_PIN   21
