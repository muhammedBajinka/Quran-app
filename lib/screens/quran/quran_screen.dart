import 'package:flutter/material.dart';

import '../../data/quran_repository.dart';
import '../../models/quran_models.dart';
import 'surah_reader_screen.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final QuranRepository _repository = QuranRepository();

  late Future<List<QuranSurah>> _surahsFuture;

  @override
  void initState() {
    super.initState();
    _surahsFuture = _repository.loadSurahs();
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

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: surahs.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final surah = surahs[index];

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFE8F3EE),
                foregroundColor: const Color(0xFF2E7D5B),
                child: Text('${surah.number}'),
              ),
              title: Text(
                surah.nameEnglish,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text('${surah.ayahCount} Ayahs'),
              trailing: Text(
                surah.nameArabic,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SurahReaderScreen(surah: surah),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
