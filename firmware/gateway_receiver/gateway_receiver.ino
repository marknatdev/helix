/*
 * =====================================================================
 * HELIX GATEWAY - RECEIVER FIRMWARE (ESP32 LoRa Gateway to Supabase)
 * =====================================================================
 * Component: Construction Site Receiver Gateway
 * Microcontroller: ESP32-WROOM-32 / TTGO ESP32 LoRa Gateway
 * Modules:
 *   - SX1276 LoRa Receiver (915MHz / 868MHz)
 *   - Wi-Fi Client (Connects to Site Hotspot / Cellular Router)
 *   - HTTPClient (Posts decoded JSON telemetry to Supabase REST API)
 * =====================================================================
 */

#include <SPI.h>
#include <LoRa.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// --- WI-FI & SUPABASE CONFIGURATION ---
const char* WIFI_SSID = "CONSTRUCTION_SITE_WIFI";
const char* WIFI_PASS = "SafetyFirst2026";

// Supabase REST Endpoint URL & Anonymous Key
const char* SUPABASE_URL = "https://YOUR_SUPABASE_PROJECT_ID.supabase.co/rest/v1";
const char* SUPABASE_KEY = "YOUR_SUPABASE_ANON_KEY";

// --- PIN DEFINITIONS ---
#define LORA_SCK     5
#define LORA_MISO    19
#define LORA_MOSI    27
#define LORA_SS      18
#define LORA_RST     23
#define LORA_DIO0    26
#define LORA_BAND    915E6

void setup() {
    Serial.begin(115200);
    while (!Serial && millis() < 3000);

    Serial.println("\n[HELIX GATEWAY] Initializing Receiver ESP32...");

    // 1. Connect to Wi-Fi
    WiFi.begin(WIFI_SSID, WIFI_PASS);
    Serial.print("[WIFI] Connecting to ");
    Serial.print(WIFI_SSID);
    int wifiAttempts = 0;
    while (WiFi.status() != WL_CONNECTED && wifiAttempts < 20) {
        delay(500);
        Serial.print(".");
        wifiAttempts++;
    }
    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\n[WIFI] Connected! IP Address: " + WiFi.localIP().toString());
    } else {
        Serial.println("\n[WIFI WARNING] WiFi connection failed. Will buffer payloads.");
    }

    // 2. Initialize LoRa SPI & Receiver
    SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_SS);
    LoRa.setPins(LORA_SS, LORA_RST, LORA_DIO0);

    if (!LoRa.begin(LORA_BAND)) {
        Serial.println("[LORA ERROR] Gateway LoRa Init failed!");
        while (1);
    }

    Serial.println("[GATEWAY] Receiver Ready. Listening for Smart Helmet LoRa Packets...");
}

void loop() {
    // Check for incoming LoRa packet
    int packetSize = LoRa.parsePacket();
    if (packetSize) {
        String packetContent = "";
        while (LoRa.available()) {
            packetContent += (char)LoRa.read();
        }

        int rssi = LoRa.packetRssi();
        float snr = LoRa.packetSnr();

        Serial.println("\n[LORA RX] Received (" + String(packetSize) + " bytes), RSSI: " + String(rssi) + " dBm, SNR: " + String(snr));
        Serial.println("Payload: " + packetContent);

        // Process Packet & Relay to Supabase
        processLoRaPayload(packetContent, rssi, snr);
    }
}

void processLoRaPayload(String rawJson, int rssi, float snr) {
    StaticJsonDocument<512> doc;
    DeserializationError error = deserializeJson(doc, rawJson);

    if (error) {
        Serial.print("[JSON ERROR] Parsing failed: ");
        Serial.println(error.f_str());
        return;
    }

    const char* devId = doc["dev"];
    float lat = doc["lat"];
    float lng = doc["lng"];
    const char* posture = doc["posture"];
    int bat = doc["bat"];
    bool sos = doc["sos"];

    // Relay Telemetry Log to Supabase via HTTP REST POST
    if (WiFi.status() == WL_CONNECTED) {
        HTTPClient http;
        String endpoint = String(SUPABASE_URL) + "/telemetry_logs";

        http.begin(endpoint);
        http.addHeader("Content-Type", "application/json");
        http.addHeader("apikey", SUPABASE_KEY);
        http.addHeader("Authorization", "Bearer " + String(SUPABASE_KEY));
        http.addHeader("Prefer", "return=minimal");

        // Construct Supabase DB Payload
        StaticJsonDocument<512> supabaseDoc;
        supabaseDoc["latitude"] = lat;
        supabaseDoc["longitude"] = lng;
        supabaseDoc["posture_state"] = posture;
        supabaseDoc["battery_pct"] = bat;
        supabaseDoc["rssi"] = rssi;
        supabaseDoc["snr"] = snr;

        String postBody;
        serializeJson(supabaseDoc, postBody);

        int httpCode = http.POST(postBody);
        Serial.print("[SUPABASE REST] POST /telemetry_logs Response: ");
        Serial.println(httpCode);
        http.end();

        // If SOS or Fall Detected, log Critical Incident to Supabase
        if (sos || String(posture) == "FALL_DETECTED") {
            HTTPClient httpInc;
            String incEndpoint = String(SUPABASE_URL) + "/incidents";
            httpInc.begin(incEndpoint);
            httpInc.addHeader("Content-Type", "application/json");
            httpInc.addHeader("apikey", SUPABASE_KEY);
            httpInc.addHeader("Authorization", "Bearer " + String(SUPABASE_KEY));

            StaticJsonDocument<512> incDoc;
            incDoc["event_type"] = sos ? "PANIC_SOS" : "FALL_DETECTION";
            incDoc["severity"] = "CRITICAL";
            incDoc["status"] = "OPEN";
            incDoc["latitude"] = lat;
            incDoc["longitude"] = lng;
            incDoc["details"] = String("LoRa Alert from ") + devId + ". Signal RSSI: " + String(rssi) + " dBm";

            String incBody;
            serializeJson(incDoc, incBody);

            int incCode = httpInc.POST(incBody);
            Serial.print("[SUPABASE REST] POST /incidents Critical Alert Response: ");
            Serial.println(incCode);
            httpInc.end();
        }
    }
}
