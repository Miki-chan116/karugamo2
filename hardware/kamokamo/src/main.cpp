#include <M5Atom.h>
#include <NimBLEDevice.h>

int count = 0;
bool lastButtonState = false;
unsigned long lastPressTime = 0;
bool deviceConnected = false;

NimBLECharacteristic* pCharacteristic;

// BLEの名前
const char* BLE_DEVICE_NAME = "KarugamoCounter";

// UUID
#define SERVICE_UUID        "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

class ServerCallbacks : public NimBLEServerCallbacks {
public:
  void onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo) {
    deviceConnected = true;
    Serial.println("Smartphone connected");
    M5.dis.drawpix(0, 0x00ffff);  // 水色
  }

  void onDisconnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo, int reason) {
    deviceConnected = false;
    Serial.println("Smartphone disconnected");

    NimBLEDevice::startAdvertising();

    M5.dis.drawpix(0, 0x0000ff);  // 青
  }
};

void setup() {
  M5.begin(true, false, true);
  Serial.begin(115200);
  delay(1000);

  Serial.println("Karugamo BLE Counter Start");

  // 待機中は青
  M5.dis.drawpix(0, 0x0000ff);

  // BLE初期化
  NimBLEDevice::init(BLE_DEVICE_NAME);

  NimBLEServer* pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  NimBLEService* pService = pServer->createService(SERVICE_UUID);

  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    NIMBLE_PROPERTY::NOTIFY
  );

  pService->start();

  // BLE広告設定
  NimBLEAdvertising* pAdvertising = NimBLEDevice::getAdvertising();

  NimBLEAdvertisementData advData;
  advData.setFlags(0x06); // LE General Discoverable Mode + BR/EDR Not Supported
  advData.addServiceUUID(SERVICE_UUID);

  NimBLEAdvertisementData scanResponseData;
  scanResponseData.setName(BLE_DEVICE_NAME);

  pAdvertising->setAdvertisementData(advData);
  pAdvertising->setScanResponseData(scanResponseData);
  pAdvertising->start();

  Serial.println("BLE advertising config: flags + service uuid + scan response name");
  Serial.println("BLE advertising started");
  Serial.print("Device name: ");
  Serial.println(BLE_DEVICE_NAME);
}

void loop() {
  M5.update();

  bool currentButtonState = M5.Btn.isPressed();

  // 押された瞬間だけ反応
  if (currentButtonState == true && lastButtonState == false) {
    count++;
    unsigned long now = millis();
    unsigned long interval = (count == 1) ? 0 : (now - lastPressTime);

    String payload = "{";
    payload += "\"device_id\":\"atom-001\",";
    payload += "\"press_count\":" + String(count) + ",";
    payload += "\"interval_ms\":" + String(interval);
    payload += "}";

    Serial.print("payload: ");
    Serial.println(payload);

    if (deviceConnected) {
      pCharacteristic->setValue(payload.c_str());
      pCharacteristic->notify();
      Serial.println("BLE notify sent");

      // 接続中に送信成功したら緑
      M5.dis.drawpix(0, 0x00ff00);
      delay(200);

      // 接続中は水色に戻す
      M5.dis.drawpix(0, 0x00ffff);
    } else {
      Serial.println("No smartphone connected");

      // 未接続なら黄色
      M5.dis.drawpix(0, 0xffff00);
      delay(200);

      // 待機青に戻す
      M5.dis.drawpix(0, 0x0000ff);
    }

    lastPressTime = now;
  }

  lastButtonState = currentButtonState;
  delay(10);
}