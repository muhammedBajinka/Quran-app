import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/quran_models.dart';

class SurahReaderScreen extends StatelessWidget {
  final QuranSurah surah;

  const SurahReaderScreen({super.key, required this.surah});

  static const String _bismillah = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

  @override
  Widget build(BuildContext context) {
    final hasSeparateBismillah = surah.number != 1 && surah.number != 9;

    final ayahSpans = <InlineSpan>[];

    for (int index = 0; index < surah.ayahs.length; index++) {
      final ayah = surah.ayahs[index];

      String text = ayah.arabicText;

      // Surahs 2–114 (except 9) store the Bismillah
      // together with Ayah 1. Display it separately above.
      if (hasSeparateBismillah && index == 0) {
        text = text.replaceFirst(_bismillah, '').trim();
      }

      ayahSpans.add(TextSpan(text: '$text ﴿${ayah.number}﴾ '));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${surah.nameTransliteration} · ${surah.nameArabic}',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasSeparateBismillah) ...[
                Text(
                  _bismillah,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.amiriQuran(fontSize: 27, height: 1.7),
                ),
                const SizedBox(height: 20),
              ],
              Text.rich(
                TextSpan(children: ayahSpans),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.justify,
                softWrap: true,
                style: GoogleFonts.amiriQuran(fontSize: 25, height: 2.05),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
