import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GasApiService {
  static const String gasUrl =
      'https://script.google.com/macros/s/AKfycbwBvYoSEjYuzMYPhqUYFtHNMi4XloOw3d3uKrzYKJBoqSAi36q_buROS_7nyJQu2vLZMg/exec';

  static Future<bool> sendLog({
    required String deviceId,
    required int pressCount,
    required int intervalMs,
    String source = 'manual',
    required String userName,
    required String phoneNumber,
    dynamic receivedAt,
  }) async {
    try {
      String? receivedAtText;

      if (receivedAt is DateTime) {
        receivedAtText = receivedAt.toIso8601String();
      } else if (receivedAt is String && receivedAt.trim().isNotEmpty) {
        receivedAtText = receivedAt.trim();
      }

      final Map<String, dynamic> requestBody = {
        'device_id': deviceId,
        'press_count': pressCount,
        'interval_ms': intervalMs,
        'source': source,
        'user_name': userName,
        'phone_number': phoneNumber,
      };

      if (receivedAtText != null) {
        requestBody['received_at'] = receivedAtText;
      }

      final body = jsonEncode(requestBody);

      debugPrint('GAS request body: $body');

      http.Response response = await http.post(
        Uri.parse(gasUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: body,
      );

      debugPrint('GAS first statusCode: ${response.statusCode}');
      debugPrint('GAS first response: ${response.body}');

      // GAS Webアプリは 302 リダイレクトを返すことがあるため対応
      if (response.statusCode == 301 ||
          response.statusCode == 302 ||
          response.statusCode == 303 ||
          response.statusCode == 307 ||
          response.statusCode == 308) {
        String? redirectUrl = response.headers['location'];

        // Locationヘッダーが取れない場合、HTML内の href から取得
        if (redirectUrl == null) {
          final match = RegExp(r'HREF="([^"]+)"').firstMatch(response.body);
          redirectUrl = match?.group(1)?.replaceAll('&amp;', '&');
        }

        if (redirectUrl == null) {
          debugPrint('GASリダイレクト先URLが取得できません');
          return false;
        }

        debugPrint('GAS redirectUrl: $redirectUrl');

        response = await http.get(Uri.parse(redirectUrl));

        debugPrint('GAS redirected statusCode: ${response.statusCode}');
        debugPrint('GAS redirected response: ${response.body}');
      }

      if (response.statusCode != 200) {
        return false;
      }

      final result = jsonDecode(response.body);
      return result['status'] == 'success';
    } catch (e) {
      debugPrint('GAS送信エラー: $e');
      return false;
    }
  }
}