import 'package:flutter/material.dart';

import '../../data/quran_repository.dart';
import '../../models/quran_models.dart';
import '../../theme/quran_text_style.dart';
import '../../state/memorization_state.dart';
import '../../state/progress_state.dart';
import 'memorization_ayah_selection_screen.dart';
import 'memorization_record_screen.dart';

class MemorizationScreen extends StatefulWidget {
  final MemorizationState memorizationState;
  final ProgressState progressState;

  const MemorizationScreen({
    super.key,
    required this.memorizationState,
    required this.progressState,
  });

  @override
  State<MemorizationScreen> createState() => _MemorizationScreenState();
}

class _MemorizationScreenState extends State<MemorizationScreen> {
  final QuranRepository _repository = QuranRepository();

  late Future<List<QuranSurah>> _surahsFuture;
  late Future<List<QuranJuz>> _juzsFuture;

  bool _showRecitations = false;
  bool _showJuzs = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _surahsFuture = _repository.loadSurahs();
    _juzsFuture = _repository.loadJuzs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAyahSelection(QuranSurah surah) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => MemorizationAyahSelectionScreen(
          surah: surah,
          memorizationState: widget.memorizationState,
          progressState: widget.progressState,
        ),
      ),
    );

    if (!mounted) return;

    setState(() {});
  }

  Future<void> _openRecording(
    QuranSurah surah,
    MemorizationRecording recording,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => MemorizationRecordScreen(
          surah: surah,
          selectedAyahs: recording.ayahNumbers,
          memorizationState: widget.memorizationState,
          progressState: widget.progressState,
        ),
      ),
    );

    if (!mounted) return;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QuranSurah>>(
      future: _surahsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Unable to load the Quran data.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final surahs = snapshot.data ?? <QuranSurah>[];

        return AnimatedBuilder(
          animation: widget.memorizationState,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
              children: [
                _buildTopSwitcher(),
                const SizedBox(height: 18),
                if (_showRecitations)
                  _buildRecitations(surahs)
                else
                  _buildMemorization(surahs),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTopSwitcher() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment<bool>(
          value: false,
          icon: Icon(Icons.menu_book_outlined),
          label: Text('My Memorization'),
        ),
        ButtonSegment<bool>(
          value: true,
          icon: Icon(Icons.mic_none),
          label: Text('My Recitations'),
        ),
      ],
      selected: {_showRecitations},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        setState(() {
          _showRecitations = selection.first;
        });
      },
    );
  }

  Widget _buildMemorization(List<QuranSurah> surahs) {
    final totalQuranAyahs = surahs.fold<int>(
      0,
      (total, surah) => total + surah.ayahCount,
    );

    final memorizedAyahs = widget.memorizationState.totalMemorizedAyahs;
    final remainingAyahs = (totalQuranAyahs - memorizedAyahs).clamp(
      0,
      totalQuranAyahs,
    );

    final startedSurahs = widget.memorizationState.memorizedCount;
    final remainingSurahs = surahs.where((surah) {
      return widget.memorizationState.memorizedAyahCountForSurah(surah.number) <
          surah.ayahCount;
    }).length;

    final query = _searchQuery.trim().toLowerCase();

    final filteredSurahs = surahs.where((surah) {
      if (query.isEmpty) {
        return true;
      }

      return surah.number.toString() == query ||
          surah.nameTransliteration.toLowerCase().contains(query) ||
          surah.nameEnglish.toLowerCase().contains(query) ||
          surah.nameArabic.contains(_searchQuery.trim());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'My Memorization',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Text(
                  '$memorizedAyahs / $totalQuranAyahs ayahs memorized',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: totalQuranAyahs == 0
                      ? 0
                      : memorizedAyahs / totalQuranAyahs,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMemorizationStat(
                        '$remainingAyahs',
                        'Ayahs left',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMemorizationStat(
                        '$startedSurahs',
                        'Surahs started',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMemorizationStat(
                        '$remainingSurahs',
                        'Surahs left',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: _showJuzs
                ? 'Search Juz number'
                : 'Search Surah name or number',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 14),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(
              value: false,
              icon: Icon(Icons.menu_book_outlined),
              label: Text('Surahs'),
            ),
            ButtonSegment<bool>(
              value: true,
              icon: Icon(Icons.auto_stories_outlined),
              label: Text('Juz'),
            ),
          ],
          selected: {_showJuzs},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            setState(() {
              _showJuzs = selection.first;
              _searchQuery = '';
              _searchController.clear();
            });
          },
        ),
        const SizedBox(height: 16),
        if (_showJuzs)
          FutureBuilder<List<QuranJuz>>(
            future: _juzsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Unable to load Juz data.'),
                );
              }

              final juzs = snapshot.data ?? <QuranJuz>[];
              final juzQuery = _searchQuery.trim().toLowerCase();

              final filteredJuzs = juzs.where((juz) {
                if (juzQuery.isEmpty) {
                  return true;
                }

                return juz.number.toString() == juzQuery ||
                    juz.name.toLowerCase().contains(juzQuery);
              }).toList();

              if (filteredJuzs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: Text('No Juz found.')),
                );
              }

              return Column(
                children: filteredJuzs
                    .map(
                      (juz) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${juz.number}')),
                          title: Text(
                            'Juz ${juz.number}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(juz.name),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openJuzActions(juz, juzs, surahs),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          )
        else if (filteredSurahs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: Text('No Surah found.')),
          )
        else
          ...filteredSurahs.map(_buildSurahCard),
      ],
    );
  }

  Widget _buildMemorizationStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Map<int, List<int>> _ayahsForJuz(
    QuranJuz juz,
    List<QuranJuz> juzs,
    List<QuranSurah> surahs,
  ) {
    QuranJuz? nextJuz;

    for (final candidate in juzs) {
      if (candidate.number == juz.number + 1) {
        nextJuz = candidate;
        break;
      }
    }

    final result = <int, List<int>>{};

    for (final surah in surahs) {
      if (surah.number < juz.startSurahNumber) {
        continue;
      }

      if (nextJuz != null && surah.number > nextJuz.startSurahNumber) {
        break;
      }

      var firstAyah = 1;
      var lastAyah = surah.ayahCount;

      if (surah.number == juz.startSurahNumber) {
        firstAyah = juz.startAyahNumber;
      }

      if (nextJuz != null && surah.number == nextJuz.startSurahNumber) {
        lastAyah = nextJuz.startAyahNumber - 1;
      }

      if (firstAyah <= lastAyah) {
        result[surah.number] = List<int>.generate(
          lastAyah - firstAyah + 1,
          (index) => firstAyah + index,
        );
      }

      if (nextJuz != null && surah.number == nextJuz.startSurahNumber) {
        break;
      }
    }

    return result;
  }

  Future<void> _openJuzActions(
    QuranJuz juz,
    List<QuranJuz> juzs,
    List<QuranSurah> surahs,
  ) async {
    final portions = _ayahsForJuz(juz, juzs, surahs);

    if (portions.isEmpty) {
      return;
    }

    final activity = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Juz ${juz.number}',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(juz.name),
                const SizedBox(height: 18),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.menu_book)),
                  title: const Text('Memorization'),
                  subtitle: const Text('Mark the whole Juz as memorized.'),
                  onTap: () => Navigator.pop(sheetContext, 'memorization'),
                ),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.refresh)),
                  title: const Text('Revision'),
                  subtitle: const Text('Log revision for the whole Juz.'),
                  onTap: () => Navigator.pop(sheetContext, 'revision'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (activity == null || !mounted) {
      return;
    }

    if (activity == 'memorization') {
      final strength = await _chooseBulkStrength();

      if (strength == null || !mounted) {
        return;
      }

      var newAyahCount = 0;
      final now = DateTime.now();

      for (final entry in portions.entries) {
        final alreadyMemorized = widget.memorizationState
            .memorizedAyahsForSurah(entry.key);

        final newAyahs = entry.value
            .where((ayah) => !alreadyMemorized.contains(ayah))
            .length;

        newAyahCount += newAyahs;

        final session = MemorizationSession(
          id: '${now.microsecondsSinceEpoch}-${entry.key}',
          surahNumber: entry.key,
          ayahNumbers: List.unmodifiable(entry.value),
          mistakeAyahs: const [],
          type: MemorizationSessionType.memorization,
          createdAt: now,
        );

        widget.memorizationState.completeMemorization(
          session: session,
          strength: strength,
        );
      }

      if (newAyahCount > 0) {
        await widget.progressState.recordMemorizationCompletion(newAyahCount);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newAyahCount == 0
                ? 'Juz ${juz.number} was already memorized.'
                : 'Juz ${juz.number} marked as memorized.',
          ),
        ),
      );
    } else {
      final now = DateTime.now();

      for (final entry in portions.entries) {
        widget.memorizationState.addRevisionSession(
          RevisionSession(
            id: '${now.microsecondsSinceEpoch}-${entry.key}',
            surahNumber: entry.key,
            ayahNumbers: List.unmodifiable(entry.value),
            mistakeAyahs: const [],
            createdAt: now,
          ),
        );
      }

      await widget.progressState.recordRevisionSession();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Revision logged for Juz ${juz.number}.')),
      );
    }
  }

  Future<AyahStrength?> _chooseBulkStrength() {
    return showModalBottomSheet<AyahStrength>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Memorization strength',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('Strong'),
                  subtitle: const Text('I know this Juz well.'),
                  onTap: () => Navigator.pop(sheetContext, AyahStrength.strong),
                ),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Needs review'),
                  subtitle: const Text('I need more revision.'),
                  onTap: () =>
                      Navigator.pop(sheetContext, AyahStrength.needsReview),
                ),
                ListTile(
                  leading: const Icon(Icons.warning_amber_outlined),
                  title: const Text('Weak'),
                  subtitle: const Text('I need significant practice.'),
                  onTap: () => Navigator.pop(sheetContext, AyahStrength.bad),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecitations(List<QuranSurah> surahs) {
    final recordings = [...widget.memorizationState.recordings]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (recordings.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.mic_none,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              const Text(
                'No recitations yet',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Record a recitation from the Memorization section and it will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'My Recitations',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${recordings.length}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...recordings.map((recording) {
          final surah = _findSurah(surahs, recording.surahNumber);

          if (surah == null) {
            return const SizedBox.shrink();
          }

          final selectionLabel = _recordingSelectionLabel(recording, surah);

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openRecording(surah, recording),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                child: Row(
                  children: [
                    CircleAvatar(child: Text('${surah.number}')),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            surah.nameTransliteration,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectionLabel,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatDate(recording.createdAt)} · '
                            '${_formatDuration(recording.durationSeconds)}',
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
        }),
      ],
    );
  }

  QuranSurah? _findSurah(List<QuranSurah> surahs, int surahNumber) {
    for (final surah in surahs) {
      if (surah.number == surahNumber) {
        return surah;
      }
    }

    return null;
  }

  String _recordingSelectionLabel(
    MemorizationRecording recording,
    QuranSurah surah,
  ) {
    final recordedAyahs = recording.ayahNumbers.toSet();

    final isWholeSurah =
        recordedAyahs.length == surah.ayahCount &&
        List.generate(
          surah.ayahCount,
          (index) => index + 1,
        ).every(recordedAyahs.contains);

    if (isWholeSurah) {
      return 'Whole Surah';
    }

    final ayahs = [...recordedAyahs]..sort();

    if (ayahs.isEmpty) {
      return 'No ayahs';
    }

    if (ayahs.length == 1) {
      return 'Ayah ${ayahs.first}';
    }

    return 'Ayahs ${ayahs.first}–${ayahs.last}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildSurahCard(QuranSurah surah) {
    final memorizedCount = widget.memorizationState.memorizedAyahCountForSurah(
      surah.number,
    );

    final isMemorized = memorizedCount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(child: Text('${surah.number}')),
        title: Text(
          surah.nameTransliteration,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: isMemorized
            ? Text('$memorizedCount / ${surah.ayahCount} ayahs memorized')
            : Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: surah.nameArabic,
                      style: QuranTextStyle.arabic(),
                    ),
                    TextSpan(text: ' · ${surah.ayahCount} ayahs'),
                  ],
                ),
              ),
        trailing: IconButton(
          tooltip: 'Select ayahs',
          icon: Icon(
            isMemorized ? Icons.check_circle : Icons.add_circle_outline,
          ),
          onPressed: () => _openAyahSelection(surah),
        ),
        onTap: () => _openAyahSelection(surah),
      ),
    );
  }
}
