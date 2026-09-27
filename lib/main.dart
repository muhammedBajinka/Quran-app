import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/audio/audio_screen.dart';
import 'screens/memorization/memorization_screen.dart';
import 'screens/quran/quran_screen.dart';
import 'state/memorization_state.dart';
import 'state/progress_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  final progressState = ProgressState();
  await progressState.load();
  await progressState.registerAppOpen();

  runApp(
    QuranApp(
      progressState: progressState,
    ),
  );
}

class QuranApp extends StatelessWidget {
  final ProgressState progressState;

  const QuranApp({
    super.key,
    required this.progressState,
  });

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
      home: QuranHomePage(
        progressState: progressState,
      ),
    );
  }
}

class QuranHomePage extends StatefulWidget {
  final ProgressState progressState;

  const QuranHomePage({
    super.key,
    required this.progressState,
  });

  @override
  State<QuranHomePage> createState() => _QuranHomePageState();
}

class _QuranHomePageState extends State<QuranHomePage> {
  final MemorizationState _memorizationState = MemorizationState();

  int _selectedIndex = 0;

  static const List<String> _titles = [
    'Quran',
    'Memorization',
    'Progress',
    'Audio',
    'Settings',
  ];

  @override
  void dispose() {
    _memorizationState.dispose();
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
      ]),
      builder: (context, child) {
        final pages = <Widget>[
          QuranScreen(
            memorizationState: _memorizationState,
          ),
          MemorizationScreen(
            memorizationState: _memorizationState,
            progressState: widget.progressState,
          ),
          _ProgressPage(
            progressState: widget.progressState,
            memorizationState: _memorizationState,
          ),
          const AudioScreen(),
          const _PlaceholderPage(
            title: 'Settings',
            message: 'Account, Quran and audio settings will be built here.',
            icon: Icons.settings_outlined,
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
              labelTextStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 11),
              ),
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
                label: 'Audio',
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Your Progress',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Keep learning and build your streak.',
          style: TextStyle(
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: _ProgressCard(
                icon: Icons.stars_outlined,
                title: 'Points',
                value: '${progressState.points}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProgressCard(
                icon: Icons.local_fire_department_outlined,
                title: 'Streak',
                value: '${progressState.currentStreak} days',
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _ProgressCard(
                icon: Icons.emoji_events_outlined,
                title: 'Longest streak',
                value: '${progressState.longestStreak} days',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProgressCard(
                icon: Icons.calendar_today_outlined,
                title: 'Active days',
                value: '${progressState.totalOpenDays}',
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        const Text(
          'Memorization',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 12),

        _InfoTile(
          icon: Icons.menu_book_outlined,
          title: 'Ayahs memorized',
          value: '${memorizationState.totalMemorizedAyahs}',
        ),

        _InfoTile(
          icon: Icons.bookmark_added_outlined,
          title: 'Memorization sessions',
          value: '${memorizationState.totalMemorizationSessions}',
        ),

        _InfoTile(
          icon: Icons.replay_outlined,
          title: 'Revision sessions',
          value: '${memorizationState.totalRevisionSessionsLogged}',
        ),

        _InfoTile(
          icon: Icons.mic_none_outlined,
          title: 'Recordings',
          value: '${memorizationState.recordings.length}',
        ),

        const SizedBox(height: 24),

        const Text(
          'How you earn points',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 12),

        const _PointRule(
          icon: Icons.login_outlined,
          text: 'Open the app once each day',
          points: '+1',
        ),
        const _PointRule(
          icon: Icons.menu_book_outlined,
          text: 'Complete a memorization session',
          points: '+5',
        ),
        const _PointRule(
          icon: Icons.replay_outlined,
          text: 'Complete a revision session',
          points: '+3',
        ),
        const _PointRule(
          icon: Icons.mic_none_outlined,
          text: 'Complete a recording',
          points: '+2',
        ),
        const _PointRule(
          icon: Icons.check_circle_outline,
          text: 'Memorize an ayah',
          points: '+1',
        ),
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
    return Card(
      elevation: 0,
      color: const Color(0xFFF4F8F6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: const Color(0xFF2E7D5B),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
          ],
        ),
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
        leading: Icon(
          icon,
          color: const Color(0xFF2E7D5B),
        ),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _PointRule extends StatelessWidget {
  final IconData icon;
  final String text;
  final String points;

  const _PointRule({
    required this.icon,
    required this.text,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: const Color(0xFF2E7D5B),
      ),
      title: Text(text),
      trailing: Text(
        points,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _PlaceholderPage({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: const Color(0xFF2E7D5B),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
