import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class KarugamoBleService {
  static const String targetDeviceName = 'KarugamoCounter';

  static final Guid serviceUuid = Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E');

  static final Guid notifyCharacteristicUuid = Guid(
    '6E400003-B5A3-F393-E0A9-E50E24DCCA9E',
  );

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;

  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  Stream<String> get stream => _controller.stream;

  Future<void> scanAndConnect() async {
    print('===== BLEスキャン開始 =====');

    await FlutterBluePlus.stopScan();

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    final subscription = FlutterBluePlus.scanResults.listen((results) async {
      for (final result in results) {
        final deviceName = result.device.platformName;
        final advName = result.advertisementData.advName;
        final remoteId = result.device.remoteId.str;
        final rssi = result.rssi;

        print(
          '発見: deviceName=[$deviceName] advName=[$advName] id=[$remoteId] rssi=[$rssi]',
        );

        if (deviceName.contains(targetDeviceName) ||
            advName.contains(targetDeviceName)) {
          print('KarugamoCounterを発見しました');

          await FlutterBluePlus.stopScan();

          _device = result.device;

          await _device!.connect(license: License.free);

          print('KarugamoCounterに接続しました');

          await _discover();
          return;
        }
      }
    });

    await Future.delayed(const Duration(seconds: 10));
    await subscription.cancel();
    await FlutterBluePlus.stopScan();

    if (_device == null) {
      print('KarugamoCounterが見つかりませんでした');
      _controller.add('KarugamoCounterが見つかりませんでした');
    }
  }

  Future<void> _discover() async {
    if (_device == null) {
      print('デバイス未接続です');
      return;
    }

    print('サービス探索開始');

    final services = await _device!.discoverServices();

    for (final service in services) {
      print('Service UUID: ${service.uuid}');

      if (service.uuid == serviceUuid) {
        print('目的のServiceを発見');

        for (final characteristic in service.characteristics) {
          print('Characteristic UUID: ${characteristic.uuid}');

          if (characteristic.uuid == notifyCharacteristicUuid) {
            print('Notify用Characteristicを発見');

            // ⭐️ここが修正ポイント
            if (_characteristic == null) {
              _characteristic = characteristic;

              await _characteristic!.setNotifyValue(true);

              _characteristic!.onValueReceived.listen((value) {
                final text = utf8.decode(value);
                print('受信: $text');
                _controller.add(text);
              });
            }

            _controller.add('接続成功：ATOM Liteのボタンを押してください');
            return;
          }
        }
      }
    }

    print('Notify用Characteristicが見つかりませんでした');
    _controller.add('Notify用Characteristicが見つかりませんでした');
  }
}
