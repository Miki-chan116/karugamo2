import 'package:flutter/material.dart';
import 'ble/ble_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: BleTestPage());
  }
}

class BleTestPage extends StatefulWidget {
  @override
  State<BleTestPage> createState() => _BleTestPageState();
}

class _BleTestPageState extends State<BleTestPage> {
  final ble = KarugamoBleService();

  String receivedText = "未接続";

  @override
  void initState() {
    super.initState();

    ble.stream.listen((data) {
      setState(() {
        receivedText = data;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("カルガモBLEテスト")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(receivedText, style: TextStyle(fontSize: 20)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await ble.scanAndConnect();
              },
              child: Text("接続"),
            ),
          ],
        ),
      ),
    );
  }
}
