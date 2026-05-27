#pragma once
#include <stdint.h>

// ─── Device Identity ─────────────────────────────────────────────────────────
#define HELMET_ID    "HLX-001"        // 8-char max, sent in every packet

// ─── LoRa Radio (SX1276, Heltec WiFi LoRa 32 V2) ───────────────────────────
#define LORA_FREQ       923.0f        // MHz — AS923 band (match receiver!)
#define LORA_BW         125.0f        // kHz bandwidth
#define LORA_SF         7             // Spreading factor (7-12)
#define LORA_CR         5             // Coding rate (5 = 4/5)
#define LORA_SYNC_WORD  0x12          // Private network sync word
#define LORA_TX_POWER   17            // dBm (max 20 for SX1276)
#define LORA_PREAMBLE   8             // Preamble length

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

// ─── Vext Power (controls OLED power on Heltec V2) ──────────────────────────
#define VEXT_PIN   21   // LOW = on, HIGH = off

// ─── GPS (NEO-M8U) — future use ─────────────────────────────────────────────
#define GPS_RX_PIN   13   // ESP32 GPIO ← GPS TX
#define GPS_TX_PIN   12   // ESP32 GPIO → GPS RX
#define GPS_BAUD     9600
#define USE_REAL_GPS false  // Set true when GPS hardware is connected

// ─── Fake GPS defaults (Bangkok) ─────────────────────────────────────────────
#define FAKE_LAT     13.7563f
#define FAKE_LNG     100.5018f
#define FAKE_ALT     12.0f
#define FAKE_SPEED   1.5f     // m/s walking pace
#define FAKE_SATS    9

// ─── Battery ADC ─────────────────────────────────────────────────────────────
#define VBAT_PIN             37
#define VBAT_DIVIDER_RATIO   2.0f
#define VBAT_MIN             3.2f   // Volts = 0 %
#define VBAT_MAX             4.2f   // Volts = 100 %

// ─── TX Timing ───────────────────────────────────────────────────────────────
#define TX_INTERVAL_S   10    // seconds between transmissions
