import 'dart:async';
import '../../services/error_report_service.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/media_repository.dart';
import '../../models/audio/media_item.dart';

class MediaVideoFeedScreen extends StatefulWidget {
  const MediaVideoFeedScreen({super.key});

  @override
  State<MediaVideoFeedScreen> createState() => _MediaVideoFeedScreenState();
}

class _MediaVideoFeedScreenState extends State<MediaVideoFeedScreen> {
  final MediaRepository _repository = MediaRepository();

  late Future<List<MediaItem>> _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _items = _repository.getVideoFeed();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<List<MediaItem>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError) {
            return _FeedMessage(
              icon: Icons.cloud_off_outlined,
              message: 'Could not load videos.',
              buttonText: 'Try Again',
              onPressed: () {
                setState(_load);
              },
            );
          }

          final items = snapshot.data ?? const <MediaItem>[];

          if (items.isEmpty) {
            return _FeedMessage(
              icon: Icons.video_library_outlined,
              message: 'No videos have been published yet.',
              buttonText: 'Refresh',
              onPressed: _refresh,
            );
          }

          return _VideoFeed(items: items);
        },
      ),
    );
  }
}

class _VideoFeed extends StatefulWidget {
  final List<MediaItem> items;

  const _VideoFeed({required this.items});

  @override
  State<_VideoFeed> createState() => _VideoFeedState();
}

class _VideoFeedState extends State<_VideoFeed> {
  late final PageController _pageController;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _pageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: widget.items.length,
          onPageChanged: _pageChanged,
          itemBuilder: (context, index) {
            return _VideoFeedPage(
              key: ValueKey(widget.items[index].id),
              item: widget.items[index],
              active: index == _currentIndex,
            );
          },
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton.filledTonal(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoFeedPage extends StatefulWidget {
  final MediaItem item;
  final bool active;

  const _VideoFeedPage({super.key, required this.item, required this.active});

  @override
  State<_VideoFeedPage> createState() => _VideoFeedPageState();
}

class _VideoFeedPageState extends State<_VideoFeedPage> {
  VideoPlayerController? _controller;

  bool _initialized = false;
  bool _showPlayButton = true;
  bool _liked = false;
  String? _error;

  double _speed = 1.0;

  static const _speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant _VideoFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.active != widget.active) {
      if (widget.active) {
        _playIfReady();
      } else {
        _controller?.pause();
      }
    }
  }

  Future<void> _initialize() async {
    final url = widget.item.videoUrl;

    if (url == null || url.trim().isEmpty) {
      setState(() {
        _error = 'Video unavailable.';
      });
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;

    controller.addListener(_videoChanged);

    try {
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _initialized = true;
      });

      if (widget.active) {
        await controller.play();
      }
    } catch (error) {
      unawaited(ErrorReportService.report('VIDEO_PLAYBACK_FAILED', error: error));
      if (!mounted) return;

      setState(() {
        _error = 'The video could not be loaded.';
      });
    }
  }

  void _videoChanged() {
    if (!mounted || _controller == null) return;

    final playing = _controller!.value.isPlaying;

    if (_showPlayButton == playing) {
      setState(() {
        _showPlayButton = !playing;
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _playIfReady() async {
    final controller = _controller;

    if (controller == null || !_initialized) return;

    await controller.play();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;

    if (controller == null || !_initialized) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _setSpeed(double speed) async {
    final controller = _controller;

    if (controller == null || !_initialized) return;

    await controller.setPlaybackSpeed(speed);

    if (!mounted) return;

    setState(() {
      _speed = speed;
    });
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
  void dispose() {
    final controller = _controller;

    if (controller != null) {
      controller.removeListener(_videoChanged);
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlayback,
              child: Center(child: _buildVideo(controller)),
            ),

            if (_initialized && _showPlayButton)
              Center(
                child: IgnorePointer(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 46,
                    ),
                  ),
                ),
              ),

            Positioned(
              right: 12,
              bottom: 105,
              child: Column(
                children: [
                  IconButton(
                    tooltip: _liked ? 'Unlike' : 'Like',
                    iconSize: 34,
                    color: Colors.white,
                    onPressed: () {
                      setState(() {
                        _liked = !_liked;
                      });
                    },
                    icon: Icon(_liked ? Icons.favorite : Icons.favorite_border),
                  ),
                  const Text(
                    'Like',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                  const SizedBox(height: 14),
                  PopupMenuButton<double>(
                    tooltip: 'Playback speed',
                    initialValue: _speed,
                    onSelected: _setSpeed,
                    itemBuilder: (context) => _speeds
                        .map(
                          (speed) => PopupMenuItem<double>(
                            value: speed,
                            child: Text('$speed×'),
                          ),
                        )
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        '$_speed×',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              left: 14,
              right: 62,
              bottom: 52,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 5, color: Colors.black)],
                    ),
                  ),
                  if (widget.item.description != null &&
                      widget.item.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.item.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        shadows: [Shadow(blurRadius: 5, color: Colors.black)],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (_initialized && controller != null)
              Positioned(
                left: 8,
                right: 8,
                bottom: 4,
                child: _VideoProgress(
                  controller: controller,
                  formatDuration: _formatDuration,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo(VideoPlayerController? controller) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(30),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    if (!_initialized || controller == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    final aspectRatio = controller.value.aspectRatio;

    return AspectRatio(
      aspectRatio: aspectRatio > 0 ? aspectRatio : 9 / 16,
      child: VideoPlayer(controller),
    );
  }
}

class _VideoProgress extends StatefulWidget {
  final VideoPlayerController controller;
  final String Function(Duration) formatDuration;

  const _VideoProgress({
    required this.controller,
    required this.formatDuration,
  });

  @override
  State<_VideoProgress> createState() => _VideoProgressState();
}

class _VideoProgressState extends State<_VideoProgress> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final duration = value.duration;
    final position = value.position;

    final durationMs = duration.inMilliseconds;
    final positionMs = position.inMilliseconds;

    final max = durationMs > 0 ? durationMs.toDouble() : 1.0;
    final current = positionMs
        .clamp(0, durationMs > 0 ? durationMs : 0)
        .toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              widget.formatDuration(position),
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            const Spacer(),
            Text(
              widget.formatDuration(duration),
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
        SizedBox(
          height: 22,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
              value: current,
              max: max,
              onChanged: durationMs > 0
                  ? (newValue) {
                      widget.controller.seekTo(
                        Duration(milliseconds: newValue.round()),
                      );
                    }
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String buttonText;
  final VoidCallback onPressed;

  const _FeedMessage({
    required this.icon,
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 52),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ),
      ),
    );
  }
}
