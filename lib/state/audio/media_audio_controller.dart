import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/audio/media_item.dart';

class MediaAudioController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  MediaItem? _currentItem;
  bool _repeatEnabled = false;
  double _speed = 1.0;
  int _playRequest = 0;
  Future<void> _loadTail = Future<void>.value();

  AudioPlayer get player => _player;

  MediaItem? get currentItem => _currentItem;

  bool get repeatEnabled => _repeatEnabled;

  double get speed => _speed;

  bool get hasCurrentItem => _currentItem != null;

  Future<void> playItem(MediaItem item) {
    if (!item.hasAudio) return Future<void>.value();
    final request = ++_playRequest;
    // Serialize source changes. A stale setUrl must finish before a newer one
    // starts, otherwise it can replace the newly visible clip's source.
    final operation = _loadTail.then((_) async {
      if (request != _playRequest) return;
      if (_currentItem?.id != item.id) {
        _currentItem = null;
        notifyListeners();
        await _player.stop();
        if (request != _playRequest) return;
        await _player.setUrl(item.audioUrl!);
        if (request != _playRequest) return;
        _currentItem = item;
        notifyListeners();
      }
      if (request != _playRequest) return;
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      if (request == _playRequest) _player.play();
    });
    // A failed source must not poison the queue for later clips.
    _loadTail = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> play() async {
    if (_currentItem == null) {
      return;
    }

    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    _player.play();
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
    ++_playRequest;
    _player.dispose();
    super.dispose();
  }
}
