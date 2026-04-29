import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/log_item.dart';
import '../services/gas_api_service.dart';
import '../services/ble_service.dart';

class HomeScreen extends StatefulWidget {
  final BleService bleService;
  final bool isBleConnected;

  const HomeScreen({
    super.key,
    required this.bleService,
    required this.isBleConnected,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> logs = [];

  late final BleService _bleService;
  late bool _isBleConnected;
  String _bleStatus = 'ATOM Lite未接続';
  StreamSubscription<AtomLog>? _atomLogSubscription;

  @override
  void initState() {
    super.initState();

    _bleService = widget.bleService;
    _isBleConnected = widget.isBleConnected;
    _bleStatus = _isBleConnected ? 'ATOM Lite接続中' : 'ATOM Lite未接続';

    _atomLogSubscription = _bleService.atomLogStream.listen((atomLog) {
      final now = DateTime.now();

      final timeText =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      setState(() {
        logs.add({
          "time": timeText,
          "count": atomLog.pressCount,
          "received_at": now,
          "interval_ms": atomLog.intervalMs,
          "device_id": atomLog.deviceId,
          "source": "atom",
        });
      });
    });
  }  

  void _addLog() {
    final now = DateTime.now();

    final timeText =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    int intervalMs = 0;

    if (logs.isNotEmpty) {
      final previousTime = logs.last["received_at"] as DateTime;
      intervalMs = now.difference(previousTime).inMilliseconds;
    }

    setState(() {
      logs.add({
        "time": timeText,
        "count": logs.length + 1,
        "received_at": now,
        "interval_ms": intervalMs,
        "device_id": "manual-device",
        "source": "manual",
      });
    });
  }

  // Future<void> _connectAtomLite() async {
  //   setState(() {
  //     _bleStatus = 'ATOM Lite接続準備中...';
  //   });

  //   try {
  //     await _bleService.connect(
  //       onLogReceived: (atomLog) {
  //         final now = DateTime.now();

  //         final timeText =
  //             "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

  //         setState(() {
  //           logs.add({
  //             "time": timeText,
  //             "count": atomLog.pressCount,
  //             "received_at": now,
  //             "interval_ms": atomLog.intervalMs,
  //             "device_id": atomLog.deviceId,
  //             "source": "atom",
  //           });
  //         });
  //       },
  //       onStatusChanged: (message) {
  //         setState(() {
  //           _bleStatus = message;

  //           if (message.contains('接続完了')) {
  //             _isBleConnected = true;
  //           }
  //         });
  //       },
  //     );
  //   } catch (e) {
  //     setState(() {
  //       _bleStatus = 'ATOM Lite接続エラー: $e';
  //       _isBleConnected = false;
  //     });
  //   }
  // }

  Future<void> _sendLogs() async {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('送信するデータがありません')),
      );
      return;
    }

    int successCount = 0;

    for (final log in logs) {
      final success = await GasApiService.sendLog(
        deviceId: log["device_id"],
        pressCount: log["count"],
        intervalMs: log["interval_ms"],
        source: log["source"],
      );

      if (success) {
        successCount++;
      }
    }

    if (!mounted) return;

    if (successCount == logs.length) {
      final sentCount = successCount;

      setState(() {
        logs.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$sentCount件送信しました')),
      );
    } else {
      final failedCount = logs.length - successCount;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount件送信、$failedCount件失敗しました'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _atomLogSubscription?.cancel();
    _bleService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0b5a35),
      appBar: AppBar(
        title: const Text('🦆 カウンター2'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4DFF9E),
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _addLog,
                child: const Text("➕ 打刻"),
              ),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isBleConnected ? Colors.white : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _bleStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _bleStatus,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ListView(
                children: logs.reversed.map((log) {
                  final index = logs.indexOf(log);
                  String? diff;

                  if (index > 0) {
                    final intervalMs = log["interval_ms"] as int;
                    final diffMin = (intervalMs / 1000 / 60).round();
                    diff = "$diffMin分";
                  }

                  return LogItem(
                    time: log["time"],
                    count: log["count"],
                    latest: log == logs.last,
                    diff: diff,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    elevation: 0,
                  ),
                  onPressed: () {},
                  child: const Text(
                    "修正する",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4A261),
                    foregroundColor: Colors.black,
                    elevation: 0,
                  ),
                  onPressed: _sendLogs,
                  child: const Text(
                    "📤 データを送る",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}