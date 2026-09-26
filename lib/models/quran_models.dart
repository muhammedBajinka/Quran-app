class QuranAyah {
  final int number;
  final int surahNumber;
  final int ayahNumber;
  final String arabicText;

  const QuranAyah({
    required this.number,
    required this.surahNumber,
    required this.ayahNumber,
    required this.arabicText,
  });
}

class QuranSurah {
  final int number;
  final String nameArabic;
  final String nameEnglish;
  final String nameTransliteration;
  final int ayahCount;
  final List<QuranAyah> ayahs;

  const QuranSurah({
    required this.number,
    required this.nameArabic,
    required this.nameEnglish,
    required this.nameTransliteration,
    required this.ayahCount,
    required this.ayahs,
  });
}

class QuranJuz {
  final int number;
  final String name;
  final int startSurahNumber;
  final int startAyahNumber;

  const QuranJuz({
    required this.number,
    required this.name,
    required this.startSurahNumber,
    required this.startAyahNumber,
  });
}
