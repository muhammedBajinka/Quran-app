import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/audio/media_item.dart';

class MediaAudioController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  MediaItem? _currentItem;
  bool _repeatEnabled = false;
  double _speed = 1.0;

  AudioPlayer get player => _player;

  MediaItem? get currentItem => _currentItem;

  bool get repeatEnabled => _repeatEnabled;

  double get speed => _speed;

  bool get hasCurrentItem => _currentItem != null;

  Future<void> playItem(MediaItem item) async {
    if (!item.hasAudio) {
      return;
    }

    final isNewItem = _currentItem?.id != item.id;

    if (isNewItem) {
      await _player.stop();
      await _player.setUrl(item.audioUrl!);
      _currentItem = item;
      notifyListeners();
    }

    await _player.play();
  }

  Future<void> play() async {
    if (_currentItem == null) {
      return;
    }

    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> toggleRepeat() async {
    _repeatEnabled = !_repeatEnabled;

    await _player.setLoopMode(_repeatEnabled ? LoopMode.one : LoopMode.off);

    notifyListeners();
  }

  Future<void> setSpeed(double value) async {
    _speed = value;
    await _player.setSpeed(value);
    notifyListeners();
  }

  Future<void> close() async {
    await _player.stop();
    _currentItem = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
