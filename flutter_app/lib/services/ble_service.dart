import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class AtomLog {
  final String deviceId;
  final int pressCount;
  final int intervalMs;

  AtomLog({
    required this.deviceId,
    required this.pressCount,
    required this.intervalMs,
  });

  factory AtomLog.fromJson(Map<String, dynamic> json) {
    return AtomLog(
      deviceId: json['device_id']?.toString() ?? 'atom-001',
      pressCount: int.tryParse(json['press_count'].toString()) ?? 0,
      intervalMs: int.tryParse(json['interval_ms'].toString()) ?? 0,
    );
  }
}

class BleService {
  static final Guid serviceUuid = Guid(
    '6E400001-B5A3-F393-E0A9-E50E24DCCA9E',
  );

  static final Guid characteristicUuid = Guid(
    '6E400003-B5A3-F393-E0A9-E50E24DCCA9E',
  );

  static const String deviceName = 'KarugamoCounter';

  BluetoothDevice? _device;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _notifySubscription;

  final StreamController<AtomLog> _atomLogController =
      StreamController<AtomLog>.broadcast();

  Stream<AtomLog> get atomLogStream => _atomLogController.stream;

  bool isConnected = false;

  Future<void> requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<bool> connect({
    required void Function(String message) onStatusChanged,
  }) async {
    await requestPermissions();

    onStatusChanged('ATOM Liteを検索中...');

    BluetoothDevice? foundDevice;

    await _scanSubscription?.cancel();
    _scanSubscription = null;

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final platformName = result.device.platformName;
        final advName = result.advertisementData.advName;
        final remoteId = result.device.remoteId.str;
        final serviceUuids = result.advertisementData.serviceUuids;

        debugPrint(
          'BLE scan: platformName=$platformName, advName=$advName, remoteId=$remoteId, serviceUuids=$serviceUuids',
        );

        final nameMatched =
            platformName == deviceName || advName == deviceName;

        final serviceMatched = serviceUuids.any(
          (uuid) =>
              uuid.toString().toLowerCase() ==
              serviceUuid.toString().toLowerCase(),
        );

        if (nameMatched || serviceMatched) {
          foundDevice = result.device;
          debugPrint('KarugamoCounter found: $remoteId');
          break;
        }
      }
    });

    await FlutterBluePlus.stopScan();
    await FlutterBluePlus.startScan();

    await Future.delayed(const Duration(seconds: 10));

    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    if (foundDevice == null) {
      onStatusChanged('KarugamoCounterが見つかりませんでした');
      isConnected = false;
      return false;
    }

    _device = foundDevice;

    onStatusChanged('ATOM Liteに接続中...');

    await _device!.connect(
      timeout: const Duration(seconds: 10),
      autoConnect: false,
    );

    isConnected = true;

    onStatusChanged('接続しました。サービスを確認中...');

    final services = await _device!.discoverServices();

    for (final service in services) {
      debugPrint('BLE service: ${service.uuid}');

      if (service.uuid.toString().toLowerCase() ==
          serviceUuid.toString().toLowerCase()) {
        for (final characteristic in service.characteristics) {
          debugPrint('BLE characteristic: ${characteristic.uuid}');

          if (characteristic.uuid.toString().toLowerCase() ==
              characteristicUuid.toString().toLowerCase()) {
            _notifyCharacteristic = characteristic;
            break;
          }
        }
      }
    }

    if (_notifyCharacteristic == null) {
      onStatusChanged('Notify用Characteristicが見つかりませんでした');
      isConnected = false;
      return false;
    }

    await _notifyCharacteristic!.setNotifyValue(true);

    await _notifySubscription?.cancel();

    _notifySubscription =
        _notifyCharacteristic!.onValueReceived.listen((value) {
      final text = utf8.decode(value);

      debugPrint('BLE received: $text');

      try {
        final jsonMap = jsonDecode(text) as Map<String, dynamic>;
        final log = AtomLog.fromJson(jsonMap);
        _atomLogController.add(log);
        onStatusChanged('ATOM Liteから受信しました');
      } catch (_) {
        onStatusChanged('受信データの解析に失敗しました: $text');
      }
    });

    onStatusChanged('ATOM Lite接続完了。ボタン押下待ちです');
    return true;
  }

  Future<void> disconnect() async {
    await _notifySubscription?.cancel();
    _notifySubscription = null;

    if (_notifyCharacteristic != null) {
      await _notifyCharacteristic!.setNotifyValue(false);
      _notifyCharacteristic = null;
    }

    await _device?.disconnect();
    _device = null;
    isConnected = false;
  }

  void dispose() {
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _device?.disconnect();
    _atomLogController.close();
  }
}