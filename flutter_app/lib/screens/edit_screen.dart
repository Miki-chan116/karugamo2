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

  final TextEditingController _hourController = TextEditingController();
  final TextEditingController _minuteController = TextEditingController();

  bool _manualIsPm = false;

  @override
  void initState() {
    super.initState();
    logs = List<Map<String, dynamic>>.from(widget.logs);
    is12h = widget.is12h;

    final now = DateTime.now();
    _manualIsPm = now.hour >= 12;

    _normalizeLogs();
    _sortLogs();
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _normalizeLogs() {
    for (final log in logs) {
      final receivedAt = _toDateTime(log["received_at"]);

      if (receivedAt != null) {
        log["received_at"] = receivedAt;
      }

      // 12H/24H表示切替を効かせるため、表示用の固定文字列は使わない
      log.remove("time");
    }
  }

  String _formatDate(DateTime dt) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final weekday = weekdays[dt.weekday - 1];
    return '${dt.year}年${dt.month}月${dt.day}日($weekday)';
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  String _formatTime(dynamic value) {
    final dt = _toDateTime(value) ?? DateTime.now();

    if (is12h) {
      int hour = dt.hour % 12;
      if (hour == 0) hour = 12;
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return "$ampm ${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }

    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  int _timeSortValue(Map<String, dynamic> log) {
    final receivedAt = _toDateTime(log["received_at"]);
    if (receivedAt != null) {
      return receivedAt.hour * 60 + receivedAt.minute;
    }

    return 0;
  }

  void _sortLogs() {
    logs.sort((a, b) {
      final timeCompare = _timeSortValue(b).compareTo(_timeSortValue(a));
      if (timeCompare != 0) return timeCompare;

      final aCount = a["count"] as int? ?? 0;
      final bCount = b["count"] as int? ?? 0;

      return bCount.compareTo(aCount);
    });
  }

  int? _to24Hour(int inputHour) {
    if (!is12h) {
      if (inputHour < 0 || inputHour > 23) return null;
      return inputHour;
    }

    if (inputHour < 1 || inputHour > 12) return null;

    if (_manualIsPm) {
      return inputHour == 12 ? 12 : inputHour + 12;
    }

    return inputHour == 12 ? 0 : inputHour;
  }

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

    final inputHourValue = int.parse(hour);
    final minuteValue = int.parse(minute);

    final hourValue = _to24Hour(inputHourValue);

    if (hourValue == null || minuteValue > 59) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            is12h
                ? '12H表示では、時は 1〜12、分は 00〜59 で入力してください'
                : '24H表示では、時は 0〜23、分は 00〜59 で入力してください',
          ),
        ),
      );
      return;
    }

    final now = DateTime.now();

    final manualReceivedAt = DateTime(
      now.year,
      now.month,
      now.day,
      hourValue,
      minuteValue,
      0,
    );

    setState(() {
      logs.add({
        "count": logs.length + 1,
        "received_at": manualReceivedAt,
        "interval_ms": 0,
        "device_id": "manual-edit",
        "source": "manual",
      });

      _sortLogs();

      _hourController.clear();
      _minuteController.clear();
    });
  }

  void _delete(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
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
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        logs.removeAt(index);
      });
    }
  }

  void _saveLogs() {
    _normalizeLogs();
    _sortLogs();
    Navigator.pop(context, logs);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFF0b5a35),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Row(
          children: [
            Expanded(
              child: Text('🦆 ${_formatDate(today)}'),
            ),
            // OutlinedButton(
            //   onPressed: () {
            //     setState(() {
            //       is12h = !is12h;
            //     });
            //   },
            //   style: OutlinedButton.styleFrom(
            //     backgroundColor: const Color(0xFFE0E0E0),
            //   ),
            //   child: Text(is12h ? "24H" : "12H"),
            // ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _addManualTime,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4DFF9E),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      minimumSize: const Size(0, 48),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    child: TextField(
                      controller: _hourController,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: is12h ? '8' : '22',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 12,
                        ),
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
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: TextField(
                      controller: _minuteController,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: '05',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 12,
                        ),
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
                  if (is12h) ...[
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 50,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _manualIsPm = !_manualIsPm;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE0E0E0),
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _manualIsPm ? 'PM' : 'AM',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.white30),
                      ),
                    ),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => _delete(index),
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
                        Expanded(
                          child: Text(
                            _formatTime(log["received_at"]),
                            style: const TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white30),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            "${log["count"]}",
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