import 'package:flutter/material.dart';

import '../../models/quran_models.dart';
import '../../state/memorization_state.dart';
import '../../state/progress_state.dart';
import 'memorization_record_screen.dart';

class MemorizationAyahSelectionScreen extends StatefulWidget {
  final QuranSurah surah;
  final MemorizationState memorizationState;
  final ProgressState progressState;

  const MemorizationAyahSelectionScreen({
    super.key,
    required this.surah,
    required this.memorizationState,
    required this.progressState,
  });

  @override
  State<MemorizationAyahSelectionScreen> createState() =>
      _MemorizationAyahSelectionScreenState();
}

enum _Activity { memorize, revision, record }

enum _Scope { wholeSurah, chooseAyahs }

class _MemorizationAyahSelectionScreenState
    extends State<MemorizationAyahSelectionScreen> {
  _Activity? _activity;
  _Scope? _scope;
  final Set<int> _selectedAyahs = {};
  AyahStrength? _strength;

  void _chooseActivity(_Activity activity) {
    setState(() {
      _activity = activity;
      _scope = null;
      _selectedAyahs.clear();
      _strength = null;
    });
  }

  void _chooseScope(_Scope scope) {
    setState(() {
      _scope = scope;

      if (scope == _Scope.wholeSurah) {
        _selectedAyahs
          ..clear()
          ..addAll(
            List<int>.generate(widget.surah.ayahCount, (index) => index + 1),
          );
      } else {
        _selectedAyahs.clear();
      }
    });
  }

  void _toggleAyah(int ayahNumber) {
    setState(() {
      if (_selectedAyahs.contains(ayahNumber)) {
        _selectedAyahs.remove(ayahNumber);
      } else {
        _selectedAyahs.add(ayahNumber);
      }
    });
  }

  void _chooseStrength(AyahStrength strength) {
    setState(() {
      _strength = strength;
    });
  }

  Future<void> _finish() async {
    final activity = _activity;
    final strength = _strength;

    if (activity == null || _scope == null || _selectedAyahs.isEmpty) {
      return;
    }

    if (activity != _Activity.record && strength == null) {
      return;
    }

    final ayahs = [..._selectedAyahs]..sort();

    if (activity == _Activity.record) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => MemorizationRecordScreen(
            surah: widget.surah,
            selectedAyahs: ayahs,
            memorizationState: widget.memorizationState,
            progressState: widget.progressState,
          ),
        ),
      );
      return;
    }

    final now = DateTime.now();

    widget.memorizationState.saveMemorizationPortion(
      surahNumber: widget.surah.number,
      ayahNumbers: ayahs,
      strength: strength!,
    );

    if (activity == _Activity.memorize) {
      final session = MemorizationSession(
        id: now.microsecondsSinceEpoch.toString(),
        surahNumber: widget.surah.number,
        ayahNumbers: List.unmodifiable(ayahs),
        mistakeAyahs: const [],
        type: MemorizationSessionType.memorization,
        createdAt: now,
      );

      widget.memorizationState.completeMemorization(
        session: session,
        strength: strength,
      );

      await widget.progressState.recordMemorizationCompletion(
        widget.memorizationState.memorizedAyahCountForSurah(
          widget.surah.number,
        ),
      );
    } else {
      final session = RevisionSession(
        id: now.microsecondsSinceEpoch.toString(),
        surahNumber: widget.surah.number,
        ayahNumbers: List.unmodifiable(ayahs),
        mistakeAyahs: const [],
        createdAt: now,
      );

      widget.memorizationState.addRevisionSession(session);
      await widget.progressState.recordRevisionSession();
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          activity == _Activity.memorize
              ? 'Memorization logged.'
              : 'Revision logged.',
        ),
      ),
    );

    Navigator.pop(context);
  }

  String _activityTitle() {
    switch (_activity) {
      case _Activity.memorize:
        return 'Memorize';
      case _Activity.revision:
        return 'Revision';
      case _Activity.record:
        return 'Record';
      case null:
        return '';
    }
  }

  Widget _choiceCard({
    required IconData icon,
    required String title,
    required String description,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
                    Text(description),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAyahs = _selectedAyahs.isNotEmpty;
    final canFinish =
        _activity != null && _scope != null && hasAyahs && _strength != null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.surah.nameTransliteration)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Text(
            widget.surah.nameArabic,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('${widget.surah.ayahCount} ayahs'),
          const SizedBox(height: 24),

          const Text(
            '1. Activity',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          _choiceCard(
            icon: Icons.menu_book,
            title: 'Memorize',
            description: 'Log these ayahs as memorized.',
            selected: _activity == _Activity.memorize,
            onTap: () => _chooseActivity(_Activity.memorize),
          ),
          _choiceCard(
            icon: Icons.refresh,
            title: 'Revision',
            description: 'Log these ayahs as revised.',
            selected: _activity == _Activity.revision,
            onTap: () => _chooseActivity(_Activity.revision),
          ),
          _choiceCard(
            icon: Icons.mic,
            title: 'Record',
            description: 'Make one continuous recording.',
            selected: _activity == _Activity.record,
            onTap: () => _chooseActivity(_Activity.record),
          ),

          if (_activity != null) ...[
            const SizedBox(height: 14),
            const Text(
              '2. Scope',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            _choiceCard(
              icon: Icons.menu_book,
              title: 'Whole Surah',
              description: 'Use all ${widget.surah.ayahCount} ayahs.',
              selected: _scope == _Scope.wholeSurah,
              onTap: () => _chooseScope(_Scope.wholeSurah),
            ),
            _choiceCard(
              icon: Icons.format_list_numbered,
              title: 'Choose ayahs',
              description: 'Pick only the ayahs you want.',
              selected: _scope == _Scope.chooseAyahs,
              onTap: () => _chooseScope(_Scope.chooseAyahs),
            ),
          ],

          if (_scope == _Scope.chooseAyahs) ...[
            const SizedBox(height: 8),
            Text(
              '${_selectedAyahs.length} ayahs selected',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: widget.surah.ayahCount,
              itemBuilder: (context, index) {
                final ayahNumber = index + 1;
                final selected = _selectedAyahs.contains(ayahNumber);

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _toggleAyah(ayahNumber),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$ayahNumber',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: selected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],

          if (_scope != null) ...[
            const SizedBox(height: 20),
            const Text(
              '3. Strength',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            _choiceCard(
              icon: Icons.check_circle_outline,
              title: 'Strong',
              description: 'I know this portion well.',
              selected: _strength == AyahStrength.strong,
              onTap: () => _chooseStrength(AyahStrength.strong),
            ),
            _choiceCard(
              icon: Icons.refresh,
              title: 'Needs review',
              description: 'I need more revision.',
              selected: _strength == AyahStrength.needsReview,
              onTap: () => _chooseStrength(AyahStrength.needsReview),
            ),
            _choiceCard(
              icon: Icons.warning_amber_outlined,
              title: 'Bad',
              description: 'I need to work on this more.',
              selected: _strength == AyahStrength.bad,
              onTap: () => _chooseStrength(AyahStrength.bad),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton(
            onPressed: canFinish ? _finish : null,
            child: Text(
              _activity == _Activity.record
                  ? 'Continue to Recording'
                  : 'Log ${_activityTitle()}',
            ),
          ),
        ),
      ),
    );
  }
}
