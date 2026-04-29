import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/log_item.dart';
import '../services/gas_api_service.dart';
import '../services/ble_service.dart';
import 'edit_screen.dart';

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

  bool is12h = false;

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
    }

    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  late final BleService _bleService;
  late bool _isBleConnected;
  String _bleStatus = 'ATOM Lite未接続';
  StreamSubscription<AtomLog>? _atomLogSubscription;

  String _userName = '';
  String _phoneNumber = '';

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _userName = prefs.getString('user_name') ?? '';
      _phoneNumber = prefs.getString('phone_number') ?? '';
    });
  }

  @override
  void initState() {
    super.initState();

    _loadUserInfo();
    _bleService = widget.bleService;
    _isBleConnected = widget.isBleConnected;
    _bleStatus = _isBleConnected ? 'ATOM Lite接続中' : 'ATOM Lite未接続';

    _atomLogSubscription = _bleService.atomLogStream.listen((atomLog) {
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
        userName: _userName,
        phoneNumber: _phoneNumber,
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
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFF0b5a35),

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Row(
          children: [
            Expanded(
              child: Text(
                '🦆 ${_formatDate(today)}',
                textAlign: TextAlign.left,
              ),
            ),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  is12h = !is12h;
                });
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFE0E0E0),
                side: const BorderSide(color: Colors.grey),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
              child: Text(
                is12h ? "24H" : "12H",
                style: const TextStyle(
                  fontSize: 12,
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
                    time: _formatTime(log["received_at"] as DateTime),
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
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditScreen(
                          logs: logs,
                          is12h: is12h,
                        ),
                      ),
                    );

                    if (result != null) {
                      setState(() {
                        logs = List<Map<String, dynamic>>.from(result);
                      });
                    }
                  },
                  child: const Text(
                    "✏ 編集する",
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