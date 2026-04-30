import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ble_service.dart';
import '../services/gas_api_service.dart';
import '../widgets/log_item.dart';
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
  static const String _pendingLogsKey = 'pending_logs';

  List<Map<String, dynamic>> logs = [];

  bool is12h = false;

  late final BleService _bleService;
  late bool _isBleConnected;
  String _bleStatus = '🦆カウンター 未接続';
  StreamSubscription<AtomLog>? _atomLogSubscription;

  String _userName = '';
  String _phoneNumber = '';

  @override
  void initState() {
    super.initState();

    _bleService = widget.bleService;
    _isBleConnected = widget.isBleConnected;
    _bleStatus = _isBleConnected ? '🦆カウンター 接続中' : '🦆カウンター 未接続';

    _initialize();
  }

  Future<void> _initialize() async {
    await _loadUserInfo();
    await _loadPendingLogs();

    _atomLogSubscription = _bleService.atomLogStream.listen((atomLog) {
      final now = DateTime.now();

      int intervalMs = 0;

      if (logs.isNotEmpty) {
        final previousTime = _latestReceivedAt();

        if (previousTime != null) {
          intervalMs = now.difference(previousTime).inMilliseconds;
        }
      }

      setState(() {
        logs.add({
          "count": _nextCount(),
          "received_at": now,
          "interval_ms": intervalMs,
          "device_id": atomLog.deviceId,
          "source": "atom",
        });

        _sortLogs();
      });

      unawaited(_savePendingLogs());
    });
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _userName = prefs.getString('user_name') ?? '';
      _phoneNumber = prefs.getString('phone_number') ?? '';
    });
  }

  Future<void> _loadPendingLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_pendingLogsKey);

    if (text == null || text.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(text);

      if (decoded is! List) {
        return;
      }

      final loadedLogs = decoded.map<Map<String, dynamic>>((item) {
        final map = Map<String, dynamic>.from(item as Map);

        final receivedAt = _toDateTime(map["received_at"]);
        if (receivedAt != null) {
          map["received_at"] = receivedAt;
        } else {
          map["received_at"] = DateTime.now();
        }

        map["count"] = int.tryParse(map["count"].toString()) ?? 0;
        map["interval_ms"] = int.tryParse(map["interval_ms"].toString()) ?? 0;
        map["device_id"] = map["device_id"]?.toString() ?? '';
        map["source"] = map["source"]?.toString() ?? 'manual';

        // 12H/24H切替を効かせるため、固定表示用のtimeは使わない
        map.remove("time");

        return map;
      }).toList();

      loadedLogs.sort((a, b) {
        final timeCompare = _timeSortValue(b).compareTo(_timeSortValue(a));
        if (timeCompare != 0) return timeCompare;

        final aCount = a["count"] as int? ?? 0;
        final bCount = b["count"] as int? ?? 0;

        return bCount.compareTo(aCount);
      });

      if (!mounted) return;

      setState(() {
        logs = loadedLogs;
      });
    } catch (e) {
      debugPrint('未送信ログの読み込みに失敗しました: $e');
    }
  }

  Future<void> _savePendingLogs() async {
    final prefs = await SharedPreferences.getInstance();

    final serializableLogs = logs.map((log) {
      final receivedAt = _toDateTime(log["received_at"]);

      return {
        "count": log["count"],
        "received_at": receivedAt?.toIso8601String() ??
            log["received_at"]?.toString() ??
            DateTime.now().toIso8601String(),
        "interval_ms": log["interval_ms"] ?? 0,
        "device_id": log["device_id"] ?? '',
        "source": log["source"] ?? 'manual',
      };
    }).toList();

    await prefs.setString(_pendingLogsKey, jsonEncode(serializableLogs));
  }

  Future<void> _clearPendingLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingLogsKey);
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

  DateTime? _latestReceivedAt() {
    DateTime? latest;

    for (final log in logs) {
      final receivedAt = _toDateTime(log["received_at"]);
      if (receivedAt == null) continue;

      if (latest == null || receivedAt.isAfter(latest)) {
        latest = receivedAt;
      }
    }

    return latest;
  }

  int _nextCount() {
    if (logs.isEmpty) {
      return 1;
    }

    int maxCount = 0;

    for (final log in logs) {
      final count = int.tryParse(log["count"].toString()) ?? 0;
      if (count > maxCount) {
        maxCount = count;
      }
    }

    return maxCount + 1;
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

  String _formatDate(DateTime dt) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final weekday = weekdays[dt.weekday - 1];
    return '${dt.year}年${dt.month}月${dt.day}日($weekday)';
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

  void _addLog() {
    final now = DateTime.now();

    int intervalMs = 0;

    if (logs.isNotEmpty) {
      final previousTime = _latestReceivedAt();

      if (previousTime != null) {
        intervalMs = now.difference(previousTime).inMilliseconds;
      }
    }

    setState(() {
      logs.add({
        "count": _nextCount(),
        "received_at": now,
        "interval_ms": intervalMs,
        "device_id": "manual-device",
        "source": "manual",
      });

      _sortLogs();
    });

    unawaited(_savePendingLogs());
  }

  Future<void> _sendLogs() async {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('送るデータがありません')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    int successCount = 0;

    for (final log in logs) {
      final success = await GasApiService.sendLog(
        deviceId: log["device_id"]?.toString() ?? '',
        pressCount: int.tryParse(log["count"].toString()) ?? 0,
        intervalMs: int.tryParse(log["interval_ms"].toString()) ?? 0,
        source: log["source"]?.toString() ?? 'manual',
        userName: _userName,
        phoneNumber: _phoneNumber,
        receivedAt: log["received_at"],
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

      await _clearPendingLogs();

      messenger.showSnackBar(
        SnackBar(content: Text('$sentCount件、送りました')),
      );
    } else {
      final failedCount = logs.length - successCount;

      await _savePendingLogs();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$successCount件、送りました。$failedCount件、失敗しました。未送信データは保持しています。',
          ),
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
                children: logs.map((log) {
                  final index = logs.indexOf(log);
                  String? diff;

                  if (index > 0) {
                    final intervalMs =
                        int.tryParse(log["interval_ms"].toString()) ?? 0;
                    final diffMin = (intervalMs / 1000 / 60).round();
                    diff = "$diffMin分";
                  }

                  return LogItem(
                    time: _formatTime(log["received_at"]),
                    count: int.tryParse(log["count"].toString()) ?? 0,
                    latest: index == 0,
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

                        for (final log in logs) {
                          final receivedAt = _toDateTime(log["received_at"]);
                          if (receivedAt != null) {
                            log["received_at"] = receivedAt;
                          }

                          log.remove("time");
                        }

                        _sortLogs();
                      });

                      await _savePendingLogs();
                    }
                  },
                  child: const Text(
                    "✏️ 編集する",
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