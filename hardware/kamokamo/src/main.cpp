#include <M5Atom.h>
#include <NimBLEDevice.h>
#include <Preferences.h>

int count = 0;
bool lastButtonState = false;
unsigned long lastPressTime = 0;
bool deviceConnected = false;

NimBLECharacteristic* pCharacteristic;

// BLEの名前
const char* BLE_DEVICE_NAME_PREFIX = "KarugamoCounter";
String bleDeviceName = "KarugamoCounter-unset";

// UUID
#define SERVICE_UUID        "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

// device_id保存用
Preferences prefs;
String deviceId = "atom-unset";

// シリアル入力用
String serialBuffer = "";

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

void printHelp() {
  Serial.println("Available commands:");
  Serial.println("  GET_ID");
  Serial.println("  SET_ID atom-001");
  Serial.println("  RESET_ID");
}

String buildBleDeviceName(String id) {
  id.trim();

  if (id.startsWith("atom-")) {
    String number = id.substring(5);
    number.trim();

    if (number.length() > 0) {
      return String(BLE_DEVICE_NAME_PREFIX) + "-" + number;
    }
  }

  return String(BLE_DEVICE_NAME_PREFIX) + "-unset";
}

void handleSerialCommand(String command) {
  command.trim();

  if (command.length() == 0) {
    return;
  }

  Serial.print("command: ");
  Serial.println(command);

  if (command == "HELP") {
    printHelp();
    return;
  }

  if (command == "GET_ID") {
    Serial.print("Current device_id: ");
    Serial.println(deviceId);
    return;
  }

  if (command == "RESET_ID") {
    deviceId = "atom-unset";
    prefs.putString("device_id", deviceId);

    Serial.print("OK device_id reset: ");
    Serial.println(deviceId);
    return;
  }

  if (command.startsWith("SET_ID ")) {
    String newDeviceId = command.substring(7);
    newDeviceId.trim();

    if (newDeviceId.length() == 0) {
      Serial.println("ERROR device_id is empty");
      return;
    }

    deviceId = newDeviceId;
    prefs.putString("device_id", deviceId);

    Serial.print("OK device_id=");
    Serial.println(deviceId);
    return;
  }

  Serial.println("ERROR unknown command");
  printHelp();
}

void checkSerialCommand() {
  while (Serial.available() > 0) {
    char c = Serial.read();

    if (c == '\n' || c == '\r') {
      if (serialBuffer.length() > 0) {
        handleSerialCommand(serialBuffer);
        serialBuffer = "";
      }
    } else {
      serialBuffer += c;
    }
  }
}

void setup() {
  M5.begin(true, false, true);
  Serial.begin(115200);
  delay(1000);

  Serial.println("Karugamo BLE Counter Start");

  // device_id読み込み
  prefs.begin("karugamo", false);
  deviceId = prefs.getString("device_id", "atom-unset");
  bleDeviceName = buildBleDeviceName(deviceId);

  Serial.print("Current device_id: ");
  Serial.println(deviceId);

  Serial.print("BLE device name: ");
  Serial.println(bleDeviceName);

  printHelp();

  // 待機中は青
  M5.dis.drawpix(0, 0x0000ff);

  // BLE初期化
  NimBLEDevice::init(bleDeviceName.c_str());

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
  scanResponseData.setName(bleDeviceName.c_str());

  pAdvertising->setAdvertisementData(advData);
  pAdvertising->setScanResponseData(scanResponseData);
  pAdvertising->start();

  Serial.println("BLE advertising config: flags + service uuid + scan response name");
  Serial.println("BLE advertising started");
  Serial.print("Device name: ");
  Serial.println(bleDeviceName);
}

void loop() {
  M5.update();

  // PCからの設定コマンドを確認
  checkSerialCommand();

  bool currentButtonState = M5.Btn.isPressed();

  // 押された瞬間だけ反応
  if (currentButtonState == true && lastButtonState == false) {
    count++;
    unsigned long now = millis();
    unsigned long interval = (count == 1) ? 0 : (now - lastPressTime);

    String payload = "{";
    payload += "\"device_id\":\"" + deviceId + "\",";
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