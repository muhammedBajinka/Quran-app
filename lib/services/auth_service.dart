import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase;

  AuthService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  static const String googleRedirect = 'com.bajinka.quran://login-callback';

  SupabaseClient get supabase => _supabase;

  User? get currentUser => _supabase.auth.currentUser;

  bool get isAnonymous => currentUser?.isAnonymous ?? false;

  Future<void> ensureGuestSession() async {
    if (_supabase.auth.currentSession == null) {
      await _supabase.auth.signInAnonymously();
    }
  }

  Future<bool> continueWithGoogle() async {
    // Use normal OAuth sign-in rather than linking the Google identity to the
    // temporary anonymous user. This lets an existing Google identity recover
    // its original Quran Life account.
    return _supabase.auth
        .signInWithOAuth(
          OAuthProvider.google,
          redirectTo: googleRedirect,
          authScreenLaunchMode: LaunchMode.externalApplication,
        )
        .timeout(const Duration(seconds: 15));
  }
}
