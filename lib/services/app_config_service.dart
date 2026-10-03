import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppRelease {
  final String version;
  final int buildNumber;
  final String releaseNotes;
  final String distributionType;
  final String downloadUrl;
  final bool isRequired;

  const AppRelease({
    required this.version,
    required this.buildNumber,
    required this.releaseNotes,
    required this.distributionType,
    required this.downloadUrl,
    required this.isRequired,
  });

  factory AppRelease.fromMap(Map<String, dynamic> map) {
    return AppRelease(
      version: map['version']?.toString() ?? '',
      buildNumber: (map['build_number'] as num?)?.toInt() ?? 0,
      releaseNotes: map['release_notes']?.toString() ?? '',
      distributionType: map['distribution_type']?.toString() ?? 'apk',
      downloadUrl: map['download_url']?.toString() ?? '',
      isRequired: map['is_required'] == true,
    );
  }
}

class AppConfig {
  final String shareMessage;
  final String privacyPolicyUrl;
  final AppRelease? currentRelease;

  const AppConfig({
    required this.shareMessage,
    required this.privacyPolicyUrl,
    required this.currentRelease,
  });
}

class AppConfigService {
  final SupabaseClient _supabase;

  AppConfigService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  Future<AppConfig> loadConfig() async {
    String shareMessage =
        'Download this Quran app for reading, memorization, Duas and beneficial Islamic audio.';
    String privacyPolicyUrl = '';
    AppRelease? currentRelease;

    try {
      final configRow = await _supabase
          .from('app_config')
          .select('share_message, privacy_policy_url')
          .eq('platform', 'android')
          .eq('is_active', true)
          .maybeSingle();

      if (configRow != null) {
        final configuredMessage = configRow['share_message']?.toString().trim();
        final configuredPrivacyUrl = configRow['privacy_policy_url']
            ?.toString()
            .trim();

        if (configuredMessage != null && configuredMessage.isNotEmpty) {
          shareMessage = configuredMessage;
        }

        if (configuredPrivacyUrl != null) {
          privacyPolicyUrl = configuredPrivacyUrl;
        }
      }
    } catch (error) {
      debugPrint('APP_CONFIG_ERROR: $error');
    }

    try {
      final releaseRow = await _supabase
          .from('app_releases')
          .select(
            'version, build_number, release_notes, '
            'distribution_type, download_url, is_required',
          )
          .eq('platform', 'android')
          .eq('is_current', true)
          .maybeSingle();

      if (releaseRow != null) {
        currentRelease = AppRelease.fromMap(releaseRow);
      }
    } catch (error) {
      debugPrint('APP_RELEASE_ERROR: $error');
    }

    return AppConfig(
      shareMessage: shareMessage,
      privacyPolicyUrl: privacyPolicyUrl,
      currentRelease: currentRelease,
    );
  }
}
