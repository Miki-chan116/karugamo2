import 'package:flutter/material.dart';
import '../services/gas_api_service.dart';

class EditScreen extends StatefulWidget {
  final List<Map<String, dynamic>> logs;
  final bool is12h;

  const EditScreen({
    super.key,
    required this.logs,
    required this.is12h,
  });

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late List<Map<String, dynamic>> logs;
  late bool is12h;

  final TextEditingController _timeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    logs = List.from(widget.logs); // コピー
    is12h = widget.is12h;
  }

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

  // ✅ 時刻追加（先頭に追加＝最新が上）
  void _addManualTime() {
    final text = _timeController.text;

    if (!RegExp(r'^\d{1,2}:\d{2}$').hasMatch(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('時刻は 10:30 の形式で入力してください')),
      );
      return;
    }

    final now = DateTime.now();

    setState(() {
      logs.insert(0, {
        "time": text,
        "count": logs.length + 1,
        "received_at": now,
        "interval_ms": 0,
        "device_id": "manual-edit",
        "source": "manual",
      });
      _timeController.clear();
    });
  }

void _delete(int index) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("削除の確認"),
      content: const Text("このログを削除しますか？"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("キャンセル"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            "削除する",
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    setState(() {
      logs.removeAt(index);
    });
  }
}

  Future<void> _sendLogs() async {
    if (logs.isEmpty) return;

    int successCount = 0;

    for (final log in logs) {
      final success = await GasApiService.sendLog(
        deviceId: log["device_id"],
        pressCount: log["count"],
        intervalMs: log["interval_ms"],
        source: log["source"],
      );

      if (success) successCount++;
    }

    if (!mounted) return;

    Navigator.pop(context, logs);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFF0b5a35),

      // ===== ヘッダー（完全再現）=====
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Row(
          children: [
            Expanded(
              child: Text('🦆 ${_formatDate(today)}'),
            ),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  is12h = !is12h;
                });
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFE0E0E0),
              ),
              child: Text(is12h ? "24H" : "12H"),
            ),
          ],
        ),
      ),

// ===== メイン =====
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 追加ボタン＋入力欄（横並び）
            Row(
              children: [
                ElevatedButton(
                  onPressed: _addManualTime,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4DFF9E),
                  ),
                  child: const Text(
                    "➕ 追加する",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // 入力欄
                Expanded(
                  child: TextField(
                    controller: _timeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: "10:30",
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 一覧
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  // 修正1: 新→古の順に表示
                  final reversedIndex = logs.length - 1 - index;
                  final log = logs[reversedIndex];

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.white30),
                      ),
                    ),
                    child: Row(
                      children: [
                        // 削除ボタン
                        ElevatedButton(
                          onPressed: () => _delete(reversedIndex),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text(
                            "🗑️削除する",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // 時刻
                        Expanded(
                          child: Text(
                            log["time"] ??
                                _formatTime(log["received_at"]),
                            style: const TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        // 回数（元の順番で表示）
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white30),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            "${reversedIndex + 1}",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

// ===== フッター =====
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
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    elevation: 0,
                  ),
                  child: const Text(
                    "◀️ もどる",
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
                  onPressed: _sendLogs,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4A261),
                    foregroundColor: Colors.black,
                    elevation: 0,
                  ),
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