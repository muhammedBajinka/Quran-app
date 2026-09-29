import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/quran_models.dart';
import '../../state/audio/quran_audio_controller.dart';
import '../../state/quran_reading_state.dart';
import '../../widgets/quran/quran_audio_player.dart';

class SurahReaderScreen extends StatefulWidget {
  final QuranSurah surah;
  final QuranAudioController audioController;
  final QuranReadingState readingState;

  const SurahReaderScreen({
    super.key,
    required this.surah,
    required this.audioController,
    required this.readingState,
  });

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  static const String _bismillah = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

  final ScrollController _scrollController = ScrollController();

  bool _completedThisVisit = false;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_handleScroll);

    widget.readingState.markStarted(widget.surah.number);
  }

  void _handleScroll() {
    if (_completedThisVisit || !_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;

    if (position.maxScrollExtent <= 0) {
      return;
    }

    if (position.pixels >= position.maxScrollExtent - 8) {
      _completedThisVisit = true;
      widget.readingState.markCompleted(widget.surah.number);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surah = widget.surah;
    final audioController = widget.audioController;

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
        title: Text('${surah.nameTransliteration} · ${surah.nameArabic}'),
      ),

      // Persistent player. It is outside the scrollable Quran text.
      bottomNavigationBar: QuranAudioPlayer(
        controller: audioController,

        // This will be populated from the admin/backend reciter data.
        reciters: const [],
      ),

      body: SingleChildScrollView(
        controller: _scrollController,
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
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
