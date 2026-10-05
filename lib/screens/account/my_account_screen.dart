import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/media_social_repository.dart';
import '../../services/auth_service.dart';
import '../profile/creator_profile_screen.dart';

class MyAccountScreen extends StatefulWidget {
  const MyAccountScreen({super.key});

  @override
  State<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  final AuthService _authService = AuthService();
  final MediaSocialRepository _socialRepository = MediaSocialRepository();

  StreamSubscription<AuthState>? _authSubscription;
  bool _googleLoading = false;
  bool _profileReady = false;
  Object? _profileError;

  bool get _hasAccount {
    final user = _authService.currentUser;
    return user != null && !user.isAnonymous;
  }

  @override
  void initState() {
    super.initState();

    if (_hasAccount) {
      _prepareProfile();
    }

    _authSubscription = _authService.supabase.auth.onAuthStateChange.listen((
      data,
    ) {
      if (!mounted) return;

      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.userUpdated) {
        setState(() {
          _googleLoading = false;
          _profileReady = false;
          _profileError = null;
        });

        _prepareProfile();
      } else if (data.event == AuthChangeEvent.tokenRefreshed) {
        setState(() {
          _googleLoading = false;
        });
      }
    });
  }

  Future<void> _prepareProfile() async {
    final user = _authService.currentUser;

    if (user == null || user.isAnonymous) {
      return;
    }

    try {
      await _socialRepository.ensureCurrentUserProfile();

      if (!mounted) return;

      setState(() {
        _profileReady = true;
        _profileError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _profileReady = false;
        _profileError = error;
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _continueWithGoogle() async {
    if (_googleLoading) return;

    setState(() {
      _googleLoading = true;
    });

    try {
      final launched = await _authService.continueWithGoogle();

      if (!launched) {
        await _authService.ensureGuestSession();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start Google sign-in.')),
        );
      }
    } catch (error) {
      try {
        await _authService.ensureGuestSession();
      } catch (_) {
        // Startup will retry anonymous authentication on the next app launch.
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-in failed: $error'),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _googleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (_hasAccount && user != null) {
      if (_profileError != null) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('My Account'),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 48,
                    color: Colors.black45,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Could not prepare your profile.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _profileError = null;
                      });
                      _prepareProfile();
                    },
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      if (!_profileReady) {
        return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(child: CircularProgressIndicator()),
        );
      }

      return CreatorProfileScreen(creatorId: user.id);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Account'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 30),
            const Center(
              child: CircleAvatar(
                radius: 42,
                backgroundColor: Color(0xFFE7F1EC),
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 46,
                  color: Color(0xFF2E7D5B),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Your Quran Life account',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Sign in to create your profile and keep account-backed data connected across your devices.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _googleLoading ? null : _continueWithGoogle,
              icon: _googleLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.account_circle_outlined),
              label: Text(
                _googleLoading ? 'Connecting...' : 'Continue with Google',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You can continue using Quran Life as a guest without signing in.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
