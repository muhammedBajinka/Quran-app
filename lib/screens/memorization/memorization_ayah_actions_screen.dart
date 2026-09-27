import 'package:flutter/material.dart';

import '../../models/quran_models.dart';
import '../../state/memorization_state.dart';
import 'memorization_practice_screen.dart';
import 'memorization_record_screen.dart';
import 'memorization_revision_screen.dart';

class MemorizationAyahActionsScreen extends StatefulWidget {
  final QuranSurah surah;
  final List<int> selectedAyahs;
  final MemorizationState memorizationState;

  const MemorizationAyahActionsScreen({
    super.key,
    required this.surah,
    required this.selectedAyahs,
    required this.memorizationState,
  });

  @override
  State<MemorizationAyahActionsScreen> createState() =>
      _MemorizationAyahActionsScreenState();
}

class _MemorizationAyahActionsScreenState
    extends State<MemorizationAyahActionsScreen> {
  AyahStrength? _strength;

  @override
  void initState() {
    super.initState();

    final existing = widget.memorizationState.portionForSelection(
      widget.surah.number,
      widget.selectedAyahs,
    );

    _strength = existing?.strength;
  }

  String _ayahSummary() {
    final sorted = [...widget.selectedAyahs]..sort();

    if (sorted.isEmpty) {
      return 'No ayahs selected';
    }

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

  void _selectStrength(AyahStrength strength) {
    setState(() {
      _strength = strength;
    });

    widget.memorizationState.saveMemorizationPortion(
      surahNumber: widget.surah.number,
      ayahNumbers: widget.selectedAyahs,
      strength: strength,
    );
  }

  void _openMemorize() {
    if (_strength == null) {
      _showStrengthMessage();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => MemorizationPracticeScreen(
          surah: widget.surah,
          selectedAyahs: widget.selectedAyahs,
          memorizationState: widget.memorizationState,
        ),
      ),
    );
  }

  void _openRevision() {
    if (_strength == null) {
      _showStrengthMessage();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => MemorizationRevisionScreen(
          surah: widget.surah,
          selectedAyahs: widget.selectedAyahs,
          memorizationState: widget.memorizationState,
        ),
      ),
    );
  }

  void _openRecord() {
    if (_strength == null) {
      _showStrengthMessage();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => MemorizationRecordScreen(
          surah: widget.surah,
          selectedAyahs: widget.selectedAyahs,
          memorizationState: widget.memorizationState,
        ),
      ),
    );
  }

  void _showStrengthMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Choose the strength of this portion first.'),
        ),
      );
  }

  String _strengthLabel(AyahStrength strength) {
    switch (strength) {
      case AyahStrength.strong:
        return 'Strong';
      case AyahStrength.needsReview:
        return 'Needs review';
      case AyahStrength.bad:
        return 'Bad';
    }
  }

  IconData _strengthIcon(AyahStrength strength) {
    switch (strength) {
      case AyahStrength.strong:
        return Icons.check_circle;
      case AyahStrength.needsReview:
        return Icons.refresh;
      case AyahStrength.bad:
        return Icons.warning_amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final memorizedCount =
        widget.memorizationState.memorizedAyahCountForSurah(
      widget.surah.number,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.surah.nameTransliteration),
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
                      widget.surah.nameArabic,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.surah.nameTransliteration,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${widget.selectedAyahs.length} ayahs selected',
                      style: const TextStyle(fontSize: 16),
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
                    const SizedBox(height: 10),
                    Text(
                      '$memorizedCount / ${widget.surah.ayahCount} ayahs memorized',
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
              'How strong is this portion?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose one strength for the whole selected portion.',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...AyahStrength.values.map(
              (strength) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StrengthCard(
                  title: _strengthLabel(strength),
                  icon: _strengthIcon(strength),
                  selected: _strength == strength,
                  onTap: () => _selectStrength(strength),
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
                  'Practice the selected ayahs without showing the ayah text here.',
              onTap: _openMemorize,
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.refresh,
              title: 'Revision',
              description:
                  'Start a revision session for this selected portion.',
              onTap: _openRevision,
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.mic,
              title: 'Record',
              description:
                  'Make one continuous recording of this selected portion.',
              onTap: _openRecord,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Change selected ayahs'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrengthCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _StrengthCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: selected ? colorScheme.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                ),
            ],
          ),
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
