/**
 * receiver.ino — HELIX LoRa Gateway / Receiver
 * ────────────────────────────────────────────────────────────────────────────
 * Heltec WiFi LoRa 32 V2 · SX1276
 * Listens for LoRa packets from helmet senders, parses the binary struct,
 * connects to WiFi, and POSTs JSON to the local Express webhook server.
 *
 * Libraries (Arduino Library Manager):
 *   - RadioLib               by Jan Gromes
 *   - ESP8266 and ESP32 OLED driver for SSD1306 displays  by ThingPulse
 *   - ArduinoJson            by Benoit Blanchon
 *
 * Board: ESP32 Dev Module
 * ────────────────────────────────────────────────────────────────────────────
 */

#include "config.h"

#include <RadioLib.h>
#include <SPI.h>
#include <Wire.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "SSD1306Wire.h"

// ─── Packet structure (must match sender) ────────────────────────────────────
struct __attribute__((packed)) HelmetPacket {
  char     helmetId[8];
  float    lat;
  float    lng;
  float    altitude;
  float    speed;
  float    heading;
  uint8_t  battery;
  uint8_t  satellites;
  uint16_t seqNum;
};

// ─── Hardware ────────────────────────────────────────────────────────────────
SX1276 radio = new Module(LORA_NSS, LORA_DIO0, LORA_RST, LORA_DIO1);
SSD1306Wire oled(OLED_ADDR, OLED_SDA, OLED_SCL);

// ─── State ───────────────────────────────────────────────────────────────────
static uint32_t rxCount     = 0;
static uint32_t postOkCount = 0;
static uint32_t postErrCount = 0;
static uint32_t lastOledMs  = 0;

// Last received packet info (for OLED)
static char     lastHelmetId[9] = "";
static float    lastRssi        = 0;
static float    lastSnr         = 0;
static uint16_t lastSeq         = 0;

// ─── WiFi ────────────────────────────────────────────────────────────────────
void connectWiFi() {
  Serial.printf("[WIFI] Connecting to %s", WIFI_SSID);
  oled.clear();
  oled.drawString(0, 0, "WiFi connecting...");
  oled.drawString(0, 14, WIFI_SSID);
  oled.display();

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 40) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WIFI] Connected! IP: %s\n", WiFi.localIP().toString().c_str());
    oled.clear();
    oled.drawString(0, 0, "WiFi OK");
    oled.drawString(0, 14, WiFi.localIP().toString());
    oled.display();
  } else {
    Serial.println("\n[WIFI] FAILED — will retry");
    oled.clear();
    oled.drawString(0, 0, "WiFi FAILED");
    oled.drawString(0, 14, "Will retry...");
    oled.display();
  }
}

// ─── POST to webhook server ──────────────────────────────────────────────────
void postToWebhook(const HelmetPacket &pkt, float rssi, float snr) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[POST] WiFi not connected — skipping");
    postErrCount++;
    return;
  }

  // Build JSON
  JsonDocument doc;
  // Null-terminate helmetId safely
  char id[9];
  memcpy(id, pkt.helmetId, 8);
  id[8] = '\0';

  doc["helmetId"]   = id;
  doc["lat"]        = pkt.lat;
  doc["lng"]        = pkt.lng;
  doc["alt"]        = pkt.altitude;
  doc["speed"]      = pkt.speed;
  doc["heading"]    = pkt.heading;
  doc["battery"]    = pkt.battery;
  doc["satellites"] = pkt.satellites;
  doc["rssi"]       = (int)rssi;
  doc["snr"]        = snr;
  doc["seqNum"]     = pkt.seqNum;

  String json;
  serializeJson(doc, json);

  HTTPClient http;
  http.begin(WEBHOOK_URL);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Webhook-Token", WEBHOOK_TOKEN);
  http.setTimeout(5000);

  int httpCode = http.POST(json);

  if (httpCode == 200) {
    postOkCount++;
    Serial.printf("[POST] OK (200) — %s\n", id);
  } else {
    postErrCount++;
    Serial.printf("[POST] Failed — HTTP %d\n", httpCode);
  }
  http.end();
}

// ─── OLED ────────────────────────────────────────────────────────────────────
void updateOled() {
  oled.clear();
  oled.setFont(ArialMT_Plain_10);

  // Line 1: WiFi status
  if (WiFi.status() == WL_CONNECTED) {
    oled.drawString(0, 0,
      String("WiFi: ") + WiFi.localIP().toString());
  } else {
    oled.drawString(0, 0, "WiFi: disconnected");
  }

  // Line 2: Last received
  if (rxCount > 0) {
    oled.drawString(0, 14,
      String("RX: ") + lastHelmetId + " #" + String(lastSeq));
  } else {
    oled.drawString(0, 14, "RX: waiting...");
  }

  // Line 3: Signal quality
  if (rxCount > 0) {
    oled.drawString(0, 28,
      String("RSSI:") + String((int)lastRssi) + " SNR:" + String(lastSnr, 1));
  }

  // Line 4: Counters
  oled.drawString(0, 42,
    String("RX:") + String(rxCount)
    + " OK:" + String(postOkCount)
    + " ERR:" + String(postErrCount));

  // Line 5: LoRa config
  oled.drawString(0, 53,
    String("LoRa ") + String(LORA_FREQ, 1) + "MHz  SF" + String(LORA_SF));

  oled.display();
}

// ─── Setup ───────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  Serial.println("\n[HELIX] Receiver starting...");

  // Vext power on (OLED)
  pinMode(VEXT_PIN, OUTPUT);
  digitalWrite(VEXT_PIN, LOW);

  // Reset OLED
  pinMode(OLED_RST, OUTPUT);
  digitalWrite(OLED_RST, LOW);
  delay(50);
  digitalWrite(OLED_RST, HIGH);
  delay(50);

  oled.init();
  oled.setFont(ArialMT_Plain_10);
  oled.drawString(0, 0, "HELIX Receiver");
  oled.drawString(0, 14, "Initialising...");
  oled.display();

  // WiFi
  connectWiFi();
  delay(500);

  // SPI + Radio
  SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_NSS);

  Serial.print("[LORA] Init SX1276... ");
  int state = radio.begin(LORA_FREQ, LORA_BW, LORA_SF, LORA_CR,
                           LORA_SYNC_WORD, -1, LORA_PREAMBLE);
  // TX power = -1: we're RX only, power doesn't matter
  if (state != RADIOLIB_ERR_NONE) {
    Serial.printf("FAILED (%d)\n", state);
    oled.clear();
    oled.drawString(0, 0, "Radio FAILED!");
    oled.drawString(0, 14, String("Err: ") + String(state));
    oled.display();
    while (true) delay(1000);
  }
  Serial.println("OK");
  Serial.printf("[LORA] Listening on %.1f MHz, SF%d\n", LORA_FREQ, LORA_SF);

  oled.clear();
  oled.drawString(0, 0, "HELIX Receiver ready");
  oled.drawString(0, 14, String("Listening ") + String(LORA_FREQ, 1) + " MHz");
  oled.display();
}

// ─── Loop ────────────────────────────────────────────────────────────────────
void loop() {
  // Try to receive a packet (blocking with short timeout)
  uint8_t buf[64];
  int state = radio.receive(buf, sizeof(HelmetPacket));

  if (state == RADIOLIB_ERR_NONE) {
    size_t len = radio.getPacketLength();

    if (len == sizeof(HelmetPacket)) {
      HelmetPacket pkt;
      memcpy(&pkt, buf, sizeof(pkt));

      float rssi = radio.getRSSI();
      float snr  = radio.getSNR();

      rxCount++;

      // Store for OLED
      memcpy(lastHelmetId, pkt.helmetId, 8);
      lastHelmetId[8] = '\0';
      lastRssi = rssi;
      lastSnr  = snr;
      lastSeq  = pkt.seqNum;

      Serial.printf("[RX] #%u from %s  seq=%u  lat=%.5f lng=%.5f  RSSI=%.0f SNR=%.1f\n",
                    rxCount, lastHelmetId, pkt.seqNum,
                    pkt.lat, pkt.lng, rssi, snr);

      // Forward to webhook server
      postToWebhook(pkt, rssi, snr);
    } else {
      Serial.printf("[RX] Wrong size: got %d, expected %d — ignoring\n",
                    len, sizeof(HelmetPacket));
    }
  } else if (state != RADIOLIB_ERR_RX_TIMEOUT) {
    Serial.printf("[RX] Error: %d\n", state);
  }

  // Reconnect WiFi if lost
  if (WiFi.status() != WL_CONNECTED) {
    static uint32_t lastReconnect = 0;
    if (millis() - lastReconnect > 10000) {
      lastReconnect = millis();
      Serial.println("[WIFI] Reconnecting...");
      WiFi.reconnect();
    }
  }

  // Update OLED
  uint32_t now = millis();
  if (now - lastOledMs >= 1000) {
    lastOledMs = now;
    updateOled();
  }
}
