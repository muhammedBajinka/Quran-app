import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../lib/services/error_report_service.dart';

void main() {
  test('reports stable codes without copying private error text', () {
    expect(ErrorReportService.technicalCode(const PostgrestException(message: 'secret token and private title', code: '42501')), '42501');
    expect(ErrorReportService.technicalCode(const PostgrestException(message: 'private', code: 'token=secret')), isNull);
    expect(ErrorReportService.technicalCode(StateError('Worker HTTP 503: private title and token')), 'HTTP_503');
    expect(ErrorReportService.technicalCode(StateError('https://private.example?token=secret')), isNull);
    expect(ErrorReportService.technicalCode(TimeoutException('private URL')), 'TIMEOUT');
  });

  test('a reporting setup failure does not escape into the app', () async {
    await expectLater(ErrorReportService.report('APP_CRASH', error: StateError('private')), completes);
  });
}
