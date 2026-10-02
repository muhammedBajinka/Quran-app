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

  Future<void> submit({
    required String category,
    required String message,
  }) async {
    final trimmedMessage = message.trim();

    if (trimmedMessage.isEmpty || trimmedMessage.length > 1000) {
      throw ArgumentError(
        'Feedback must contain between 1 and 1000 characters.',
      );
    }

    final installId = await _installService.getInstallId();
    final appInfo = await _appInfoService.load();

    await _supabase.from('feedback').insert({
      'anonymous_install_id': installId,
      'category': category,
      'message': trimmedMessage,
      'app_version': appInfo.version,
      'build_number': appInfo.buildNumber,
      'platform': 'android',
      'status': 'new',
    });
  }
}
