import 'package:flutter/material.dart';

import '../../data/quran_repository.dart';
import '../../models/quran_models.dart';
import '../../state/memorization_state.dart';
import 'memorization_ayah_selection_screen.dart';

class MemorizationScreen extends StatefulWidget {
  final MemorizationState memorizationState;

  const MemorizationScreen({
    super.key,
    required this.memorizationState,
  });

  @override
  State<MemorizationScreen> createState() => _MemorizationScreenState();
}

class _MemorizationScreenState extends State<MemorizationScreen> {
  final QuranRepository _repository = QuranRepository();

  late Future<List<QuranSurah>> _surahsFuture;

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
          return const Center(
            child: CircularProgressIndicator(),
          );
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

        final surahs = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Memorization',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.memorizationState.totalMemorizedAyahs} ayahs memorized',
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.memorizationState.memorizedCount} Surahs started',
                      style: const TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Surahs',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ...surahs.map(_buildSurahCard),
          ],
        );
      },
    );
  }

  Widget _buildSurahCard(QuranSurah surah) {
    final memorizedCount =
        widget.memorizationState.memorizedAyahCountForSurah(
      surah.number,
    );

    final isMemorized = memorizedCount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: CircleAvatar(
          child: Text('${surah.number}'),
        ),
        title: Text(
          surah.nameTransliteration,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          isMemorized
              ? '$memorizedCount / ${surah.ayahCount} ayahs memorized'
              : '${surah.nameArabic} · ${surah.ayahCount} ayahs',
        ),
        trailing: IconButton(
          tooltip: 'Select ayahs',
          icon: Icon(
            isMemorized
                ? Icons.check_circle
                : Icons.add_circle_outline,
          ),
          onPressed: () => _openAyahSelection(surah),
        ),
        onTap: () => _openAyahSelection(surah),
      ),
    );
  }
}
