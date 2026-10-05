import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase;

  AuthService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  static const String googleRedirect = 'com.bajinka.quran://login-callback';

  SupabaseClient get supabase => _supabase;

  User? get currentUser => _supabase.auth.currentUser;

  bool get isAnonymous => currentUser?.isAnonymous ?? false;

  Future<bool> continueWithGoogle() async {
    return _supabase.auth
        .linkIdentity(
          OAuthProvider.google,
          redirectTo: googleRedirect,
          authScreenLaunchMode: LaunchMode.externalApplication,
        )
        .timeout(const Duration(seconds: 15));
  }
}
