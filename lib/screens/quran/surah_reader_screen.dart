import 'package:flutter/material.dart';

import '../../models/quran_models.dart';

class SurahReaderScreen extends StatelessWidget {
  final QuranSurah surah;

  const SurahReaderScreen({
    super.key,
    required this.surah,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(surah.nameEnglish),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: surah.ayahs.length,
        itemBuilder: (context, index) {
          final ayah = surah.ayahs[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              ayah.arabicText,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 25,
                height: 2,
              ),
            ),
          );
        },
      ),
    );
  }
}
