import 'package:flutter/material.dart';
import '../widgets/log_item.dart';
import '../services/gas_api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> logs = [];

  String _formatDate(DateTime dt) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final weekday = weekdays[dt.weekday - 1];
    return '${dt.year}年${dt.month}月${dt.day}日($weekday)';
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
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFF0b5a35),

      appBar: AppBar(
        title: Text('🦆 ${_formatDate(today)}'),
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
        padding: const EdgeInsets.only(
          left: 8,
          right: 8,
          top: 8,
          bottom: 46, // 約1cm（38px）＋元の8px
        ),
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
                    "✍️修正する",
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