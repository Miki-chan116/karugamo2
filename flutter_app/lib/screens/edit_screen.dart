import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // 時刻入力用のコントローラー
  final TextEditingController _hourController = TextEditingController();
  final TextEditingController _minuteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    logs = List.from(widget.logs); // コピー
    is12h = widget.is12h;
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final weekday = weekdays[dt.weekday - 1];
    return '${dt.year}年${dt.month}月${dt.day}日($weekday)';
  }

  String _formatTime(dynamic value) {
    DateTime dt;

    if (value is DateTime) {
      dt = value;
    } else if (value is String) {
      dt = DateTime.tryParse(value) ?? DateTime.now();
    } else {
      dt = DateTime.now();
    }

    if (is12h) {
      int hour = dt.hour % 12;
      if (hour == 0) hour = 12;
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return "$ampm ${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } else {
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
  }

  // 時刻追加（数字だけ入力 → HH:mm に変換）
  void _addManualTime() {
    final hour = _hourController.text.trim();
    final minute = _minuteController.text.trim();

    if (!RegExp(r'^\d{1,2}$').hasMatch(hour) ||
        !RegExp(r'^\d{2}$').hasMatch(minute)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('時刻を正しく入力してください（例: 10 : 30）')),
      );
      return;
    }

    final hourValue = int.parse(hour);
    final minuteValue = int.parse(minute);

    if (hourValue > 23 || minuteValue > 59) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('時刻を正しく入力してください（例: 10 : 30）')),
      );
      return;
    }

    final text = '${hourValue.toString().padLeft(2, '0')}:${minuteValue.toString().padLeft(2, '0')}';
    final now = DateTime.now();

    setState(() {
      logs.add({
        "time": text,
        "count": logs.length + 1,
        "received_at": now,
        "interval_ms": 0,
        "device_id": "manual-edit",
        "source": "manual",
      });

      _hourController.clear();
      _minuteController.clear();
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

  void _saveLogs() {
    for (int i = 0; i < logs.length; i++) {
      logs[i]["count"] = i + 1;
    }

    Navigator.pop(context, logs);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFF0b5a35),

      // ===== ヘッダー =====
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

                // 時
                SizedBox(
                  width: 48,
                  child: TextField(
                    controller: _hourController,
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: '10',
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                // 分
                SizedBox(
                  width: 48,
                  child: TextField(
                    controller: _minuteController,
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: '30',
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) {
                      if (value.length == 2) {
                        FocusScope.of(context).unfocus();
                      }
                    },
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
                  // 新→古の順に表示
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
                            log["time"] ?? _formatTime(log["received_at"]),
                            style: const TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        // 回数
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
                  onPressed: _saveLogs,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4A261),
                    foregroundColor: Colors.black,
                    elevation: 0,
                  ),
                  child: const Text(
                    "💾 保存する",
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