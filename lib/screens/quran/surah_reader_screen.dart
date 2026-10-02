import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/global_quran_audio.dart';
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
  final GlobalKey _quranTextKey = GlobalKey();
  final Map<int, TapGestureRecognizer> _ayahTapRecognizers = {};
  final Map<int, TextSpan> _ayahTextSpans = {};
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
              (GlobalQuranAudio.hasSurah(reciter, widget.surah.number) ||
                  _availableReciterIds.contains(reciter.id)),
        )
        .toList();
  }

  Future<void> _loadInitialReciter() async {
    Set<String> availableIds = const {};

    try {
      availableIds = await _reciterRepository.getAvailableReciterIdsForSurah(
        widget.surah.number,
      );
    } catch (_) {
      // Global reciters do not depend on the backend.
    }

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
      String? audioUrl;
      List<QuranAyahTimestamp> timestamps = const [];

      if (GlobalQuranAudio.supports(reciter)) {
        audioUrl = GlobalQuranAudio.audioUrl(reciter, widget.surah.number);

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

        // Load the verified Surah MP3 first. Timing data is optional and
        // must never prevent normal Surah playback.
        await widget.audioController.setSource(
          surahNumber: widget.surah.number,
          audioUrl: audioUrl,
        );

        if (!mounted || requestId != _audioRequestId) {
          return;
        }

        if (GlobalQuranAudio.hasAyahTiming(reciter)) {
          timestamps = await GlobalQuranAudio.getAyahTimestamps(
            reciter,
            widget.surah.number,
          );
        }
      } else {
        // Custom reciters: audio is required, timestamps are optional.
        //
        // Load the Surah audio first so missing or broken timestamp data can
        // never prevent normal Surah playback.
        audioUrl = await _reciterRepository.getSurahAudioUrl(
          reciterId: reciter.id,
          surahNumber: widget.surah.number,
        );

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

        try {
          timestamps = await _reciterRepository.getAyahTimestamps(
            reciterId: reciter.id,
            surahNumber: widget.surah.number,
          );
        } catch (error, stackTrace) {
          // Timestamp failure must never disable working custom audio.
          debugPrint(
            'Custom reciter timing error | '
            'reciter=${reciter.id} | '
            'surah=${widget.surah.number} | '
            'error=$error',
          );
          debugPrintStack(stackTrace: stackTrace);
          timestamps = const [];
        }
      }

      if (!mounted || requestId != _audioRequestId) {
        return;
      }

      setState(() {
        _ayahTimestamps = timestamps;
        _activeAyahNumber = null;
      });

      if (GlobalQuranAudio.hasAyahTiming(reciter) &&
          timestamps.isEmpty &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${reciter.name} audio loaded, but ayah timing could not be loaded.',
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Quran audio error | '
        'reciter=${reciter.id} | '
        'surah=${widget.surah.number} | '
        'error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted || requestId != _audioRequestId) {
        return;
      }

      await widget.audioController.clearSource();

      if (!mounted || requestId != _audioRequestId) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Audio error for ${reciter.name}: $error'),
          duration: const Duration(seconds: 15),
        ),
      );
    }
  }

  Future<void> _playAyah(int ayahNumber) async {
    QuranAyahTimestamp? timestamp;

    for (final item in _ayahTimestamps) {
      if (item.ayahNumber == ayahNumber) {
        timestamp = item;
        break;
      }
    }

    if (timestamp == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ayah-by-ayah playback is not available for this reciter.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _activeAyahNumber = ayahNumber;
    });

    await widget.audioController.playAyah(
      ayahNumber: ayahNumber,
      startMs: timestamp.startMs,
    );
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

    if (activeAyah != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveAyah(activeAyah!);
      });
    }
  }

  void _scrollToActiveAyah(int ayahNumber) {
    if (!mounted || _ayahTimestamps.isEmpty || !_scrollController.hasClients) {
      return;
    }

    final textSpan = _ayahTextSpans[ayahNumber];
    final context = _quranTextKey.currentContext;

    if (textSpan == null || context == null) {
      return;
    }

    final renderObject = context.findRenderObject();

    if (renderObject is! RenderParagraph) {
      return;
    }

    final ayahLocalY = _verticalPositionForSpan(renderObject, textSpan);
    final paragraphBox = renderObject.localToGlobal(Offset.zero);
    final ayahScreenY = paragraphBox.dy + ayahLocalY;

    final screenHeight = MediaQuery.sizeOf(context).height;
    final comfortableTop = screenHeight * 0.30;
    final comfortableBottom = screenHeight * 0.62;

    if (ayahScreenY >= comfortableTop && ayahScreenY <= comfortableBottom) {
      return;
    }

    final desiredY = screenHeight * 0.46;
    final difference = ayahScreenY - desiredY;

    final position = _scrollController.position;
    final target = (position.pixels + difference).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    _scrollController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  double _verticalPositionForSpan(
    RenderParagraph paragraph,
    TextSpan targetSpan,
  ) {
    final fullText = paragraph.text.toPlainText();
    final targetText = targetSpan.toPlainText();

    if (targetText.isEmpty) {
      return 0;
    }

    int offset = 0;

    for (final span in _ayahTextSpans.values) {
      if (identical(span, targetSpan)) {
        break;
      }

      offset += span.toPlainText().length;
    }

    if (offset >= fullText.length) {
      return 0;
    }

    final end = (offset + 1).clamp(0, fullText.length);

    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: offset, extentOffset: end),
    );

    if (boxes.isEmpty) {
      return 0;
    }

    return boxes.first.top + (boxes.first.bottom - boxes.first.top) / 2;
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

    for (final recognizer in _ayahTapRecognizers.values) {
      recognizer.dispose();
    }
    _ayahTapRecognizers.clear();

    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surah = widget.surah;
    final audioController = widget.audioController;

    final hasSeparateBismillah = surah.number != 1 && surah.number != 9;

    final ayahSpans = <InlineSpan>[];
    _ayahTextSpans.clear();

    for (int index = 0; index < surah.ayahs.length; index++) {
      final ayah = surah.ayahs[index];

      String text = ayah.arabicText;

      // Surahs 2–114 (except 9) store the Bismillah
      // together with Ayah 1. Display it separately above.
      if (hasSeparateBismillah && index == 0) {
        text = text.replaceFirst(_bismillah, '').trim();
      }

      final isActive = ayah.number == _activeAyahNumber;

      final recognizer = _ayahTapRecognizers.putIfAbsent(
        ayah.number,
        () => TapGestureRecognizer(),
      );

      recognizer.onTap = () {
        _playAyah(ayah.number);
      };

      final ayahSpan = TextSpan(
        text: '$text ﴿${ayah.number}﴾ ',
        recognizer: recognizer,
        style: isActive
            ? const TextStyle(
                backgroundColor: Color(0xFFE0F2E9),
                color: Color(0xFF145A3A),
              )
            : null,
      );

      _ayahTextSpans[ayah.number] = ayahSpan;
      ayahSpans.add(ayahSpan);
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
                  style: GoogleFonts.notoNaskhArabic(
                    fontSize: widget.settingsState.arabicTextSize + 2,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text.rich(
                TextSpan(children: ayahSpans),
                key: _quranTextKey,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.justify,
                softWrap: true,
                style: GoogleFonts.notoNaskhArabic(
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
