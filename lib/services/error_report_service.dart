import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_info_service.dart';

/// Only codes and version metadata leave the device. Never send exception text,
/// URLs, tokens, file names, comments, or stack traces.
class ErrorReportService {
  static final Map<String, DateTime> _recent = {};
  static DateTime _window = DateTime.now();
  static int _count = 0;

  static String? technicalCode(Object error) {
    String? code;
    if (error is PostgrestException) code = error.code;
    if (error is StorageException) code = error.statusCode;
    if (error is AuthException) code = error.statusCode;
    if (error is TimeoutException) return 'TIMEOUT';
    if (code != null && RegExp(r'^[A-Za-z0-9_-]{1,40}$').hasMatch(code)) {
      return code;
    }
    final http = RegExp(r'Worker HTTP ([1-5][0-9]{2}):').firstMatch(error.toString());
    return http == null ? null : 'HTTP_${http.group(1)}';
  }

  static Future<void> report(String code, {Object? error, String source = 'quran_app'}) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) return;
      final now = DateTime.now();
      if (now.difference(_window) > const Duration(minutes: 10)) {
        _window = now;
        _count = 0;
        _recent.clear();
      }
      final technical = error == null ? null : technicalCode(error);
      final key = '$source/$code/$technical';
      final previous = _recent[key];
      if (_count >= 20 || (previous != null && now.difference(previous) < const Duration(minutes: 1))) return;
      _recent[key] = now;
      _count++;
      final info = await AppInfoService().load();
      await client.from('error_reports').insert({
        'source': source,
        'error_code': code,
        'technical_code': technical,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'app_version': info.version,
        'build_number': info.buildNumber,
      }).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Reporting must never fail an operation or recursively report itself.
    }
  }
}
