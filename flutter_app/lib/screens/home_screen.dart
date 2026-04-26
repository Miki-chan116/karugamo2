import 'package:flutter/material.dart';
import '../widgets/log_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> logs = [];

  void _addLog() {
    final now = TimeOfDay.now();
    final timeText =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    setState(() {
      logs.add({
        "time": timeText,
        "count": logs.length + 1,
      });
    });
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

            const SizedBox(height: 20),

            Expanded(
              child: ListView(
                children: logs.reversed.map((log) {
                  final index = logs.indexOf(log);
                  String? diff;

                  if (index > 0) {
                    final prev = logs[index - 1];
                    final prevParts = (prev["time"] as String).split(":");
                    final currParts = (log["time"] as String).split(":");

                    final prevMin =
                        int.parse(prevParts[0]) * 60 +
                        int.parse(prevParts[1]);
                    final currMin =
                        int.parse(currParts[0]) * 60 +
                        int.parse(currParts[1]);

                    diff = "${currMin - prevMin}分";
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
                height: 56, // ← 打刻ボタンと同じ高さ
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,            // 文字色は黒で読みやすく
                    elevation: 0,
                  ),
                  onPressed: () {},
                  child: const Text(
                    "修正",
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
                height: 56, // ← 打刻ボタンと同じ高さ
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4A261), // ← 落ち着いたオレンジ
                    foregroundColor: Colors.black,            // 文字色は黒で読みやすく
                    elevation: 0,
                  ),
                  onPressed: () {},
                  child: const Text(
                    "📤 送る",
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