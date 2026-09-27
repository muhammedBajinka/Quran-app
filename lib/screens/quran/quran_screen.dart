import 'package:flutter/material.dart';

import '../../data/quran_repository.dart';
import '../../models/quran_models.dart';
import '../../state/memorization_state.dart';
import '../../state/audio/quran_audio_controller.dart';
import 'surah_reader_screen.dart';

class QuranScreen extends StatefulWidget {
  final MemorizationState memorizationState;
  final QuranAudioController audioController;

  const QuranScreen({
    super.key,
    required this.memorizationState,
    required this.audioController,
  });

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final QuranRepository _repository = QuranRepository();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<QuranSurah>> _surahsFuture;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _surahsFuture = _repository.loadSurahs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QuranSurah> _filterSurahs(List<QuranSurah> surahs) {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return surahs;
    }

    return surahs.where((surah) {
      return surah.number.toString().contains(query) ||
          surah.nameTransliteration.toLowerCase().contains(query) ||
          surah.nameArabic.contains(query);
    }).toList();
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load the Quran data.\n\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final surahs = snapshot.data;

        if (surahs == null || surahs.isEmpty) {
          return const Center(
            child: Text('No Quran data found.'),
          );
        }

        final filteredSurahs = _filterSurahs(surahs);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search Surah by name or number',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF5F7F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: filteredSurahs.isEmpty
                  ? const Center(
                      child: Text('No Surahs found.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: filteredSurahs.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final surah = filteredSurahs[index];
                        final isMemorized =
                            widget.memorizationState.isMemorized(
                          surah.number,
                        );

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 6,
                          ),
                          leading: CircleAvatar(
                            backgroundColor:
                                const Color(0xFFE8F3EE),
                            foregroundColor:
                                const Color(0xFF2E7D5B),
                            child: Text('${surah.number}'),
                          ),
                          title: Text(
                            '${surah.number} · ${surah.nameTransliteration} · ${surah.nameArabic}',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${surah.ayahCount} Ayahs',
                          ),
                          trailing: IconButton(
                            tooltip: isMemorized
                                ? 'Remove from memorization'
                                : 'Mark for memorization',
                            icon: Icon(
                              isMemorized
                                  ? Icons.bookmark
                                  : Icons.bookmark_outline,
                              color: isMemorized
                                  ? const Color(0xFF2E7D5B)
                                  : null,
                            ),
                            onPressed: () {
                              widget.memorizationState
                                  .toggleMemorized(surah.number);
                            },
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    SurahReaderScreen(
                                      surah: surah,
                                      audioController: widget.audioController,
                                    ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
