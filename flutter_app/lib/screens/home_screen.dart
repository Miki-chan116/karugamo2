import 'package:flutter/material.dart';
import '../widgets/log_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> logs = [
    {"time": "03:12", "count": 1}, 
    {"time": "04:13", "count": 2},
    {"time": "05:14", "count": 3},
  ];
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0b5a35),

      // ===== ヘッダー =====
      appBar: AppBar(
        title: const Text('🦆 カルガモカウンター2'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),

      // ===== メイン =====
      body: Column(
        children: [

          // ===== ログ一覧 =====
          Expanded(
            child: ListView(
              children: logs.reversed.toList().map((log) {
                final index = logs.indexOf(log);
                String? diff;
                if (index > 0) {
                  final prev = logs[index - 1];
                  // 時刻を分に変換
                final prevParts = (prev["time"] as String).split(":");
                final currParts = (log["time"] as String).split(":");
                final prevMin = int.parse(prevParts[0]) * 60 + int.parse(prevParts[1]);
                final currMin = int.parse(currParts[0]) * 60 + int.parse(currParts[1]);
                diff = "${currMin - prevMin}分";
                }
                return LogItem(
                  time: log["time"],
                  count: log["count"],
                  latest: log == logs.last,
                  diff: diff,
                );
              }).toList(),
/*               children: logs.reversed.toList().asMap().entries.map((entry) {
                final log = entry.value;
                return LogItem(
                  time: log["time"],
                  count: log["count"],
                  latest: log == logs.last,
                );
              }).toList(), */
            ), 
          ),

          // ===== フッター =====
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton(
                  onPressed: () {
                    final now = TimeOfDay.now();

                    final timeText = 
                        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

                    setState(() {
                      logs.add({
                        "time": timeText,
                        "count": logs.length + 1,
                      });
                    });
                  },
                  child: const Text("➕ 打刻する"),
                ),
              ),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text("修正する"),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text("📤 送信"),
                    ),
                  ),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }
}