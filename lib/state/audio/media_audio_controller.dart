import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/audio/media_item.dart';
import '../../services/error_report_service.dart';

class MediaAudioController extends ChangeNotifier with WidgetsBindingObserver {
  final AudioPlayer _player;

  MediaAudioController({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  MediaItem? _currentItem;
  MediaItem? _requestedItem;
  bool _repeatEnabled = false;
  bool _wantsPlayback = false;
  bool _foreground = true;
  bool _disposed = false;
  double _speed = 1.0;
  int _playRequest = 0;
  Future<void> _loadTail = Future<void>.value();

  AudioPlayer get player => _player;
  MediaItem? get currentItem => _currentItem;
  bool get repeatEnabled => _repeatEnabled;
  double get speed => _speed;
  bool get hasCurrentItem => _currentItem != null;

  bool _canPlay(int request) =>
      !_disposed && _foreground && _wantsPlayback && request == _playRequest;

  void _startPlayback(int request) {
    if (!_canPlay(request)) return;
    // play completes when playback ends; do not block the source queue on it.
    unawaited(_player.play().catchError((Object error) {
      if (_canPlay(request)) {
        unawaited(ErrorReportService.report('AUDIO_PLAYBACK_FAILED', error: error));
      }
    }));
  }

  Future<void> playItem(MediaItem item) {
    if (_disposed || !item.hasAudio) return Future<void>.value();
    _requestedItem = item;
    _wantsPlayback = true;
    final request = ++_playRequest;
    if (!_foreground) return Future<void>.value();
    // Serialize sources so an old setUrl cannot replace the visible clip.
    final operation = _loadTail.then((_) async {
      if (!_canPlay(request)) return;
      if (_currentItem?.id != item.id) {
        _currentItem = null;
        notifyListeners();
        await _player.stop();
        if (!_canPlay(request)) return;
        await _player.setUrl(item.audioUrl!);
        if (!_canPlay(request)) return;
        _currentItem = item;
        notifyListeners();
      }
      if (!_canPlay(request)) return;
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      _startPlayback(request);
    });
    // A failed source must not poison the queue for later clips.
    _loadTail = operation.catchError((Object error) {
      if (_canPlay(request)) {
        unawaited(ErrorReportService.report('AUDIO_PLAYBACK_FAILED', error: error));
      }
    });
    return operation;
  }

  Future<void> play() async {
    final item = _requestedItem ?? _currentItem;
    if (item == null || _disposed) return;
    await playItem(item);
  }

  Future<void> pause() async {
    if (_disposed) return;
    _wantsPlayback = false;
    ++_playRequest;
    await _pauseAndDrain();
  }

  Future<void> _pauseAndDrain() {
    final pause = _player.pause();
    // Pause immediately, but make a new source wait for its native acknowledgement.
    _loadTail = Future.wait<void>([_loadTail, pause]).then((_) {}).catchError(
      (Object error) {
        unawaited(ErrorReportService.report('AUDIO_PAUSE_FAILED', error: error));
      },
    );
    return pause;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    _foreground = foreground;
    if (!foreground) {
      ++_playRequest;
      unawaited(_pauseAndDrain().catchError((Object error) {
        unawaited(ErrorReportService.report('AUDIO_PAUSE_FAILED', error: error));
      }));
    } else if (_wantsPlayback && _requestedItem != null) {
      unawaited(playItem(_requestedItem!).catchError((Object error) {
        unawaited(ErrorReportService.report('AUDIO_PLAYBACK_FAILED', error: error));
      }));
    }
  }

  Future<void> seek(Duration position) async {
    if (!_disposed) await _player.seek(position);
  }

  Future<void> toggleRepeat() async {
    if (_disposed) return;
    final enabled = !_repeatEnabled;
    await _player.setLoopMode(enabled ? LoopMode.one : LoopMode.off);
    if (_disposed) return;
    _repeatEnabled = enabled;
    notifyListeners();
  }

  Future<void> setSpeed(double value) async {
    if (_disposed) return;
    await _player.setSpeed(value);
    if (_disposed) return;
    _speed = value;
    notifyListeners();
  }

  Future<void> close() {
    if (_disposed) return Future<void>.value();
    _wantsPlayback = false;
    _requestedItem = null;
    final request = ++_playRequest;
    final operation = _loadTail.then((_) async {
      if (_disposed || request != _playRequest) return;
      await _player.stop();
      if (_disposed || request != _playRequest) return;
      _currentItem = null;
      notifyListeners();
    });
    _loadTail = operation.catchError((Object error) {
      unawaited(ErrorReportService.report('AUDIO_STOP_FAILED', error: error));
    });
    return operation;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _wantsPlayback = false;
    ++_playRequest;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_player.dispose());
    super.dispose();
  }
}
