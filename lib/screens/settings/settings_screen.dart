import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/audio/quran_reciter.dart';
import '../../services/app_config_service.dart';
import '../../services/app_info_service.dart';
import '../../services/feedback_service.dart';
import '../../state/quran_settings_state.dart';

class SettingsScreen extends StatelessWidget {
  final QuranSettingsState settingsState;
  final List<QuranReciter> reciters;

  const SettingsScreen({
    super.key,
    required this.settingsState,
    this.reciters = const [],
  });

  Future<void> _shareApp(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final config = await AppConfigService().loadConfig();
      final release = config.currentRelease;

      if (release == null || release.downloadUrl.trim().isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('The app download link is not available yet.'),
          ),
        );
        return;
      }

      final message = config.shareMessage.trim();
      final downloadUrl = release.downloadUrl.trim();

      final shareText = message.isEmpty
          ? downloadUrl
          : '$message\n\n$downloadUrl';

      await SharePlus.instance.share(ShareParams(text: shareText));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not open sharing. Please try again.'),
        ),
      );
    }
  }

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
          subtitle: 'Share the latest app download',
          onTap: () => _shareApp(context),
        ),

        _SettingsTile(
          icon: Icons.feedback_outlined,
          title: 'Feedback',
          subtitle: 'Send feedback about the app',
          onTap: () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const _FeedbackPage()));
          },
        ),

        _SettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          subtitle: 'How your information is handled',
          onTap: () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const _PrivacyPage()));
          },
        ),

        _SettingsTile(
          icon: Icons.info_outline,
          title: 'About',
          subtitle: 'About this Quran app',
          onTap: () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const _AboutPage()));
          },
        ),

        const SizedBox(height: 16),
        const _SettingsVersion(),
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

class _FeedbackPage extends StatefulWidget {
  const _FeedbackPage();

  @override
  State<_FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<_FeedbackPage> {
  final TextEditingController _controller = TextEditingController();
  final FeedbackService _feedbackService = FeedbackService();

  String _category = 'General';
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendFeedback() async {
    if (_sending) {
      return;
    }

    final message = _controller.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your feedback first.')),
      );
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await _feedbackService.submit(category: _category, message: message);

      if (!mounted) {
        return;
      }

      _controller.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you. Your feedback was sent.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not send feedback. Check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Help improve the app',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Report a problem, suggest a feature, or send general feedback.',
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'General', child: Text('General')),
              DropdownMenuItem(
                value: 'Problem',
                child: Text('Report a problem'),
              ),
              DropdownMenuItem(
                value: 'Suggestion',
                child: Text('Feature suggestion'),
              ),
              DropdownMenuItem(
                value: 'Quran content',
                child: Text('Quran content'),
              ),
            ],
            onChanged: _sending
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        _category = value;
                      });
                    }
                  },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            enabled: !_sending,
            minLines: 6,
            maxLines: 10,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Your feedback',
              hintText: 'Tell us what you think...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _sending ? null : _sendFeedback,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_sending ? 'Sending...' : 'Send feedback'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Feedback includes an anonymous installation identifier and '
            'the installed app version so problems can be investigated. '
            'Do not include private or sensitive information in your message.',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Text(
            'Privacy',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 20),
          Text(
            'Data stored on your device',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Your Quran progress, memorization information, app settings, '
            'and recordings are stored locally on your device unless a '
            'feature clearly tells you otherwise.',
          ),
          SizedBox(height: 24),
          Text(
            'Feedback',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'When you send feedback, the app sends your feedback category '
            'and message, an anonymous installation identifier, the app '
            'version and build number, and the app platform. The anonymous '
            'installation identifier is not your name and is not a user '
            'account.',
          ),
          SizedBox(height: 24),
          Text(
            'Anonymous analytics',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'The app collects limited anonymous usage information to help '
            'understand how the app is used and improve reliability. This '
            'includes an anonymous installation identifier, app version and '
            'build number, platform, event type, and event time.',
          ),
          SizedBox(height: 12),
          Text(
            'The analytics do not include your name, messages, contacts, '
            'recordings, precise location, or the specific Quran verses and '
            'memorization content you read or study.',
          ),
          SizedBox(height: 24),
          Text(
            'Future accounts',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'If user accounts or connection features are introduced later, '
            'their identity and privacy controls will be handled separately '
            'from the anonymous installation identifier.',
          ),
        ],
      ),
    );
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(
            Icons.menu_book_rounded,
            size: 64,
            color: Color(0xFF2E7D5B),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Quran',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: _VersionText()),
          const SizedBox(height: 28),
          const Text(
            'About the app',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'A Quran app designed for reading, memorization, progress '
            'tracking, Duas, and beneficial Islamic audio.',
          ),
          const SizedBox(height: 24),
          const Text(
            'Privacy',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your personal Quran progress, memorization data, settings, '
            'and recordings remain on your device unless a feature clearly '
            'states that information will be sent.',
          ),
        ],
      ),
    );
  }
}

class _SettingsVersion extends StatelessWidget {
  const _SettingsVersion();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: _VersionText(
        prefix: 'Version ',
        style: TextStyle(fontSize: 12, color: Colors.black45),
      ),
    );
  }
}

class _VersionText extends StatelessWidget {
  final String prefix;
  final TextStyle? style;

  const _VersionText({this.prefix = 'Version ', this.style});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppInfo>(
      future: AppInfoService().load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text(
            '$prefix...',
            style: style ?? const TextStyle(color: Colors.black54),
          );
        }

        return Text(
          '$prefix${snapshot.data!.displayVersion}',
          style: style ?? const TextStyle(color: Colors.black54),
        );
      },
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
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2E7D5B);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
