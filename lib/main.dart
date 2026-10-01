import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/quran_reciter_repository.dart';
import 'models/audio/quran_reciter.dart';
import 'screens/audio/audio_screen.dart';
import 'screens/memorization/memorization_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/quran/quran_screen.dart';
import 'state/audio/media_audio_controller.dart';
import 'state/audio/quran_audio_controller.dart';
import 'state/memorization_state.dart';
import 'state/progress_state.dart';
import 'state/quran_reading_state.dart';
import 'state/quran_settings_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  final progressState = ProgressState();
  await progressState.load();
  await progressState.registerAppOpen();

  runApp(QuranApp(progressState: progressState));
}

class QuranApp extends StatelessWidget {
  final ProgressState progressState;

  const QuranApp({super.key, required this.progressState});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quran',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D5B),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: QuranHomePage(progressState: progressState),
    );
  }
}

class QuranHomePage extends StatefulWidget {
  final ProgressState progressState;

  const QuranHomePage({super.key, required this.progressState});

  @override
  State<QuranHomePage> createState() => _QuranHomePageState();
}

class _QuranHomePageState extends State<QuranHomePage> {
  final MemorizationState _memorizationState = MemorizationState();
  final QuranAudioController _audioController = QuranAudioController();
  final MediaAudioController _mediaAudioController = MediaAudioController();
  final QuranReadingState _quranReadingState = QuranReadingState();
  final QuranSettingsState _quranSettingsState = QuranSettingsState();
  final QuranReciterRepository _reciterRepository = QuranReciterRepository();

  List<QuranReciter> _reciters = const [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _quranReadingState.load();
    _quranSettingsState.load();
    _loadReciters();
  }

  Future<void> _loadReciters() async {
    try {
      final reciters = await _reciterRepository.getPublishedReciters();

      if (!mounted) {
        return;
      }

      setState(() {
        _reciters = reciters;
      });
    } catch (_) {
      // Keep the app usable when the reciter catalogue cannot be loaded.
    }
  }

  static const List<String> _titles = [
    'Quran',
    'Memorization',
    'Progress',
    'Dua',
    'Settings',
  ];

  @override
  void dispose() {
    _memorizationState.dispose();
    _audioController.dispose();
    _mediaAudioController.dispose();
    _quranReadingState.dispose();
    _quranSettingsState.dispose();
    widget.progressState.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _memorizationState,
        widget.progressState,
        _quranReadingState,
        _quranSettingsState,
      ]),
      builder: (context, child) {
        final pages = <Widget>[
          QuranScreen(
            memorizationState: _memorizationState,
            audioController: _audioController,
            readingState: _quranReadingState,
            settingsState: _quranSettingsState,
            reciters: _reciters,
          ),
          MemorizationScreen(
            memorizationState: _memorizationState,
            progressState: widget.progressState,
          ),
          _ProgressPage(
            progressState: widget.progressState,
            memorizationState: _memorizationState,
          ),
          AudioScreen(audioController: _mediaAudioController),
          SettingsScreen(
            settingsState: _quranSettingsState,
            reciters: _reciters,
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(_titles[_selectedIndex]),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
          ),
          body: pages[_selectedIndex],
          bottomNavigationBar: NavigationBarTheme(
            data: const NavigationBarThemeData(
              labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
            ),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _selectTab,
              backgroundColor: Colors.white,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: 'Quran',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bookmark_outline),
                  selectedIcon: Icon(Icons.bookmark),
                  label: 'Memorization',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: 'Progress',
                ),
                NavigationDestination(
                  icon: Icon(Icons.headphones_outlined),
                  selectedIcon: Icon(Icons.headphones),
                  label: 'Dua',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProgressPage extends StatelessWidget {
  final ProgressState progressState;
  final MemorizationState memorizationState;

  const _ProgressPage({
    required this.progressState,
    required this.memorizationState,
  });

  static const int _totalQuranAyahs = 6236;

  @override
  Widget build(BuildContext context) {
    final memorized = memorizationState.totalMemorizedAyahs;
    final remaining = (_totalQuranAyahs - memorized).clamp(0, _totalQuranAyahs);
    final progress = (memorized / _totalQuranAyahs).clamp(0.0, 1.0);
    final percentage = (progress * 100).round();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Your Progress',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your Quran learning at a glance.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),

        Card(
          elevation: 0,
          color: const Color(0xFFF8FAF9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2E8E5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 132,
                      height: 132,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 118,
                            height: 118,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 12,
                              backgroundColor: const Color(0xFFE8EEEB),
                              color: const Color(0xFF2E7D5B),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$percentage%',
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                'memorized',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Overall memorization',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$memorized of $_totalQuranAyahs Ayahs',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${memorizationState.memorizedCount} Surahs in learning',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF2E7D5B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _ProgressCard(
                        icon: Icons.check_circle_outline,
                        title: 'Ayahs memorized',
                        value: '$memorized',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProgressCard(
                        icon: Icons.menu_book_outlined,
                        title: 'Ayahs remaining',
                        value: '$remaining',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        const Text(
          'Learning activity',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _ProgressCard(
                icon: Icons.bookmark_added_outlined,
                title: 'Memorization sessions',
                value: '${memorizationState.totalMemorizationSessions}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProgressCard(
                icon: Icons.replay_outlined,
                title: 'Revision sessions',
                value: '${memorizationState.totalRevisionSessionsLogged}',
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _ProgressCard(
                icon: Icons.mic_none_outlined,
                title: 'Recordings',
                value: '${memorizationState.recordings.length}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProgressCard(
                icon: Icons.local_fire_department_outlined,
                title: 'Current streak',
                value: '${progressState.currentStreak} days',
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        const Text(
          'Activity',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),

        _InfoTile(
          icon: Icons.emoji_events_outlined,
          title: 'Longest streak',
          value: '${progressState.longestStreak} days',
        ),
        _InfoTile(
          icon: Icons.calendar_today_outlined,
          title: 'Active days',
          value: '${progressState.totalOpenDays}',
        ),
        _InfoTile(
          icon: Icons.stars_outlined,
          title: 'Points',
          value: '${progressState.points}',
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ProgressCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8E5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF2E7D5B), size: 23),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF2E7D5B)),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }
}
