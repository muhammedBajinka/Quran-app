import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/audio/quran_reciter.dart';

class QuranAudioController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  QuranReciter? _selectedReciter;
  int? _surahNumber;
  int? _ayahNumber;
  String? _audioUrl;

  QuranReciter? get selectedReciter => _selectedReciter;
  int? get surahNumber => _surahNumber;
  int? get ayahNumber => _ayahNumber;
  String? get audioUrl => _audioUrl;
  Stream<Duration> get positionStream => _player.positionStream;

  bool get isPlaying => _player.playing;

  AudioPlayer get player => _player;

  void setReciter(QuranReciter reciter) {
    _selectedReciter = reciter;
    notifyListeners();
  }

  Future<void> setSource({
    required int surahNumber,
    required String audioUrl,
  }) async {
    final sourceChanged = _surahNumber != surahNumber || _audioUrl != audioUrl;

    _surahNumber = surahNumber;
    _ayahNumber = 1;
    _audioUrl = audioUrl;

    if (sourceChanged) {
      await _player.stop();
      await _player.setUrl(audioUrl);
    }

    notifyListeners();
  }

  Future<void> clearSource() async {
    _surahNumber = null;
    _ayahNumber = null;
    _audioUrl = null;

    await _player.stop();
    notifyListeners();
  }

  Future<void> play() async {
    if (_audioUrl == null || _audioUrl!.isEmpty) {
      return;
    }

    if (_player.audioSource == null) {
      await _player.setUrl(_audioUrl!);
    }

    await _player.play();
    notifyListeners();
  }

  Future<void> playAyah({required int ayahNumber, required int startMs}) async {
    if (_audioUrl == null || _audioUrl!.isEmpty) {
      return;
    }

    if (_player.audioSource == null) {
      await _player.setUrl(_audioUrl!);
    }

    _ayahNumber = ayahNumber;

    await _player.seek(Duration(milliseconds: startMs));
    await _player.play();

    notifyListeners();
  }

  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
