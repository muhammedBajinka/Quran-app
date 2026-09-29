import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../models/audio/media_item.dart';

class MediaVideoScreen extends StatefulWidget {
  final MediaItem item;

  const MediaVideoScreen({super.key, required this.item});

  @override
  State<MediaVideoScreen> createState() => _MediaVideoScreenState();
}

class _MediaVideoScreenState extends State<MediaVideoScreen> {
  late final VideoPlayerController _controller;

  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    final videoUrl = widget.item.videoUrl;

    if (videoUrl == null || videoUrl.trim().isEmpty) {
      _error = 'No video is available.';
      return;
    }

    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      await _controller.initialize();

      if (!mounted) return;

      setState(() {
        _initialized = true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'The video could not be loaded.';
      });
    }
  }

  Future<void> _openFullscreen() async {
    if (!_initialized) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenVideoScreen(controller: _controller),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (_initialized || _error == null) {
      _controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.title)),
      body: Column(
        children: [
          Expanded(child: Center(child: _buildVideoArea())),
          if (_initialized)
            _VideoControls(
              controller: _controller,
              onFullscreen: _openFullscreen,
            ),
        ],
      ),
    );
  }

  Widget _buildVideoArea() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_error!, textAlign: TextAlign.center),
      );
    }

    if (!_initialized) {
      return const CircularProgressIndicator();
    }

    final aspectRatio = _controller.value.aspectRatio;

    return AspectRatio(
      aspectRatio: aspectRatio > 0 ? aspectRatio : 16 / 9,
      child: VideoPlayer(_controller),
    );
  }
}

class _VideoControls extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onFullscreen;
  final bool showFullscreen;

  const _VideoControls({
    required this.controller,
    required this.onFullscreen,
    this.showFullscreen = true,
  });

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  VideoPlayerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_videoChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_videoChanged);
    super.dispose();
  }

  void _videoChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final duration = value.duration;
    final position = value.position;

    final durationMs = duration.inMilliseconds;
    final positionMs = position.inMilliseconds;

    final maxValue = durationMs > 0 ? durationMs.toDouble() : 1.0;

    final sliderValue = positionMs
        .clamp(0, durationMs > 0 ? durationMs : 0)
        .toDouble();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              value: sliderValue,
              max: maxValue,
              onChanged: durationMs > 0
                  ? (newValue) {
                      controller.seekTo(
                        Duration(milliseconds: newValue.round()),
                      );
                    }
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(
                    '${_formatDuration(position)} / '
                    '${_formatDuration(duration)}',
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: value.isPlaying ? 'Pause' : 'Play',
                    onPressed: () {
                      if (value.isPlaying) {
                        controller.pause();
                      } else {
                        controller.play();
                      }
                    },
                    icon: Icon(
                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                  ),
                  if (widget.showFullscreen)
                    IconButton(
                      tooltip: 'Fullscreen',
                      onPressed: widget.onFullscreen,
                      icon: const Icon(Icons.fullscreen),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenVideoScreen extends StatefulWidget {
  final VideoPlayerController controller;

  const _FullscreenVideoScreen({required this.controller});

  @override
  State<_FullscreenVideoScreen> createState() => _FullscreenVideoScreenState();
}

class _FullscreenVideoScreenState extends State<_FullscreenVideoScreen> {
  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _exitFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspectRatio = widget.controller.value.aspectRatio;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _exitFullscreen();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: aspectRatio > 0 ? aspectRatio : 16 / 9,
                  child: VideoPlayer(widget.controller),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: 'Exit fullscreen',
                  color: Colors.white,
                  iconSize: 30,
                  onPressed: _exitFullscreen,
                  icon: const Icon(Icons.fullscreen_exit),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Material(
                  color: Colors.black54,
                  child: _VideoControls(
                    controller: widget.controller,
                    onFullscreen: _exitFullscreen,
                    showFullscreen: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
