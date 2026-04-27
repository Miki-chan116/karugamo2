import 'dart:convert';
import 'package:http/http.dart' as http;

class GasApiService {
  static const String gasUrl =
      'https://script.google.com/macros/s/ここにGASのURL/exec';

  static Future<bool> sendLog({
    required String deviceId,
    required int pressCount,
    required int intervalMs,
    String source = 'manual',
  }) async {
    final response = await http.post(
      Uri.parse(gasUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'device_id': deviceId,
        'press_count': pressCount,
        'interval_ms': intervalMs,
        'source': source,
      }),
    );

    if (response.statusCode != 200) {
      return false;
    }

    final result = jsonDecode(response.body);
    return result['status'] == 'success';
  }
}
