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
      if (widget.mediaType == 'audio') {
        final player = AudioPlayer();
        _audio = player;
        await player.setSource(BytesSource(widget.bytes, mimeType: widget.mimeType));
        _duration = (await player.getDuration()) ?? Duration.zero;
        player.onPositionChanged.listen((value) {
          if (!mounted) return;
          _position = value;
          if (_durationMs > 0 && _position.inMilliseconds >= _trim.end) {
            player.pause();
            player.seek(Duration(milliseconds: _trim.start.round()));
          }
          setState(() {});
        });
        player.onPlayerStateChanged.listen((state) {
          if (mounted) setState(() => _playing = state == PlayerState.playing);
        });
        _trim = RangeValues(0, _durationMs <= 0 ? 1 : _durationMs);
        widget.onTrimChanged(_trim);
        if (mounted) setState(() {});
        return;
      }
      final controller = VideoPlayerController.networkUrl(
        Uri.dataFromBytes(widget.bytes, mimeType: widget.mimeType),
      );
      await controller.initialize();
      controller.addListener(_tick);
      _video = controller;
      _duration = controller.value.duration;
      _trim = RangeValues(0, _durationMs <= 0 ? 1 : _durationMs);
      widget.onTrimChanged(_trim);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = 'This media could not be previewed in the browser.');
    }
  }

  void _tick() {
    final controller = _video;
    if (!mounted || controller == null) return;
    _position = controller.value.position;
    _playing = controller.value.isPlaying;
    if (_durationMs > 0 && _position.inMilliseconds >= _trim.end) {
      controller.pause();
      controller.seekTo(Duration(milliseconds: _trim.start.round()));
    }
    setState(() {});
  }

  Future<void> _toggle() async {
    if (widget.mediaType == 'audio') {
      final player = _audio;
      if (player == null) return;
      if (_playing) {
        await player.pause();
        return;
      }
      final current = _position.inMilliseconds.toDouble();
      if (current < _trim.start || current >= _trim.end) {
        await player.seek(Duration(milliseconds: _trim.start.round()));
      }
      await player.resume();
      return;
    }
    final controller = _video;
    if (controller == null) return;
    if (controller.value.isPlaying) { await controller.pause(); return; }
    final current = controller.value.position.inMilliseconds.toDouble();
    if (current < _trim.start || current >= _trim.end) {
      await controller.seekTo(Duration(milliseconds: _trim.start.round()));
    }
    await controller.play();
  }

  void _changeTrim(RangeValues value) {
    final startMoved = (value.start - _trim.start).abs();
    final endMoved = (value.end - _trim.end).abs();
    final seekMs = startMoved >= endMoved ? value.start : value.end;
    setState(() => _trim = value);
    widget.onTrimChanged(value);
    final target = Duration(milliseconds: seekMs.round());
    if (widget.mediaType == 'audio') {
      _audio?.seek(target);
    } else {
      _video?.seekTo(target);
    }
  }

  String _time(double ms) {
    final seconds = (ms / 1000).round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override void dispose() { _video?.removeListener(_tick); _video?.dispose(); _audio?.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    if (_error != null) return SizedBox.expand(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))));
    if (_durationMs <= 0 || (widget.mediaType == 'video' && _video == null) || (widget.mediaType == 'audio' && _audio == null)) return const SizedBox.expand(child: Center(child: CircularProgressIndicator()));
    return Column(children: [
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Container(
        width: double.infinity,
        color: const Color(0xFF111111),
        child: widget.mediaType == 'video'
            ? Stack(fit: StackFit.expand, children: [
                Center(child: AspectRatio(aspectRatio: _video!.value.aspectRatio > 0 ? _video!.value.aspectRatio : 9 / 16, child: VideoPlayer(_video!))),
                Center(child: IconButton.filledTonal(onPressed: _toggle, iconSize: 34, icon: Icon(_playing ? Icons.pause : Icons.play_arrow))),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.graphic_eq, color: Colors.white, size: 70),
                const SizedBox(height: 16),
                const Text('Audio preview', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(_time(_position.inMilliseconds.toDouble()), style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                IconButton.filledTonal(onPressed: _toggle, iconSize: 34, icon: Icon(_playing ? Icons.pause : Icons.play_arrow)),
              ]),
      ))),
      const SizedBox(height: 10),
      Row(children: [IconButton.filled(onPressed: _toggle, icon: Icon(_playing ? Icons.pause : Icons.play_arrow)), const SizedBox(width: 8), Text(_time(_trim.start)), const Spacer(), Text('${_time(_trim.end)} · ${_time(_trim.end - _trim.start)} selected')]),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 6,
          rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 11),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          activeTrackColor: const Color(0xFF2E7D5B),
          thumbColor: const Color(0xFF2E7D5B),
        ),
        child: RangeSlider(values: _trim, min: 0, max: _durationMs, labels: RangeLabels(_time(_trim.start), _time(_trim.end)), onChanged: _changeTrim),
      ),
      const Text('Drag either end to choose exactly what will be uploaded.', style: TextStyle(color: Colors.black54, fontSize: 12)),
    ]);
  }
}
