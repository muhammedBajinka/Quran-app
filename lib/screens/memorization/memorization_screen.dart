import 'package:flutter/material.dart';

import '../../data/quran_repository.dart';
import '../../models/quran_models.dart';
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

  bool _showRecitations = false;

  @override
  void initState() {
    super.initState();
    _surahsFuture = _repository.loadSurahs();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Memorization',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.memorizationState.totalMemorizedAyahs} ayahs memorized',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.memorizationState.memorizedCount} Surahs started',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Surahs',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...surahs.map(_buildSurahCard),
      ],
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
        subtitle: Text(
          isMemorized
              ? '$memorizedCount / ${surah.ayahCount} ayahs memorized'
              : '${surah.nameArabic} · ${surah.ayahCount} ayahs',
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
