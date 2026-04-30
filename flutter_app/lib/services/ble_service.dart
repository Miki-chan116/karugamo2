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

  BluetoothDevice? _device;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _notifySubscription;

  final StreamController<AtomLog> _atomLogController =
      StreamController<AtomLog>.broadcast();

  Stream<AtomLog> get atomLogStream => _atomLogController.stream;

  bool isConnected = false;

  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final locationStatus = await Permission.locationWhenInUse.request();

      debugPrint('BLE permission iOS locationWhenInUse: $locationStatus');

      final locationGranted = await Permission.locationWhenInUse.isGranted;

      debugPrint(
        'BLE permission iOS locationWhenInUse isGranted: $locationGranted',
      );

      return locationGranted;
    }

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final scanStatus = statuses[Permission.bluetoothScan];
    final connectStatus = statuses[Permission.bluetoothConnect];
    final locationStatus = statuses[Permission.locationWhenInUse];

    debugPrint('BLE permission Android bluetoothScan: $scanStatus');
    debugPrint('BLE permission Android bluetoothConnect: $connectStatus');
    debugPrint('BLE permission Android locationWhenInUse: $locationStatus');

    final scanGranted = await Permission.bluetoothScan.isGranted;
    final connectGranted = await Permission.bluetoothConnect.isGranted;

    debugPrint('BLE permission Android bluetoothScan isGranted: $scanGranted');
    debugPrint(
      'BLE permission Android bluetoothConnect isGranted: $connectGranted',
    );

    return scanGranted && connectGranted;
  }

  Future<bool> connect({
    required String atomNumber,
    required void Function(String message) onStatusChanged,
  }) async {
    final normalizedAtomNumber = atomNumber.trim();
    final deviceName = 'KarugamoCounter-$normalizedAtomNumber';
    final expectedDeviceId = 'atom-$normalizedAtomNumber';

    debugPrint('BLE target deviceName: $deviceName');
    debugPrint('BLE expected deviceId: $expectedDeviceId');

    try {
      if (normalizedAtomNumber.isEmpty) {
        onStatusChanged('AtomLite番号が未入力です');
        isConnected = false;
        return false;
      }

      if (!RegExp(r'^[0-9]+$').hasMatch(normalizedAtomNumber)) {
        onStatusChanged('AtomLite番号は数字だけで入力してください');
        isConnected = false;
        return false;
      }

      final permissionOk = await requestPermissions();

      if (!permissionOk) {
        onStatusChanged('Bluetooth権限が許可されていません');
        isConnected = false;
        return false;
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      debugPrint('BLE adapterState: $adapterState');

      if (adapterState != BluetoothAdapterState.on) {
        onStatusChanged('スマホのBluetoothがONになっていません');
        isConnected = false;
        return false;
      }

      onStatusChanged('$deviceName を検索中...');

      BluetoothDevice? foundDevice;

      await _scanSubscription?.cancel();
      _scanSubscription = null;

      _scanSubscription = FlutterBluePlus.onScanResults.listen(
        (results) {
          debugPrint('BLE scan results count: ${results.length}');

          for (final result in results) {
            final platformName = result.device.platformName;
            final advName = result.advertisementData.advName;
            final remoteId = result.device.remoteId.str;
            final serviceUuids = result.advertisementData.serviceUuids;
            final rssi = result.rssi;

            debugPrint(
              'BLE scan: platformName=$platformName, advName=$advName, remoteId=$remoteId, rssi=$rssi, serviceUuids=$serviceUuids',
            );

            final nameMatched =
                platformName == deviceName || advName == deviceName;

            if (nameMatched) {
              foundDevice = result.device;
              debugPrint('$deviceName found: $remoteId');

              FlutterBluePlus.stopScan();
              break;
            }
          }
        },
        onError: (error) {
          debugPrint('BLE scan error: $error');
        },
      );

      debugPrint('BLE: stopScan before start');
      await FlutterBluePlus.stopScan();

      debugPrint('BLE: startScan with serviceUuid=$serviceUuid');

      await FlutterBluePlus.startScan(
        withServices: [serviceUuid],
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: false,
      );

      debugPrint('BLE: waiting scan results...');
      await Future.delayed(const Duration(seconds: 10));

      debugPrint('BLE: stopScan after wait');
      await FlutterBluePlus.stopScan();

      await _scanSubscription?.cancel();
      _scanSubscription = null;

      if (foundDevice == null) {
        onStatusChanged('$deviceName が見つかりませんでした');
        isConnected = false;
        return false;
      }

      _device = foundDevice;

      onStatusChanged('$deviceName に接続中...');

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

          if (log.deviceId != expectedDeviceId) {
            onStatusChanged(
              '接続対象が違います。期待: $expectedDeviceId / 受信: ${log.deviceId}',
            );
            debugPrint(
              'BLE device_id mismatch. expected=$expectedDeviceId actual=${log.deviceId}',
            );
            return;
          }

          _atomLogController.add(log);
          onStatusChanged('ATOM Liteから受信しました');
        } catch (error) {
          debugPrint('BLE received parse error: $error');
          onStatusChanged('受信データの解析に失敗しました: $text');
        }
      });

      onStatusChanged('$deviceName 接続完了。ボタン押下待ちです');
      return true;
    } catch (error, stackTrace) {
      debugPrint('BLE connect error: $error');
      debugPrint('BLE connect stackTrace: $stackTrace');

      onStatusChanged('ATOM Lite接続に失敗しました');
      isConnected = false;

      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}

      await _scanSubscription?.cancel();
      _scanSubscription = null;

      return false;
    }
  }

  Future<void> disconnect() async {
    await _notifySubscription?.cancel();
    _notifySubscription = null;

    if (_notifyCharacteristic != null) {
      try {
        await _notifyCharacteristic!.setNotifyValue(false);
      } catch (error) {
        debugPrint('BLE setNotifyValue(false) error: $error');
      }

      _notifyCharacteristic = null;
    }

    try {
      await _device?.disconnect();
    } catch (error) {
      debugPrint('BLE disconnect error: $error');
    }

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