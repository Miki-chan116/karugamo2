import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ble_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final BleService _bleService = BleService();

  bool _isConnecting = false;
  bool _movedToHome = false;
  String _status = 'ATOM Lite未接続';

  @override
  void initState() {
    super.initState();
    _loadSavedUserName();
  }

  Future<void> _loadSavedUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('user_name') ?? '';

    if (!mounted) return;

    setState(() {
      _nameController.text = savedName;
    });
  }

  Future<void> _saveUserName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text);
  }

  Future<void> _startWithAtomLite() async {
    if (_isConnecting) return;

    await _saveUserName();

    setState(() {
      _isConnecting = true;
      _status = 'ATOM Liteへ接続中...';
    });

    bool connected = false;

    try {
      connected = await _bleService.connect(
        onStatusChanged: (message) {
          if (!mounted) return;
          setState(() {
            _status = message;
          });
        },
      );
    } catch (e) {
      connected = false;
      if (mounted) {
        setState(() {
          _status = 'ATOM Lite接続エラー: $e';
        });
      }
    }

    if (!mounted) return;

    setState(() {
      _isConnecting = false;
    });

    if (connected) {
      _goHome(isBleConnected: true);
    } else {
      await _showDirectInputDialog();
    }
  }

  Future<void> _showDirectInputDialog() async {
    final useManual = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('ATOM Lite未接続'),
          content: const Text(
            'AtomLiteに接続できません。スマホ画面から直接打刻しますか？',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('いいえ'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('はい'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (useManual == true) {
      _goHome(isBleConnected: false);
    } else {
      await _startWithAtomLite();
    }
  }

  void _goHome({required bool isBleConnected}) {
    _movedToHome = true;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) {
          return HomeScreen(
            bleService: _bleService,
            isBleConnected: isBleConnected,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();

    if (!_movedToHome) {
      _bleService.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0b5a35),
      appBar: AppBar(
        title: const Text('🦆 カウンター2 登録'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              '※ 入力は、はじめて利用する時だけです。',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 30),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '名前',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: '例: 🦆田　いぐお',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '電話番号',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '09012345678',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _status,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 92,
        ),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isConnecting ? Colors.grey : const Color.fromARGB(255, 237, 92, 3),
              foregroundColor: Colors.white,
            ),
            onPressed: _isConnecting ? null : _startWithAtomLite,
            child: Text(
              _isConnecting ? '接続中...' : '👆 利用を始める',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}