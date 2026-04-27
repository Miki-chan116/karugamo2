# BLE送信データ仕様

## 概要
ATOM Liteは、ボタンが押されるたびにBluetooth NotifyでJSON文字列を送信する。

## 送信データ例

```json
{
  "device_id": "atom-001",
  "press_count": 1,
  "interval_ms": 530
}