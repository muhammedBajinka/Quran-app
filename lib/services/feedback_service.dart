import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'anonymous_install_service.dart';
import 'app_info_service.dart';

class FeedbackService {
  final SupabaseClient _supabase;
  final AnonymousInstallService _installService;
  final AppInfoService _appInfoService;

  FeedbackService({
    SupabaseClient? supabase,
    AnonymousInstallService? installService,
    AppInfoService? appInfoService,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _installService = installService ?? AnonymousInstallService(),
       _appInfoService = appInfoService ?? AppInfoService();

  String get _platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<List<Map<String, dynamic>>> history() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];
    final rows = await _supabase.from('feedback')
        .select('id,category,message,status,admin_reply,replied_at,created_at')
        .eq('auth_user_id', user.id)
        .order('created_at', ascending: false).limit(30);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> submit({
    required String category,
    required String message,
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty || trimmedMessage.length > 1000) {
      throw ArgumentError('Feedback must contain between 1 and 1000 characters.');
    }

    final installId = await _installService.getInstallId();
    final appInfo = await _appInfoService.load();

    await _supabase.from('feedback').insert({
      'anonymous_install_id': installId,
      'category': category,
      'message': trimmedMessage,
      'app_version': appInfo.version,
      'build_number': appInfo.buildNumber,
      'platform': _platform,
      'status': 'new',
    });
  }
}
