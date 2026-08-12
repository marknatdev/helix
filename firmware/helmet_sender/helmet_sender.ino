/*
 * ===================================================================
 * HELIX SMART HELMET - SENDER FIRMWARE (ESP32 + LoRa + MPU6050 + GPS)
 * ===================================================================
 * Component: Smart Helmet (Sender)
 * Microcontroller: ESP32-WROOM-32 / TTGO T-Beam ESP32 LoRa
 * Sensors:
 *   - LoRa Transceiver (SX1276 / SX1278 @ 915MHz / 868MHz)
 *   - MPU6050 IMU (Accelerometer + Gyroscope via I2C)
 *   - NEO-6M / NEO-8M GPS (via UART Serial2)
 *   - Battery Voltage ADC (GPIO 35 with voltage divider)
 *   - Panic / SOS Button (GPIO 15)
 * ===================================================================
 */

#include <Wire.h>
#include <SPI.h>
#include <LoRa.h>
#include <MPU6050.h>
#include <TinyGPS++.h>

// --- PIN DEFINITIONS (TTGO T-Beam / Standard ESP32 LoRa) ---
#define LORA_SCK     5
#define LORA_MISO    19
#define LORA_MOSI    27
#define LORA_SS      18
#define LORA_RST     23
#define LORA_DIO0    26
#define LORA_BAND    915E6 // Change to 868E6 or 433E6 depending on region

#define GPS_RX_PIN   12
#define GPS_TX_PIN   34

#define BATTERY_ADC_PIN 35
#define SOS_BUTTON_PIN  15

// Helmet & LoRa Address Config
const char* HELMET_ID = "HELMET-001";
const uint8_t LORA_NODE_ID = 101;

// Hardware Interfaces
MPU6050 mpu;
TinyGPSPlus gps;
HardwareSerial gpsSerial(2);

// Telemetry State Variables
enum PostureState { SITTING, STANDING, WALKING, RUNNING, FALL_DETECTED };
PostureState currentPosture = STANDING;
float currentLat = 13.7563;  // Default fallback site lat
float currentLng = 100.5018; // Default fallback site lng
int batteryPercent = 95;
bool sosActive = false;

// Fall Detection Thresholds
const float FALL_G_THRESHOLD = 3.2g; // High acceleration impact (g)
const unsigned long POST_FALL_STILL_TIME_MS = 3000;

void setup() {
    Serial.begin(115200);
    while (!Serial && millis() < 3000);

    Serial.println("\n[HELIX HELMET] Initializing ESP32 Sender...");

    // 1. Initialize SOS Button Pin
    pinMode(SOS_BUTTON_PIN, INPUT_PULLUP);

    // 2. Initialize I2C MPU6050
    Wire.begin(21, 22);
    mpu.initialize();
    if (mpu.testConnection()) {
        Serial.println("[IMU] MPU6050 Connected successfully.");
    } else {
        Serial.println("[IMU ERROR] MPU6050 Connection failed!");
    }

    // 3. Initialize GPS Hardware Serial
    gpsSerial.begin(9600, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
    Serial.println("[GPS] Initialized Serial2.");

    // 4. Initialize LoRa SPI
    SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_SS);
    LoRa.setPins(LORA_SS, LORA_RST, LORA_DIO0);

    if (!LoRa.begin(LORA_BAND)) {
        Serial.println("[LORA ERROR] LoRa Init failed!");
        while (1);
    }
    LoRa.setTxPower(20);
    LoRa.setSpreadingFactor(7);
    Serial.println("[LORA] LoRa Transceiver Ready @ 915MHz.");
}

void loop() {
    // 1. Read GPS Data
    while (gpsSerial.available() > 0) {
        gps.encode(gpsSerial.read());
    }
    if (gps.location.isValid()) {
        currentLat = gps.location.lat();
        currentLng = gps.location.lng();
    }

    // 2. Read MPU6050 Accelerometer for Behavior & Fall Detection
    int16_t ax, ay, az, gx, gy, gz;
    mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);

    // Calculate total G-force acceleration magnitude
    float gForce = sqrt((float)ax*ax + (float)ay*ay + (float)az*az) / 16384.0;
    float gyroMag = sqrt((float)gx*gx + (float)gy*gy + (float)gz*gz) / 131.0;

    // Detect Fall
    if (gForce > 3.2) {
        currentPosture = FALL_DETECTED;
        Serial.println("[ALERT] IMPACT/FALL DETECTED!");
    } else if (gyroMag > 120.0) {
        currentPosture = RUNNING;
    } else if (gyroMag > 30.0) {
        currentPosture = WALKING;
    } else if (abs(az) < 8000) {
        currentPosture = SITTING; // Helmet tilted horizontally
    } else {
        currentPosture = STANDING;
    }

    // 3. Read Battery ADC
    int adcRaw = analogRead(BATTERY_ADC_PIN);
    float voltage = (adcRaw / 4095.0) * 3.3 * 2.0; // Voltage divider factor 2
    batteryPercent = constrain((int)((voltage - 3.2) / (4.2 - 3.2) * 100), 0, 100);

    // 4. Check Panic SOS Button
    if (digitalRead(SOS_BUTTON_PIN) == LOW) {
        sosActive = true;
    }

    // 5. Package & Transmit LoRa Payload Packet
    sendLoRaTelemetry();

    delay(2000); // Transmission interval (2 seconds)
}

void sendLoRaTelemetry() {
    String postureStr = "STANDING";
    switch(currentPosture) {
        case SITTING: postureStr = "SITTING"; break;
        case STANDING: postureStr = "STANDING"; break;
        case WALKING: postureStr = "WALKING"; break;
        case RUNNING: postureStr = "RUNNING"; break;
        case FALL_DETECTED: postureStr = "FALL_DETECTED"; break;
    }

    // Construct JSON Payload string
    String jsonPayload = "{";
    jsonPayload += "\"dev\":\"" + String(HELMET_ID) + "\",";
    jsonPayload += "\"node\":" + String(LORA_NODE_ID) + ",";
    jsonPayload += "\"lat\":" + String(currentLat, 6) + ",";
    jsonPayload += "\"lng\":" + String(currentLng, 6) + ",";
    jsonPayload += "\"posture\":\"" + postureStr + "\",";
    jsonPayload += "\"bat\":" + String(batteryPercent) + ",";
    jsonPayload += "\"sos\":" + String(sosActive ? "true" : "false");
    jsonPayload += "}";

    Serial.print("[LORA TX] Sending: ");
    Serial.println(jsonPayload);

    LoRa.beginPacket();
    LoRa.print(jsonPayload);
    LoRa.endPacket();

    if (sosActive) sosActive = false; // Reset SOS latch after transmit
}
