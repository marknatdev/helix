/**
 * sender.ino — HELIX Helmet LoRa Sender
 * ────────────────────────────────────────────────────────────────────────────
 * Heltec WiFi LoRa 32 V2 · SX1276
 * Reads GPS (or fakes it), battery voltage, packs into a binary struct,
 * and transmits via raw LoRa every TX_INTERVAL_S seconds.
 *
 * Libraries (Arduino Library Manager):
 *   - RadioLib               by Jan Gromes
 *   - TinyGPSPlus            by Mikal Hart        (only if USE_REAL_GPS)
 *   - ESP8266 and ESP32 OLED driver for SSD1306 displays  by ThingPulse
 *
 * Board: ESP32 Dev Module
 * ────────────────────────────────────────────────────────────────────────────
 */

#include "config.h"

#include <RadioLib.h>
#include <SPI.h>
#include <Wire.h>
#include "SSD1306Wire.h"

#if USE_REAL_GPS
#include <TinyGPSPlus.h>
TinyGPSPlus    gps;
HardwareSerial gpsSerial(1);
#endif

// ─── Packet structure (must match receiver) ──────────────────────────────────
// Total: 8 + 4 + 4 + 4 + 4 + 4 + 1 + 1 + 2 = 32 bytes
struct __attribute__((packed)) HelmetPacket {
  char     helmetId[8];   // e.g. "HLX-001\0"
  float    lat;
  float    lng;
  float    altitude;
  float    speed;         // m/s
  float    heading;       // degrees
  uint8_t  battery;       // 0-100 %
  uint8_t  satellites;
  uint16_t seqNum;
};

// ─── Hardware ────────────────────────────────────────────────────────────────
SX1276 radio = new Module(LORA_NSS, LORA_DIO0, LORA_RST, LORA_DIO1);
SSD1306Wire oled(OLED_ADDR, OLED_SDA, OLED_SCL);

// ─── State ───────────────────────────────────────────────────────────────────
static uint16_t seqNum     = 0;
static uint32_t txCount    = 0;
static uint32_t lastTxMs   = 0;
static uint32_t lastOledMs = 0;

// Fake GPS state (random walk)
static float fakeLat     = FAKE_LAT;
static float fakeLng     = FAKE_LNG;
static float fakeHeading = 90.0f;

// ─── Battery ─────────────────────────────────────────────────────────────────
float readBatteryVoltage() {
  uint16_t raw = analogRead(VBAT_PIN);
  return (raw / 4095.0f) * 3.3f * VBAT_DIVIDER_RATIO;
}

uint8_t voltageToPct(float v) {
  if (v >= VBAT_MAX) return 100;
  if (v <= VBAT_MIN) return 0;
  return (uint8_t)(((v - VBAT_MIN) / (VBAT_MAX - VBAT_MIN)) * 100.0f);
}

// ─── Fake GPS random walk ────────────────────────────────────────────────────
void stepFakeGps() {
  fakeHeading += (float)(random(-1500, 1500)) / 100.0f;  // ±15°
  if (fakeHeading < 0)   fakeHeading += 360.0f;
  if (fakeHeading > 360) fakeHeading -= 360.0f;

  float dist = FAKE_SPEED * (float)TX_INTERVAL_S;  // meters
  float rad  = fakeHeading * PI / 180.0f;
  fakeLat += (dist * cos(rad)) / 111111.0f;
  float cosLat = cos(fakeLat * PI / 180.0f);
  if (cosLat < 0.01f) cosLat = 0.01f;
  fakeLng += (dist * sin(rad)) / (111111.0f * cosLat);
}

// ─── Build packet ────────────────────────────────────────────────────────────
void buildPacket(HelmetPacket &pkt) {
  memset(&pkt, 0, sizeof(pkt));
  strncpy(pkt.helmetId, HELMET_ID, 8);

#if USE_REAL_GPS
  if (gps.location.isValid()) {
    pkt.lat       = (float)gps.location.lat();
    pkt.lng       = (float)gps.location.lng();
    pkt.altitude  = (float)gps.altitude.meters();
    pkt.speed     = (float)gps.speed.mps();
    pkt.heading   = (float)gps.course.deg();
    pkt.satellites = (uint8_t)gps.satellites.value();
  }
#else
  stepFakeGps();
  pkt.lat        = fakeLat;
  pkt.lng        = fakeLng;
  pkt.altitude   = FAKE_ALT;
  pkt.speed      = FAKE_SPEED;
  pkt.heading    = fakeHeading;
  pkt.satellites = FAKE_SATS;
#endif

  pkt.battery = voltageToPct(readBatteryVoltage());
  pkt.seqNum  = seqNum++;
}

// ─── OLED ────────────────────────────────────────────────────────────────────
void updateOled(const HelmetPacket &pkt) {
  oled.clear();
  oled.setFont(ArialMT_Plain_10);

  oled.drawString(0, 0,
    String("TX: ") + HELMET_ID + "  #" + String(txCount));

  oled.drawString(0, 14,
    String(pkt.lat, 5) + ", " + String(pkt.lng, 5));

  oled.drawString(0, 28,
    String("Spd:") + String(pkt.speed, 1) + " Hdg:" + String(pkt.heading, 0)
    + " Sat:" + String(pkt.satellites));

  float v = readBatteryVoltage();
  oled.drawString(0, 42,
    String("Bat:") + String(v, 2) + "V (" + String(pkt.battery) + "%)");

  oled.drawString(0, 53,
    String("LoRa ") + String(LORA_FREQ, 1) + "MHz  SF" + String(LORA_SF));

  oled.display();
}

// ─── Setup ───────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  Serial.println("\n[HELIX] Sender starting...");

  // Seed random for fake GPS
  randomSeed(analogRead(0));

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
  oled.drawString(0, 0, "HELIX Sender");
  oled.drawString(0, 14, "Initialising...");
  oled.display();

#if USE_REAL_GPS
  gpsSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
  Serial.println("[GPS] UART started");
#else
  Serial.println("[GPS] Fake mode — random walk from Bangkok");
#endif

  // Battery ADC
  analogReadResolution(12);
  pinMode(VBAT_PIN, INPUT);

  // SPI + Radio
  SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_NSS);

  Serial.print("[LORA] Init SX1276... ");
  int state = radio.begin(LORA_FREQ, LORA_BW, LORA_SF, LORA_CR,
                           LORA_SYNC_WORD, LORA_TX_POWER, LORA_PREAMBLE);
  if (state != RADIOLIB_ERR_NONE) {
    Serial.printf("FAILED (%d)\n", state);
    oled.clear();
    oled.drawString(0, 0, "Radio FAILED!");
    oled.drawString(0, 14, String("Err: ") + String(state));
    oled.display();
    while (true) delay(1000);
  }
  Serial.println("OK");

  oled.clear();
  oled.drawString(0, 0, "HELIX Sender ready");
  oled.drawString(0, 14, String("Freq: ") + String(LORA_FREQ, 1) + " MHz");
  oled.drawString(0, 28, String("TX every ") + String(TX_INTERVAL_S) + "s");
  oled.display();

  lastTxMs = millis();
  Serial.printf("[LORA] Ready — %.1f MHz, SF%d, TX every %ds\n",
                LORA_FREQ, LORA_SF, TX_INTERVAL_S);
}

// ─── Loop ────────────────────────────────────────────────────────────────────
void loop() {
#if USE_REAL_GPS
  while (gpsSerial.available() > 0) {
    gps.encode(gpsSerial.read());
  }
#endif

  uint32_t now = millis();

  // Transmit at interval
  if (now - lastTxMs >= (uint32_t)TX_INTERVAL_S * 1000UL) {
    lastTxMs = now;

    HelmetPacket pkt;
    buildPacket(pkt);

    Serial.printf("[TX] #%u  lat=%.5f lng=%.5f bat=%u%% seq=%u ... ",
                  txCount + 1, pkt.lat, pkt.lng, pkt.battery, pkt.seqNum);

    int state = radio.transmit((uint8_t *)&pkt, sizeof(pkt));

    if (state == RADIOLIB_ERR_NONE) {
      txCount++;
      Serial.printf("OK (%d bytes)\n", sizeof(pkt));
    } else {
      Serial.printf("FAILED (%d)\n", state);
    }

    updateOled(pkt);
  }

  // Refresh OLED between TX (show live battery, GPS)
  if (now - lastOledMs >= 1000) {
    lastOledMs = now;
    // Light refresh — just re-draw with last known data
  }
}
