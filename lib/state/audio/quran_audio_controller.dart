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

  bool get isPlaying => _player.playing;

  AudioPlayer get player => _player;

  void setReciter(QuranReciter reciter) {
    _selectedReciter = reciter;
    notifyListeners();
  }

  void setSource({
    required int surahNumber,
    required String audioUrl,
  }) {
    _surahNumber = surahNumber;
    _ayahNumber = 1;
    _audioUrl = audioUrl;
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
