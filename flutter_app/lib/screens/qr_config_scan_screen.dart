import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/app_config_service.dart';

class QrConfigScanScreen extends StatefulWidget {
  const QrConfigScanScreen({super.key});

  @override
  State<QrConfigScanScreen> createState() => _QrConfigScanScreenState();
}

class _QrConfigScanScreenState extends State<QrConfigScanScreen> {
  final MobileScannerController _controller = MobileScannerController();

  bool _isProcessing = false;
  bool _isDialogShowing = false;

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isProcessing || _isDialogShowing) {
      return;
    }

    final barcode = capture.barcodes.firstOrNull;
    final value = barcode?.rawValue;

    if (value == null || value.isEmpty) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await _controller.stop();

      await AppConfigService.saveConfigFromQr(value);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました。')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _isDialogShowing = true;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('QR読み取りエラー'),
            content: Text(
              '設定用QRコードではない可能性があります。\n\n'
              'PCのスプレッドシート設定ツールで生成したQRコードを読み取ってください。\n\n'
              '詳細: $e',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('もう一度読み取る'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      _isDialogShowing = false;

      setState(() {
        _isProcessing = false;
      });

      await _controller.start();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定QR読み取り'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: Text(
                _isProcessing
                    ? '設定を確認しています...'
                    : 'PC管理ツールで生成したQRコードを読み取ってください',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}