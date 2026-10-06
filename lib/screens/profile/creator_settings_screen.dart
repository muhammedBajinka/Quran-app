import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class CreatorSettingsScreen extends StatefulWidget {
  const CreatorSettingsScreen({super.key});

  @override
  State<CreatorSettingsScreen> createState() => _CreatorSettingsScreenState();
}

class _CreatorSettingsScreenState extends State<CreatorSettingsScreen> {
  final AuthService _authService = AuthService();
  bool _loggingOut = false;

  Future<void> _logOut() async {
    if (_loggingOut) return;

    final shouldLogOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will be signed out of your Quran Life account on this device. '
          'You can sign in again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (shouldLogOut != true || !mounted) return;

    setState(() => _loggingOut = true);

    try {
      await _authService.supabase.auth.signOut();
      await _authService.ensureGuestSession();

      if (!mounted) return;

      // Leave creator-only screens after the account session has ended.
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are now logged out.')),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _loggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not log out right now. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final hasAccount = user != null && !user.isAnonymous;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Creator Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SettingsGroup(
            title: 'Account',
            children: [
              _SettingsItem(
                icon: Icons.manage_accounts_outlined,
                title: 'Account & security',
                subtitle: 'Sign-in and account information',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.lock_outline,
                title: 'Privacy',
                subtitle: 'Control what other people can see',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsGroup(
            title: 'Content',
            children: [
              _SettingsItem(
                icon: Icons.video_library_outlined,
                title: 'Manage content',
                subtitle: 'Manage your uploaded posts',
                onTap: () {},
              ),
            ],
          ),
          if (hasAccount) ...[
            const SizedBox(height: 20),
            _SettingsGroup(
              title: 'Account actions',
              children: [
                _SettingsItem(
                  icon: Icons.logout,
                  title: _loggingOut ? 'Logging out...' : 'Log out',
                  subtitle: 'Sign out of this account on this device',
                  enabled: !_loggingOut,
                  showChevron: false,
                  onTap: _logOut,
                ),
                _SettingsItem(
                  icon: Icons.delete_outline,
                  title: 'Delete account',
                  subtitle: 'Request permanent account deletion',
                  destructive: true,
                  onTap: () {},
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool destructive;
  final bool enabled;
  final bool showChevron;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
    this.enabled = true,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = destructive ? Colors.red.shade700 : null;
    final color = enabled ? baseColor : Colors.black38;

    return ListTile(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: showChevron ? const Icon(Icons.chevron_right) : null,
    );
  }
}
