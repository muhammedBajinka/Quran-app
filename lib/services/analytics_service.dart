import 'package:supabase_flutter/supabase_flutter.dart';

import 'anonymous_install_service.dart';
import 'app_info_service.dart';

class AnalyticsService {
  final SupabaseClient _supabase;
  final AnonymousInstallService _installService;
  final AppInfoService _appInfoService;

  AnalyticsService({
    SupabaseClient? supabase,
    AnonymousInstallService? installService,
    AppInfoService? appInfoService,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _installService = installService ?? AnonymousInstallService(),
       _appInfoService = appInfoService ?? AppInfoService();

  Future<void> track(String eventName) async {
    final normalizedName = eventName.trim();

    if (normalizedName.isEmpty || normalizedName.length > 80) {
      return;
    }

    try {
      final installId = await _installService.getInstallId();
      final appInfo = await _appInfoService.load();

      await _supabase.from('analytics_events').insert({
        'anonymous_install_id': installId,
        'event_name': normalizedName,
        'app_version': appInfo.version,
        'build_number': appInfo.buildNumber,
        'platform': 'android',
      });
    } catch (_) {
      // Analytics must never interfere with normal app use.
    }
  }
}
