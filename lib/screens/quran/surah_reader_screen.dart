import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/quran_reciter_repository.dart';
import '../../models/audio/quran_reciter.dart';
import '../../models/quran_models.dart';
import '../../state/audio/quran_audio_controller.dart';
import '../../state/quran_reading_state.dart';
import '../../state/quran_settings_state.dart';
import '../../widgets/quran/quran_audio_player.dart';

class SurahReaderScreen extends StatefulWidget {
  final QuranSurah surah;
  final QuranAudioController audioController;
  final QuranReadingState readingState;
  final QuranSettingsState settingsState;
  final List<QuranReciter> reciters;

  const SurahReaderScreen({
    super.key,
    required this.surah,
    required this.audioController,
    required this.readingState,
    required this.settingsState,
    required this.reciters,
  });

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  static const String _bismillah = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

  final ScrollController _scrollController = ScrollController();
  final QuranReciterRepository _reciterRepository = QuranReciterRepository();

  bool _completedThisVisit = false;

  List<QuranAyahTimestamp> _ayahTimestamps = const [];
  Set<String> _availableReciterIds = const {};
  int? _activeAyahNumber;
  int _audioRequestId = 0;

  StreamSubscription<Duration>? _positionSubscription;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_handleScroll);

    widget.readingState.markStarted(widget.surah.number);

    _positionSubscription = widget.audioController.positionStream.listen(
      _handleAudioPosition,
    );

    _loadInitialReciter();
  }

  List<QuranReciter> get _enabledReciters {
    return widget.reciters
        .where(
          (reciter) =>
              widget.settingsState.isReciterEnabled(reciter.id) &&
              _availableReciterIds.contains(reciter.id),
        )
        .toList();
  }

  Future<void> _loadInitialReciter() async {
    try {
      final availableIds = await _reciterRepository
          .getAvailableReciterIdsForSurah(widget.surah.number);

      if (!mounted) {
        return;
      }

      setState(() {
        _availableReciterIds = availableIds;
      });

      final enabledReciters = _enabledReciters;

      if (enabledReciters.isEmpty) {
        await widget.audioController.clearSource();
        return;
      }

      QuranReciter selected = enabledReciters.first;

      final defaultId = widget.settingsState.defaultReciterId;

      if (defaultId != null) {
        for (final reciter in enabledReciters) {
          if (reciter.id == defaultId) {
            selected = reciter;
            break;
          }
        }
      }

      widget.audioController.setReciter(selected);
      await _loadReciterAudio(selected, showUnavailableMessage: false);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _availableReciterIds = const {};
      });

      await widget.audioController.clearSource();
    }
  }

  Future<void> _loadReciterAudio(
    QuranReciter reciter, {
    required bool showUnavailableMessage,
  }) async {
    final requestId = ++_audioRequestId;

    if (mounted) {
      setState(() {
        _ayahTimestamps = const [];
        _activeAyahNumber = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        _reciterRepository.getSurahAudioUrl(
          reciterId: reciter.id,
          surahNumber: widget.surah.number,
        ),
        _reciterRepository.getAyahTimestamps(
          reciterId: reciter.id,
          surahNumber: widget.surah.number,
        ),
      ]);

      if (!mounted || requestId != _audioRequestId) {
        return;
      }

      final audioUrl = results[0] as String?;
      final timestamps = results[1] as List<QuranAyahTimestamp>;

      if (audioUrl == null || audioUrl.trim().isEmpty) {
        await widget.audioController.clearSource();

        if (!mounted || requestId != _audioRequestId) {
          return;
        }

        if (showUnavailableMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${reciter.name} does not have audio for this Surah yet.',
              ),
            ),
          );
        }

        return;
      }

      await widget.audioController.setSource(
        surahNumber: widget.surah.number,
        audioUrl: audioUrl,
      );

      if (!mounted || requestId != _audioRequestId) {
        return;
      }

      setState(() {
        _ayahTimestamps = timestamps;
        _activeAyahNumber = null;
      });
    } catch (_) {
      if (!mounted || requestId != _audioRequestId) {
        return;
      }

      await widget.audioController.clearSource();

      if (mounted && requestId == _audioRequestId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to load reciter audio right now.'),
          ),
        );
      }
    }
  }

  void _handleAudioPosition(Duration position) {
    if (!mounted || _ayahTimestamps.isEmpty) {
      return;
    }

    final positionMs = position.inMilliseconds;
    int? activeAyah;

    for (final timestamp in _ayahTimestamps) {
      final afterStart = positionMs >= timestamp.startMs;
      final beforeEnd =
          timestamp.endMs == null || positionMs < timestamp.endMs!;

      if (afterStart && beforeEnd) {
        activeAyah = timestamp.ayahNumber;
        break;
      }
    }

    if (_activeAyahNumber == activeAyah) {
      return;
    }

    setState(() {
      _activeAyahNumber = activeAyah;
    });
  }

  Future<void> _selectReciter(QuranReciter reciter) async {
    widget.audioController.setReciter(reciter);

    await _loadReciterAudio(reciter, showUnavailableMessage: true);
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
    _audioRequestId++;
    _positionSubscription?.cancel();
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

      final isActive = ayah.number == _activeAyahNumber;

      ayahSpans.add(
        TextSpan(
          text: '$text ﴿${ayah.number}﴾ ',
          style: isActive
              ? const TextStyle(
                  backgroundColor: Color(0xFFE0F2E9),
                  color: Color(0xFF145A3A),
                )
              : null,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${surah.nameTransliteration} · ${surah.nameArabic}'),
      ),

      // Persistent player. It is outside the scrollable Quran text.
      bottomNavigationBar: QuranAudioPlayer(
        controller: audioController,

        reciters: _enabledReciters,
        onReciterSelected: _selectReciter,
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
                  style: GoogleFonts.amiriQuran(
                    fontSize: widget.settingsState.arabicTextSize + 2,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text.rich(
                TextSpan(children: ayahSpans),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.justify,
                softWrap: true,
                style: GoogleFonts.amiriQuran(
                  fontSize: widget.settingsState.arabicTextSize,
                  height: 2.05,
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
