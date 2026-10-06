import 'dart:typed_data';

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
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;
  String? _error;
  RangeValues _trim = const RangeValues(0, 1);
  double get _durationMs => _duration.inMilliseconds.toDouble();

  @override void initState() { super.initState(); _initialise(); }

  Future<void> _initialise() async {
    if (widget.mediaType != 'video') {
      setState(() => _error = 'Audio preview is currently available in the Android app.');
      return;
    }
    try {
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
      if (mounted) setState(() => _error = 'This video could not be previewed in the browser.');
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
    setState(() => _trim = value);
    widget.onTrimChanged(value);
    _video?.seekTo(Duration(milliseconds: value.start.round()));
  }

  String _time(double ms) {
    final seconds = (ms / 1000).round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override void dispose() { _video?.removeListener(_tick); _video?.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    if (_error != null) return SizedBox.expand(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))));
    if (_durationMs <= 0 || _video == null) return const SizedBox.expand(child: Center(child: CircularProgressIndicator()));
    return Column(children: [
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Container(
        width: double.infinity,
        color: const Color(0xFF111111),
        child: Stack(fit: StackFit.expand, children: [
          Center(child: AspectRatio(aspectRatio: _video!.value.aspectRatio > 0 ? _video!.value.aspectRatio : 9 / 16, child: VideoPlayer(_video!))),
          Center(child: IconButton.filledTonal(onPressed: _toggle, iconSize: 34, icon: Icon(_playing ? Icons.pause : Icons.play_arrow))),
        ]),
      ))),
      const SizedBox(height: 10),
      Row(children: [IconButton.filled(onPressed: _toggle, icon: Icon(_playing ? Icons.pause : Icons.play_arrow)), const SizedBox(width: 8), Text(_time(_trim.start)), const Spacer(), Text('${_time(_trim.end)} · ${_time(_trim.end - _trim.start)} selected')]),
      RangeSlider(values: _trim, min: 0, max: _durationMs, labels: RangeLabels(_time(_trim.start), _time(_trim.end)), onChanged: _changeTrim),
      const Text('Drag either end to choose exactly what will be uploaded.', style: TextStyle(color: Colors.black54, fontSize: 12)),
    ]);
  }
}
