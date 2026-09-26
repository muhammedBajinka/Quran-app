import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/quran_models.dart';

class QuranRepository {
  static const String _assetPath = 'assets/quran/quran.json';

  Future<List<QuranSurah>> loadSurahs() async {
    final jsonString = await rootBundle.loadString(_assetPath);
    final Map<String, dynamic> data = jsonDecode(jsonString);

    final surahData = data['surahs'] as List<dynamic>;

    return surahData.map((item) {
      final surah = item as Map<String, dynamic>;
      final ayahData = surah['ayahs'] as List<dynamic>;

      final ayahs = ayahData.map((item) {
        final ayah = item as Map<String, dynamic>;

        return QuranAyah(
          number: ayah['number'] as int,
          surahNumber: surah['number'] as int,
          ayahNumber: ayah['number'] as int,
          arabicText: ayah['arabicText'] as String,
        );
      }).toList();

      return QuranSurah(
        number: surah['number'] as int,
        nameArabic: surah['nameArabic'] as String,
        nameEnglish: surah['nameEnglish'] as String,
        ayahCount: surah['ayahCount'] as int,
        ayahs: ayahs,
      );
    }).toList();
  }

  Future<List<QuranJuz>> loadJuzs() async {
    final jsonString = await rootBundle.loadString(_assetPath);
    final Map<String, dynamic> data = jsonDecode(jsonString);

    final juzData = data['juzs'] as List<dynamic>;

    return juzData.map((item) {
      final juz = item as Map<String, dynamic>;

      return QuranJuz(
        number: juz['number'] as int,
        name: juz['name'] as String,
        startSurahNumber: juz['startSurahNumber'] as int,
        startAyahNumber: juz['startAyahNumber'] as int,
      );
    }).toList();
  }
}
