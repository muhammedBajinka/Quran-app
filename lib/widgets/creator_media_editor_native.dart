import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class CreatorMediaEditor extends StatefulWidget {
  final Uint8List bytes;
  final String mediaType;
  final String mimeType;
  final String? sourcePath;
  final ValueChanged<RangeValues> onTrimChanged;
  final RangeValues trim;

  const CreatorMediaEditor({super.key, required this.bytes, required this.mediaType, required this.mimeType, required this.sourcePath, required this.trim, required this.onTrimChanged});
  @override State<CreatorMediaEditor> createState() => _CreatorMediaEditorState();
}

class _CreatorMediaEditorState extends State<CreatorMediaEditor> {
  VideoPlayerController? _video;
  AudioPlayer? _audio;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;
  String? _error;
  RangeValues _trim = const RangeValues(0, 1);
  double get _durationMs => _duration.inMilliseconds.toDouble();

  @override void initState() { super.initState(); _initialise(); }

  Future<void> _initialise() async {
    try {
      final path = widget.sourcePath;
      if (path == null || path.isEmpty) {
        throw StateError('Selected media has no local path.');
      }
      if (widget.mediaType == 'video') {
        final controller = VideoPlayerController.file(File(path));
        await controller.initialize();
        controller.addListener(_onVideoTick);
        _video = controller;
        _duration = controller.value.duration;
      } else {
        final player = AudioPlayer();
        _audio = player;
        await player.setSource(DeviceFileSource(path));
        _duration = (await player.getDuration()) ?? Duration.zero;
        player.onPositionChanged.listen((value) {
          if (!mounted) return;
          _position = value; _enforceTrimEnd(); setState(() {});
        });
        player.onPlayerStateChanged.listen((state) { if (mounted) setState(() => _playing = state == PlayerState.playing); });
      }
      final end = _durationMs <= 0 ? 1.0 : _durationMs;
      _trim = RangeValues(0, end);
      widget.onTrimChanged(_trim);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = 'This media could not be previewed. Choose another file and try again.');
    }
  }

  void _onVideoTick() {
    final controller = _video;
    if (!mounted || controller == null) return;
    _position = controller.value.position; _playing = controller.value.isPlaying; _enforceTrimEnd(); setState(() {});
  }
  void _enforceTrimEnd() { if (_durationMs > 0 && _position.inMilliseconds >= _trim.end) { _pause(); _seek(_trim.start); } }
  Future<void> _pause() async { if (widget.mediaType == 'video') { await _video?.pause(); } else { await _audio?.pause(); } }
  Future<void> _seek(double ms) async {
    final target = Duration(milliseconds: ms.round());
    if (widget.mediaType == 'video') { await _video?.seekTo(target); } else { await _audio?.seek(target); }
    if (mounted) setState(() => _position = target);
  }
  Future<void> _toggle() async {
    if (_playing) { await _pause(); return; }
    final current = _position.inMilliseconds.toDouble();
    if (current < _trim.start || current >= _trim.end) await _seek(_trim.start);
    if (widget.mediaType == 'video') { await _video?.play(); } else { await _audio?.resume(); }
  }
  void _changeTrim(RangeValues value) { setState(() => _trim = value); widget.onTrimChanged(value); _seek(value.start); }
  String _time(double ms) {
    final seconds = (ms / 1000).round(); final minutes = seconds ~/ 60; final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  @override void dispose() { _video?.removeListener(_onVideoTick); _video?.dispose(); _audio?.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    if (_error != null) return SizedBox.expand(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))));
    if (_durationMs <= 0) return const SizedBox.expand(child: Center(child: CircularProgressIndicator()));
    return Column(children: [
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Container(width: double.infinity, color: const Color(0xFF111111), child: widget.mediaType == 'video' ? _videoPreview() : _audioPreview()))),
      const SizedBox(height: 10),
      Row(children: [IconButton.filled(onPressed: _toggle, icon: Icon(_playing ? Icons.pause : Icons.play_arrow)), const SizedBox(width: 8), Text(_time(_trim.start)), const Spacer(), Text('${_time(_trim.end)} · ${_time(_trim.end - _trim.start)} selected')]),
      RangeSlider(values: _trim, min: 0, max: _durationMs, labels: RangeLabels(_time(_trim.start), _time(_trim.end)), onChanged: _changeTrim),
      const Text('Drag either end to choose exactly what will be uploaded.', style: TextStyle(color: Colors.black54, fontSize: 12)),
    ]);
  }

  Widget _videoPreview() {
    final controller = _video;
    if (controller == null || !controller.value.isInitialized) return const Center(child: CircularProgressIndicator());
    return Stack(fit: StackFit.expand, children: [
      Center(child: AspectRatio(aspectRatio: controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 9 / 16, child: VideoPlayer(controller))),
      Center(child: IconButton.filledTonal(onPressed: _toggle, iconSize: 34, icon: Icon(_playing ? Icons.pause : Icons.play_arrow))),
    ]);
  }
  Widget _audioPreview() => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.graphic_eq, color: Colors.white, size: 70), const SizedBox(height: 16),
    const Text('Audio preview', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)), const SizedBox(height: 8),
    Text(_time(_position.inMilliseconds.toDouble()), style: const TextStyle(color: Colors.white70)),
  ]);
}
