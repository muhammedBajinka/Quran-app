import 'package:flutter/material.dart';

import '../../models/quran_models.dart';
import '../../theme/quran_text_style.dart';
import '../../state/memorization_state.dart';
import '../../state/progress_state.dart';
import 'memorization_practice_screen.dart';
import 'memorization_record_screen.dart';
import 'memorization_revision_screen.dart';

class MemorizationAyahActionsScreen extends StatefulWidget {
  final QuranSurah surah;
  final List<int> selectedAyahs;
  final MemorizationState memorizationState;
  final ProgressState progressState;

  const MemorizationAyahActionsScreen({
    super.key,
    required this.surah,
    required this.selectedAyahs,
    required this.memorizationState,
    required this.progressState,
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

    _strength = widget.memorizationState
        .portionForSelection(widget.surah.number, widget.selectedAyahs)
        ?.strength;
  }

  String _ayahSummary() {
    if (widget.selectedAyahs.isEmpty) {
      return 'No ayahs selected';
    }

    final sorted = [...widget.selectedAyahs]..sort();

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

      ranges.add(start == previous ? '$start' : '$start–$previous');

      start = current;
      previous = current;
    }

    ranges.add(start == previous ? '$start' : '$start–$previous');

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
          progressState: widget.progressState,
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
          progressState: widget.progressState,
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
          progressState: widget.progressState,
        ),
      ),
    );
  }

  void _showStrengthMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Choose Strong, Needs review, or Bad first.'),
        ),
      );
  }

  Widget _buildStrengthCard({
    required AyahStrength strength,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final selected = _strength == strength;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectStrength(strength),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(child: Icon(icon)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(radius: 26, child: Icon(icon)),
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  @override
  Widget build(BuildContext context) {
    final memorizedCount = widget.memorizationState.memorizedAyahCountForSurah(
      widget.surah.number,
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.surah.nameTransliteration)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.surah.nameArabic,
                    style: QuranTextStyle.arabic(
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$memorizedCount / ${widget.surah.ayahCount} ayahs memorized',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'How strong is this portion?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          _buildStrengthCard(
            strength: AyahStrength.strong,
            title: 'Strong',
            description: 'I know this portion well.',
            icon: Icons.check_circle_outline,
          ),

          _buildStrengthCard(
            strength: AyahStrength.needsReview,
            title: 'Needs review',
            description: 'I know it but need more revision.',
            icon: Icons.refresh,
          ),

          _buildStrengthCard(
            strength: AyahStrength.bad,
            title: 'Bad',
            description: 'I need to work on this portion more.',
            icon: Icons.warning_amber_outlined,
          ),

          const SizedBox(height: 18),

          const Text(
            'What do you want to do?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          _buildActionCard(
            icon: Icons.menu_book,
            title: 'Memorize',
            description: 'Practice this portion from memory.',
            onTap: _openMemorize,
          ),

          _buildActionCard(
            icon: Icons.refresh,
            title: 'Revision',
            description: 'Revise this portion and log the session.',
            onTap: _openRevision,
          ),

          _buildActionCard(
            icon: Icons.mic,
            title: 'Record',
            description: 'Make one continuous recording of this portion.',
            onTap: _openRecord,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Change selected ayahs'),
          ),
        ),
      ),
    );
  }
}
