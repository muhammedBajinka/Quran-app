import 'package:flutter/material.dart';

class CreatorSettingsScreen extends StatelessWidget {
  const CreatorSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            title: 'Profile',
            children: [
              _SettingsItem(
                icon: Icons.person_outline,
                title: 'Edit profile',
                subtitle: 'Name, username, photo and bio',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
          _SettingsGroup(
            title: 'Account actions',
            children: [
              _SettingsItem(icon: Icons.logout, title: 'Log out', onTap: () {}),
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
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.red.shade700 : null;

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
