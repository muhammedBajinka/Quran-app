import 'package:flutter/material.dart';

import '../../models/quran_models.dart';
import '../../state/memorization_state.dart';

class MemorizationAyahActionsScreen extends StatelessWidget {
  final QuranSurah surah;
  final List<int> selectedAyahs;
  final MemorizationState memorizationState;

  const MemorizationAyahActionsScreen({
    super.key,
    required this.surah,
    required this.selectedAyahs,
    required this.memorizationState,
  });

  String _ayahSummary() {
    if (selectedAyahs.isEmpty) {
      return 'No ayahs selected';
    }

    final sorted = [...selectedAyahs]..sort();

    if (sorted.length == 1) {
      return 'Ayah ${sorted.first}';
    }

    final ranges = <String>[];
    var start = sorted.first;
    var previous = sorted.first;

    for (var i = 1; i < sorted.length; i++) {
      final current = sorted[i];

      if (current == previous + 1) {
        previous = current;
        continue;
      }

      ranges.add(
        start == previous ? '$start' : '$start–$previous',
      );

      start = current;
      previous = current;
    }

    ranges.add(
      start == previous ? '$start' : '$start–$previous',
    );

    return ranges.join(', ');
  }

  void _showComingSoon(
    BuildContext context,
    String activity,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$activity will be connected next.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final memorizedCount =
        memorizationState.memorizedAyahCountForSurah(
      surah.number,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(surah.nameTransliteration),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surah.nameArabic,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      surah.nameTransliteration,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${selectedAyahs.length} ayahs selected',
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _ayahSummary(),
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$memorizedCount / ${surah.ayahCount} ayahs memorized',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'What do you want to do?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _ActionCard(
              icon: Icons.menu_book,
              title: 'Memorize',
              description:
                  'Practice the selected ayahs and mark their strength.',
              onTap: () {
                _showComingSoon(context, 'Memorize');
              },
            ),

            const SizedBox(height: 12),

            _ActionCard(
              icon: Icons.refresh,
              title: 'Revision',
              description:
                  'Revise the selected ayahs and record the session.',
              onTap: () {
                _showComingSoon(context, 'Revision');
              },
            ),

            const SizedBox(height: 12),

            _ActionCard(
              icon: Icons.mic,
              title: 'Record',
              description:
                  'Make one continuous recording of the selected portion.',
              onTap: () {
                _showComingSoon(context, 'Record');
              },
            ),

            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Change selected ayahs'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                child: Icon(icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
