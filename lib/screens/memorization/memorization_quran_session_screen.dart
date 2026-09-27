import 'package:flutter/material.dart';

import '../../models/quran_models.dart';
import '../../state/memorization_state.dart';

class MemorizationQuranSessionScreen extends StatefulWidget {
  final QuranSurah surah;
  final List<int> selectedAyahs;
  final MemorizationState memorizationState;
  final MemorizationSessionType type;

  const MemorizationQuranSessionScreen({
    super.key,
    required this.surah,
    required this.selectedAyahs,
    required this.memorizationState,
    required this.type,
  });

  @override
  State<MemorizationQuranSessionScreen> createState() =>
      _MemorizationQuranSessionScreenState();
}

class _MemorizationQuranSessionScreenState
    extends State<MemorizationQuranSessionScreen> {
  late final List<int> _selectedAyahs;

  final Set<int> _mistakeAyahs = {};

  @override
  void initState() {
    super.initState();

    _selectedAyahs = [...widget.selectedAyahs]..sort();
  }

  String get _title {
    return widget.type ==
            MemorizationSessionType.memorization
        ? 'Memorization'
        : 'Revision';
  }

  List<QuranAyah> get _ayahs {
    final selected = _selectedAyahs.toSet();

    return widget.surah.ayahs
        .where(
          (ayah) => selected.contains(ayah.ayahNumber),
        )
        .toList();
  }

  Future<void> _markWrong() async {
    if (_selectedAyahs.isEmpty) {
      return;
    }

    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              8,
              18,
              18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Which ayah was wrong?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose the ayah you made a mistake in.',
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _selectedAyahs.length,
                    itemBuilder: (context, index) {
                      final ayahNumber =
                          _selectedAyahs[index];

                      final alreadyMarked =
                          _mistakeAyahs.contains(
                        ayahNumber,
                      );

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text('$ayahNumber'),
                        ),
                        title: Text(
                          'Ayah $ayahNumber',
                        ),
                        trailing: alreadyMarked
                            ? const Icon(
                                Icons.check,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(
                            context,
                            ayahNumber,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      if (_mistakeAyahs.contains(selected)) {
        _mistakeAyahs.remove(selected);
      } else {
        _mistakeAyahs.add(selected);
      }
    });
  }

  Future<void> _finish() async {
    final now = DateTime.now();

    final session = MemorizationSession(
      id: now.microsecondsSinceEpoch.toString(),
      surahNumber: widget.surah.number,
      ayahNumbers: List.unmodifiable(
        _selectedAyahs,
      ),
      mistakeAyahs: List.unmodifiable(
        (_mistakeAyahs.toList()..sort()),
      ),
      type: widget.type,
      createdAt: now,
    );

    widget.memorizationState.addMemorizationSession(
      session,
    );

    if (!mounted) {
      return;
    }

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (context) {
          return _SessionCompleteScreen(
            surah: widget.surah,
            session: session,
          );
        },
      ),
    );
  }

  String _ayahNumberLabel(int number) {
    return '$number';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.surah.nameTransliteration} · $_title',
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          16,
          18,
          16,
          150,
        ),
        itemCount: _ayahs.length,
        itemBuilder: (context, index) {
          final ayah = _ayahs[index];

          final isWrong =
              _mistakeAyahs.contains(
            ayah.ayahNumber,
          );

          return Container(
            margin: const EdgeInsets.only(
              bottom: 18,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: isWrong
                    ? Theme.of(context)
                        .colorScheme
                        .error
                    : Theme.of(context)
                        .dividerColor,
                width: isWrong ? 2 : 1,
              ),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        child: Text(
                          _ayahNumberLabel(
                            ayah.ayahNumber,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (isWrong)
                        Text(
                          'Wrong',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .error,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // The actual Quran writing is intentionally
                  // hidden during blind memorization/revision.
                  Container(
                    padding:
                        const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Recite this ayah from memory.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Material(
          elevation: 8,
          color: Theme.of(context)
              .colorScheme
              .surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              10,
              16,
              10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _markWrong,
                    icon: const Icon(
                      Icons.close,
                    ),
                    label: Text(
                      'Wrong: ${_mistakeAyahs.length}',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _finish,
                    child: const Text(
                      'Finish',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionCompleteScreen extends StatelessWidget {
  final QuranSurah surah;
  final MemorizationSession session;

  const _SessionCompleteScreen({
    required this.surah,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final typeText = session.type ==
            MemorizationSessionType.memorization
        ? 'Memorization'
        : 'Revision';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session complete'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          const Icon(
            Icons.check_circle,
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            '$typeText complete',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            surah.nameTransliteration,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '${session.ayahNumbers.length}',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'ayahs practiced',
                  ),
                  const SizedBox(height: 22),
                  Text(
                    '${session.mistakeCount}',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: session.mistakeCount == 0
                          ? null
                          : Theme.of(context)
                              .colorScheme
                              .error,
                    ),
                  ),
                  const Text(
                    'mistakes marked',
                  ),
                  if (session.mistakeAyahs.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Mistakes: ${session.mistakeAyahs.join(', ')}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Done',
            ),
          ),
        ],
      ),
    );
  }
}
