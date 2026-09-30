import 'package:flutter/material.dart';

import '../../models/audio/quran_reciter.dart';
import '../../state/quran_settings_state.dart';

class SettingsScreen extends StatelessWidget {
  final QuranSettingsState settingsState;
  final List<QuranReciter> reciters;

  const SettingsScreen({
    super.key,
    required this.settingsState,
    this.reciters = const [],
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const _SectionTitle('Quran'),

        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.format_size, color: Color(0xFF2E7D5B)),
                    SizedBox(width: 16),
                    Text(
                      'Arabic Text Size',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: Text('Size: ${settingsState.arabicTextSize.round()}'),
                ),
                Row(
                  children: [
                    const Text('A', style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: Slider(
                        min: QuranSettingsState.minArabicTextSize,
                        max: QuranSettingsState.maxArabicTextSize,
                        divisions:
                            (QuranSettingsState.maxArabicTextSize -
                                    QuranSettingsState.minArabicTextSize)
                                .round(),
                        value: settingsState.arabicTextSize,
                        onChanged: settingsState.setArabicTextSize,
                      ),
                    ),
                    const Text(
                      'A',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        _SettingsTile(
          icon: Icons.mic_none,
          title: 'Reciters',
          subtitle: 'Choose which reciters are available',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _RecitersPage(
                  settingsState: settingsState,
                  reciters: reciters,
                ),
              ),
            );
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

class _RecitersPage extends StatelessWidget {
  final QuranSettingsState settingsState;
  final List<QuranReciter> reciters;

  const _RecitersPage({required this.settingsState, required this.reciters});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reciters'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListenableBuilder(
        listenable: settingsState,
        builder: (context, child) {
          if (reciters.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No reciters are available yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reciters.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final reciter = reciters[index];
              final enabled = settingsState.isReciterEnabled(reciter.id);
              final isDefault = settingsState.defaultReciterId == reciter.id;

              return Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(reciter.name),
                      subtitle: Text(
                        isDefault ? 'Default reciter' : 'Available in player',
                      ),
                      value: enabled,
                      onChanged: (value) {
                        settingsState.setReciterEnabled(reciter.id, value);
                      },
                    ),
                    if (enabled)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: isDefault
                              ? const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF2E7D5B),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Default reciter',
                                      style: TextStyle(
                                        color: Color(0xFF2E7D5B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : OutlinedButton(
                                  onPressed: () {
                                    settingsState.setDefaultReciter(reciter.id);
                                  },
                                  child: const Text('Set as default'),
                                ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
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
