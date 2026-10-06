import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/media_social_repository.dart';
import '../../services/auth_service.dart';

class CreatorSettingsScreen extends StatefulWidget {
  const CreatorSettingsScreen({super.key});

  @override
  State<CreatorSettingsScreen> createState() => _CreatorSettingsScreenState();
}

class _CreatorSettingsScreenState extends State<CreatorSettingsScreen> {
  final AuthService _authService = AuthService();
  final MediaSocialRepository _socialRepository = MediaSocialRepository();
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

  void _openAccountSecurity() {
    final user = _authService.currentUser;
    if (user == null || user.isAnonymous) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AccountSecurityScreen(user: user),
      ),
    );
  }

  void _openPrivacy() {
    final user = _authService.currentUser;
    if (user == null || user.isAnonymous) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CreatorPrivacyScreen(repository: _socialRepository),
      ),
    );
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
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _SettingsSection(
            title: 'Account',
            children: [
              _SettingsItem(
                icon: Icons.manage_accounts_outlined,
                title: 'Account & security',
                subtitle: 'Sign-in and account information',
                enabled: hasAccount,
                onTap: _openAccountSecurity,
              ),
              _SettingsItem(
                icon: Icons.lock_outline,
                title: 'Privacy',
                subtitle: 'Likes, reposts, downloads and comments',
                enabled: hasAccount,
                onTap: _openPrivacy,
              ),
            ],
          ),
          _SettingsSection(
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
          if (hasAccount)
            _SettingsSection(
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
      ),
    );
  }
}

class _CreatorPrivacyScreen extends StatefulWidget {
  final MediaSocialRepository repository;
  const _CreatorPrivacyScreen({required this.repository});

  @override
  State<_CreatorPrivacyScreen> createState() => _CreatorPrivacyScreenState();
}

class _CreatorPrivacyScreenState extends State<_CreatorPrivacyScreen> {
  CreatorPrivacySettings? _settings;
  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final value = await widget.repository.getOwnCreatorPrivacySettings();
      if (!mounted) return;
      setState(() {
        _settings = value;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _save(CreatorPrivacySettings next) async {
    if (_saving) return;
    final previous = _settings;
    setState(() {
      _settings = next;
      _saving = true;
    });
    try {
      await widget.repository.setOwnCreatorPrivacySettings(next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _settings = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that privacy setting. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseComments() async {
    final current = _settings;
    if (current == null || _saving) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Who can comment', style: TextStyle(fontWeight: FontWeight.w700))),
            RadioGroup<String>(
              groupValue: current.commentPermission,
              onChanged: (value) => Navigator.of(context).pop(value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in const [
                    ('everyone', 'Everyone'),
                    ('followers', 'Followers'),
                    ('no_one', 'No one'),
                  ])
                    RadioListTile<String>(
                      value: option.$1,
                      title: Text(option.$2),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null && selected != current.commentPermission) {
      await _save(current.copyWith(commentPermission: selected));
    }
  }

  String _commentLabel(String value) {
    if (value == 'followers') return 'Followers';
    if (value == 'no_one') return 'No one';
    return 'Everyone';
  }

  @override
  Widget build(BuildContext context) {
    final value = _settings;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Privacy', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed || value == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load privacy settings.'),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    const _SectionLabel('Profile activity'),
                    SwitchListTile(
                      secondary: const Icon(Icons.favorite_border, color: Color(0xFF2E7D5B)),
                      title: const Text('Liked posts', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Show your liked posts on your profile'),
                      value: value.showLikedPosts,
                      onChanged: _saving ? null : (enabled) => _save(value.copyWith(showLikedPosts: enabled)),
                    ),
                    const Divider(height: 1, indent: 64, endIndent: 16),
                    SwitchListTile(
                      secondary: const Icon(Icons.repeat_rounded, color: Color(0xFF2E7D5B)),
                      title: const Text('Reposts', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Show your reposts on your profile'),
                      value: value.showReposts,
                      onChanged: _saving ? null : (enabled) => _save(value.copyWith(showReposts: enabled)),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Text(
                        'Your following list stays private and cannot be viewed by other people.',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SectionLabel('Your content'),
                    SwitchListTile(
                      secondary: const Icon(Icons.download_outlined, color: Color(0xFF2E7D5B)),
                      title: const Text('Allow downloads', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Allow people to download your current and future posts'),
                      value: value.allowDownloads,
                      onChanged: _saving ? null : (enabled) => _save(value.copyWith(allowDownloads: enabled)),
                    ),
                    const Divider(height: 1, indent: 64, endIndent: 16),
                    ListTile(
                      enabled: !_saving,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                      leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF2E7D5B)),
                      title: const Text('Comments', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(_commentLabel(value.commentPermission)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _saving ? null : _chooseComments,
                    ),
                    if (_saving)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
    );
  }
}

class _AccountSecurityScreen extends StatelessWidget {
  final User user;

  const _AccountSecurityScreen({required this.user});

  String get _provider {
    final provider = user.appMetadata['provider']?.toString().trim();
    if (provider == null || provider.isEmpty) return 'Quran Life';
    if (provider.toLowerCase() == 'google') return 'Google';
    return provider[0].toUpperCase() + provider.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final email = user.email?.trim();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Account & security',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _SectionLabel('Sign-in'),
          _InfoRow(
            icon: Icons.alternate_email,
            title: 'Email',
            value: email == null || email.isEmpty ? 'Not available' : email,
          ),
          _InfoRow(
            icon: Icons.login_rounded,
            title: 'Sign-in method',
            value: _provider,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Text(
              'Your sign-in information is provided by your account provider. '
              'Quran Life will only show security controls here when they are '
              'actually supported.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(title),
          ...List.generate(children.length, (index) {
            return Column(
              children: [
                children[index],
                if (index != children.length - 1)
                  const Divider(height: 1, indent: 64, endIndent: 16),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
        ),
      ),
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
    final activeColor = destructive
        ? Colors.red.shade700
        : const Color(0xFF2E7D5B);
    final iconColor = enabled ? activeColor : Colors.black26;
    final titleColor = destructive && enabled ? activeColor : null;

    return ListTile(
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      minLeadingWidth: 28,
      onTap: enabled ? onTap : null,
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: showChevron
          ? Icon(Icons.chevron_right, color: enabled ? null : Colors.black26)
          : null,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      minLeadingWidth: 28,
      leading: const SizedBox.shrink(),
      title: Row(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF2E7D5B)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 38, top: 4),
        child: Text(value),
      ),
    );
  }
}
