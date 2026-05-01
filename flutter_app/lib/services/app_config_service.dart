import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppConfigService {
  static const String _facilityNameKey = 'facility_name';
  static const String _gasWebAppUrlKey = 'gas_web_app_url';

  static Future<String?> getFacilityName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_facilityNameKey);
  }

  static Future<String?> getGasWebAppUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_gasWebAppUrlKey);
  }

  static Future<void> saveConfig({
    required String facilityName,
    required String gasWebAppUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_facilityNameKey, facilityName);
    await prefs.setString(_gasWebAppUrlKey, gasWebAppUrl);
  }

  static Future<void> saveConfigFromQr(String qrText) async {
    final decoded = jsonDecode(qrText);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('QRコードの形式が正しくありません。');
    }

    final facilityName = decoded['facility_name']?.toString().trim();
    final gasWebAppUrl = decoded['gas_web_app_url']?.toString().trim();

    if (facilityName == null || facilityName.isEmpty) {
      throw Exception('会社名がQRコードに含まれていません。');
    }

    if (gasWebAppUrl == null || gasWebAppUrl.isEmpty) {
      throw Exception('GAS WebアプリURLがQRコードに含まれていません。');
    }

    if (!gasWebAppUrl.contains('script.google.com/macros/s/') ||
        !gasWebAppUrl.endsWith('/exec')) {
      throw Exception('GAS WebアプリURLの形式が正しくありません。');
    }

    await saveConfig(
      facilityName: facilityName,
      gasWebAppUrl: gasWebAppUrl,
    );
  }

  static Future<bool> isConfigured() async {
    final gasUrl = await getGasWebAppUrl();
    return gasUrl != null && gasUrl.isNotEmpty;
  }
}