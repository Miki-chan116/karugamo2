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

  bool is12h = false; // ★ 追加（12時間表示フラグ）

  String _formatDate(DateTime dt) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final weekday = weekdays[dt.weekday - 1];
    return '${dt.year}年${dt.month}月${dt.day}日($weekday)';
  }

  String _formatTime(DateTime now) {
    if (is12h) {
      int hour = now.hour % 12;
      if (hour == 0) hour = 12;
      final ampm = now.hour < 12 ? 'AM' : 'PM';

      return "$ampm ${hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    } else {
      return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    }
  }

  void _addLog() {
    final now = DateTime.now();

    final timeText = _formatTime(now); // ★ 変更

    int intervalMs = 0;

    if (logs.isNotEmpty) {
      final previousTime = logs.last["received_at"] as DateTime;
      intervalMs = now.difference(previousTime).inMilliseconds;
    }

    setState(() {
      logs.add({
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
        const SnackBar(content: Text('送るデータがありません')),
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
        SnackBar(content: Text('$sentCount件、送りました')),
      );
    } else {
      final failedCount = logs.length - successCount;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount件、送りました。$failedCount件、失敗しました。'),
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
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,

        // ★ タイトルをRowに変更（左寄せ＋右ボタン）
        title: Row(
          children: [
            Expanded(
              child: Text(
                '🦆 ${_formatDate(today)}',
                textAlign: TextAlign.left,
              ),
            ),

            // ★ 12Hボタン
            OutlinedButton(
              onPressed: () {
                setState(() {
                  is12h = !is12h;
                });
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFE0E0E0), // 薄グレー
                side: const BorderSide(color: Colors.grey), // 濃グレー枠
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: Text(
                is12h ? "24H" : "12H",
                style: TextStyle(
                  fontSize: 12, // 日付より小さく
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
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
                child: const Text("➕ 打刻する"),
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
                    time: _formatTime(log["received_at"]),
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
          bottom: 46,
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
                    "📤 送信する",
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