import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/audio/media_item.dart';

class MediaAudioController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  MediaItem? _currentItem;
  bool _repeatEnabled = false;
  double _speed = 1.0;
  int _playRequest = 0;

  AudioPlayer get player => _player;

  MediaItem? get currentItem => _currentItem;

  bool get repeatEnabled => _repeatEnabled;

  double get speed => _speed;

  bool get hasCurrentItem => _currentItem != null;

  Future<void> playItem(MediaItem item) async {
    if (!item.hasAudio) return;
    final request = ++_playRequest;
    final isNewItem = _currentItem?.id != item.id;
    if (isNewItem) {
      await _player.stop();
      if (request != _playRequest) return;
      await _player.setUrl(item.audioUrl!);
      if (request != _playRequest) return;
      _currentItem = item;
      notifyListeners();
    }
    if (request != _playRequest) return;
    // AudioPlayer.play() completes when playback ends, not when it starts.
    // Do not await it here: page navigation must not wait for the whole clip.
    _player.play();
  }

  Future<void> play() async {
    if (_currentItem == null) {
      return;
    }

    await _player.play();
  }

  Future<void> pause() async {
    ++_playRequest;
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
    ++_playRequest;
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
