import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ble_service.dart';
import 'home_screen.dart';
import 'app_config_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _atomNumberController = TextEditingController();

  final BleService _bleService = BleService();

  bool _isConnecting = false;
  bool _movedToHome = false;
  String _status = '🦆カウンター未接続';

  @override
  void initState() {
    super.initState();
    _loadSavedUserInfo();
  }

  Future<void> _loadSavedUserInfo() async {
    final prefs = await SharedPreferences.getInstance();

    final savedName = prefs.getString('user_name') ?? '';
    final savedPhone = prefs.getString('phone_number') ?? '';
    final savedAtomNumber = prefs.getString('atom_number') ?? '';

    if (!mounted) return;

    setState(() {
      _nameController.text = savedName;
      _phoneController.text = savedPhone;
      _atomNumberController.text = savedAtomNumber;
    });
  }

  Future<void> _saveUserInfo() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('user_name', _nameController.text.trim());
    await prefs.setString('phone_number', _phoneController.text.trim());
    await prefs.setString('atom_number', _atomNumberController.text.trim());
  }

  bool _validateInput() {
    final atomNumber = _atomNumberController.text.trim();

    if (atomNumber.isEmpty) {
      setState(() {
        _status = '🦆カウンター番号を入力してください';
      });
      return false;
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(atomNumber)) {
      setState(() {
        _status = '🦆カウンター番号は数字だけで入力してください';
      });
      return false;
    }

    return true;
  }

  Future<void> _startWithAtomLite() async {
    if (_isConnecting) return;

    if (!_validateInput()) return;

    await _saveUserInfo();

    final atomNumber = _atomNumberController.text.trim();

    setState(() {
      _isConnecting = true;
      _status = '🦆カウンター $atomNumber へ接続中...';
    });

    bool connected = false;

    try {
      connected = await _bleService.connect(
        atomNumber: atomNumber,
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
          _status = '🦆カウンター接続エラー: $e';
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
          title: const Text('🦆カウンター未接続'),
          content: const Text(
            '🦆カウンターに接続できません。スマホ画面から直接打刻しますか？',
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

  Future<void> _openAppConfigScreen() async {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('管理者用設定'),
          content: const Text(
            'この設定は配布時の初回設定用です。\n\n'
            '通常利用では変更しないでください。\n'
            '送信先スプレッドシートの設定を開きますか？',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('開く'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (open == true) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AppConfigScreen(),
        ),
      );
    }
  }  

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _atomNumberController.dispose();

    if (!_movedToHome) {
      _bleService.dispose();
    }

    super.dispose();
  }

  Widget _label(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0b5a35),
            appBar: AppBar(
              title: const Text('🦆 カウンター2 '),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              actions: [
                IconButton(
                  tooltip: '管理者用設定',
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  onPressed: _isConnecting ? null : _openAppConfigScreen,
                ),
              ],
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              '※ 名前・電話番号・🦆カウンター番号\n   を入力します。',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 30),

            _label('名前'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: _inputDecoration('例: 🦆田　いぐお'),
            ),

            const SizedBox(height: 20),

            _label('電話番号'),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration('09012345678'),
            ),

            const SizedBox(height: 20),

            _label('🦆カウンター番号'),
            const SizedBox(height: 8),
            TextField(
              controller: _atomNumberController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('例: 111'),
            ),

            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '※  🦆カウンターの番号を入力します。',
                style: TextStyle(color: Colors.white70, fontSize: 12),
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