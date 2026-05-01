import 'package:flutter/material.dart';

import '../services/app_config_service.dart';
import '../services/gas_api_service.dart';
import 'qr_config_scan_screen.dart';

class AppConfigScreen extends StatefulWidget {
  const AppConfigScreen({super.key});

  @override
  State<AppConfigScreen> createState() => _AppConfigScreenState();
}

class _AppConfigScreenState extends State<AppConfigScreen> {
  String? _facilityName;
  String? _gasUrl;

  bool _isSendingTest = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final facilityName = await AppConfigService.getFacilityName();
    final gasUrl = await AppConfigService.getGasWebAppUrl();

    if (!mounted) return;

    setState(() {
      _facilityName = facilityName;
      _gasUrl = gasUrl;
    });
  }

  Future<void> _openQrScan() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const QrConfigScanScreen(),
      ),
    );

    if (result == true) {
      await _loadConfig();
    }
  }

  Future<void> _sendTestLog() async {
    if (_isSendingTest) return;

    final gasUrl = await AppConfigService.getGasWebAppUrl();

    if (gasUrl == null || gasUrl.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('送信先が未設定です。QRコードを読み取ってください。'),
        ),
      );
      return;
    }

    setState(() {
      _isSendingTest = true;
    });

    try {
      final success = await GasApiService.sendLog(
        deviceId: 'app-test',
        pressCount: 1,
        intervalMs: 0,
        source: 'test',
        userName: 'テスト送信',
        phoneNumber: '00000000000',
        receivedAt: DateTime.now(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'テスト送信に成功しました。スプレッドシートを確認してください。'
                : 'テスト送信に失敗しました。GAS URLやデプロイ設定を確認してください。',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('テスト送信エラー: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingTest = false;
        });
      }
    }
  }

  bool get _isConfigured => _gasUrl != null && _gasUrl!.isNotEmpty;

  String _maskedGasUrl() {
    final gasUrl = _gasUrl;

    if (gasUrl == null || gasUrl.isEmpty) {
      return '未設定';
    }

    if (gasUrl.length <= 36) {
      return gasUrl;
    }

    return '${gasUrl.substring(0, 32)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('送信先設定'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                title: const Text('会社名'),
                subtitle: Text(
                  _facilityName?.isNotEmpty == true ? _facilityName! : '未設定',
                ),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('送信先'),
                subtitle: Text(_isConfigured ? '設定済み' : '未設定'),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('GAS WebアプリURL'),
                subtitle: Text(_maskedGasUrl()),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSendingTest ? null : _openQrScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('QRコードを読み取る'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed:
                  (!_isConfigured || _isSendingTest) ? null : _sendTestLog,
              icon: const Icon(Icons.send),
              label: Text(_isSendingTest ? 'テスト送信中...' : 'テスト送信'),
            ),
            const SizedBox(height: 12),
            const Text(
              '※ テスト送信を押すと、スプレッドシートに確認用データが1件追加されます。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}