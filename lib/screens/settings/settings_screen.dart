import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const _SectionTitle('Quran'),

        _SettingsTile(
          icon: Icons.format_size,
          title: 'Arabic Text Size',
          subtitle: 'Choose the size of the Quran text',
          onTap: () {
            // Will be connected to the Quran reader.
          },
        ),

        _SettingsTile(
          icon: Icons.translate_outlined,
          title: 'Translation',
          subtitle: 'Choose your Quran translation',
          onTap: () {
            // Will be connected to translation settings.
          },
        ),

        _SettingsTile(
          icon: Icons.mic_none,
          title: 'Reciters',
          subtitle: 'Choose which reciters are available',
          onTap: () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const _RecitersPage()));
          },
        ),

        const SizedBox(height: 20),
        const _SectionTitle('App'),

        _SettingsTile(
          icon: Icons.share_outlined,
          title: 'Share App',
          subtitle: 'Share the Quran app with others',
          onTap: () {
            // Will use the URL supplied by the admin.
          },
        ),

        _SettingsTile(
          icon: Icons.feedback_outlined,
          title: 'Feedback',
          subtitle: 'Send feedback about the app',
          onTap: () {
            // Will be connected to the feedback system.
          },
        ),

        const SizedBox(height: 20),
        const _SectionTitle('Account'),

        _SettingsTile(
          icon: Icons.login_outlined,
          title: 'Sign in',
          subtitle: 'Sign in to your account',
          onTap: () {
            // Supabase authentication will be connected here.
          },
        ),

        _SettingsTile(
          icon: Icons.logout_outlined,
          title: 'Sign out',
          subtitle: 'Sign out of your account',
          onTap: () {
            // Supabase authentication will be connected here.
          },
        ),

        _SettingsTile(
          icon: Icons.delete_outline,
          title: 'Delete account',
          subtitle: 'Permanently delete your account',
          destructive: true,
          onTap: () {
            // Account deletion will be connected here.
          },
        ),
      ],
    );
  }
}

class _RecitersPage extends StatefulWidget {
  const _RecitersPage();

  @override
  State<_RecitersPage> createState() => _RecitersPageState();
}

class _RecitersPageState extends State<_RecitersPage> {
  // Temporary empty state until we connect this to the
  // admin-published reciter library.
  final Map<String, bool> _enabledReciters = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reciters'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: _enabledReciters.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No reciters are available yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _enabledReciters.entries.map((entry) {
                return SwitchListTile(
                  title: Text(entry.key),
                  value: entry.value,
                  onChanged: (value) {
                    setState(() {
                      _enabledReciters[entry.key] = value;
                    });
                  },
                );
              }).toList(),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2E7D5B);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: destructive ? Colors.red : green),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: destructive ? Colors.red : null,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
