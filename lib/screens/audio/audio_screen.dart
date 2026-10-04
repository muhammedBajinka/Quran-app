import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/media_repository.dart';
import '../../data/media_social_repository.dart';
import '../../models/audio/media_item.dart';
import '../../state/audio/media_audio_controller.dart';

enum _MediaFeedTab { other, sermon, dua, recitation, following, forYou }

class AudioScreen extends StatefulWidget {
  final MediaAudioController audioController;

  const AudioScreen({super.key, required this.audioController});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  final MediaRepository _repository = MediaRepository();
  final MediaSocialRepository _socialRepository = MediaSocialRepository();

  _MediaFeedTab _selectedTab = _MediaFeedTab.forYou;

  late Future<List<MediaItem>> _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _items = _loadSelectedFeed();
  }

  Future<List<MediaItem>> _loadSelectedFeed() async {
    switch (_selectedTab) {
      case _MediaFeedTab.other:
        return _repository.getCategoryFeed(MediaItemType.other);

      case _MediaFeedTab.sermon:
        return _repository.getCategoryFeed(MediaItemType.sermon);

      case _MediaFeedTab.dua:
        return _repository.getCategoryFeed(MediaItemType.dua);

      case _MediaFeedTab.recitation:
        return _repository.getCategoryFeed(MediaItemType.recitation);

      case _MediaFeedTab.following:
        final creatorIds = await _socialRepository.getFollowingCreatorIds();

        if (creatorIds.isEmpty) {
          return const [];
        }

        final all = await _repository.getAllPublished();

        return all
            .where(
              (item) =>
                  item.creatorId != null && creatorIds.contains(item.creatorId),
            )
            .toList();

      case _MediaFeedTab.forYou:
        return _repository.getForYouFeed();
    }
  }

  Future<void> _refresh() async {
    setState(_load);
    await _items;
  }

  void _selectTab(_MediaFeedTab tab) {
    if (_selectedTab == tab) {
      return;
    }

    widget.audioController.pause();

    setState(() {
      _selectedTab = tab;
      _load();
    });
  }

  @override
  void dispose() {
    widget.audioController.pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<List<MediaItem>>(
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
                  message: 'Could not load Media.',
                  buttonText: 'Try Again',
                  onPressed: () {
                    setState(_load);
                  },
                );
              }

              final items = snapshot.data ?? const <MediaItem>[];

              if (items.isEmpty) {
                final message = _selectedTab == _MediaFeedTab.following
                    ? 'Follow creators to see their posts here.'
                    : 'No Media has been published here yet.';

                return _FeedMessage(
                  icon: Icons.perm_media_outlined,
                  message: message,
                  buttonText: 'Refresh',
                  onPressed: _refresh,
                );
              }

              return _UnifiedMediaFeed(
                key: ValueKey(_selectedTab),
                items: items,
                audioController: widget.audioController,
                socialRepository: _socialRepository,
              );
            },
          ),

          _TopNavigation(
            selectedTab: _selectedTab,
            onSelected: _selectTab,
            onSearch: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Media search will be connected next.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TopNavigation extends StatelessWidget {
  final _MediaFeedTab selectedTab;
  final ValueChanged<_MediaFeedTab> onSelected;
  final VoidCallback onSearch;

  const _TopNavigation({
    required this.selectedTab,
    required this.onSelected,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 58,
          color: Colors.black.withValues(alpha: 0.30),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  reverse: true,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    children: [
                      _tab('Other', _MediaFeedTab.other),
                      _tab('Sermon', _MediaFeedTab.sermon),
                      _tab('Dua', _MediaFeedTab.dua),
                      _tab('Recitation', _MediaFeedTab.recitation),
                      _tab('Following', _MediaFeedTab.following),
                      _tab('For You', _MediaFeedTab.forYou),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Search',
                color: Colors.white,
                onPressed: onSearch,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, _MediaFeedTab tab) {
    final selected = selectedTab == tab;

    return TextButton(
      onPressed: () => onSelected(tab),
      style: TextButton.styleFrom(
        foregroundColor: selected ? Colors.white : Colors.white70,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: selected ? 22 : 0,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnifiedMediaFeed extends StatefulWidget {
  final List<MediaItem> items;
  final MediaAudioController audioController;
  final MediaSocialRepository socialRepository;

  const _UnifiedMediaFeed({
    super.key,
    required this.items,
    required this.audioController,
    required this.socialRepository,
  });

  @override
  State<_UnifiedMediaFeed> createState() => _UnifiedMediaFeedState();
}

class _UnifiedMediaFeedState extends State<_UnifiedMediaFeed> {
  late final PageController _pageController;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _pageController = PageController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.items.isEmpty) {
        return;
      }

      _activateItem(widget.items.first);
    });
  }

  Future<void> _activateItem(MediaItem item) async {
    if (item.hasAudio) {
      await widget.audioController.playItem(item);
    } else {
      await widget.audioController.pause();
    }
  }

  void _pageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    _activateItem(widget.items[index]);
  }

  @override
  void dispose() {
    widget.audioController.pause();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: widget.items.length,
      onPageChanged: _pageChanged,
      itemBuilder: (context, index) {
        final item = widget.items[index];

        return _MediaFeedPage(
          key: ValueKey(item.id),
          item: item,
          active: index == _currentIndex,
          audioController: widget.audioController,
          socialRepository: widget.socialRepository,
        );
      },
    );
  }
}

class _MediaFeedPage extends StatefulWidget {
  final MediaItem item;
  final bool active;
  final MediaAudioController audioController;
  final MediaSocialRepository socialRepository;

  const _MediaFeedPage({
    super.key,
    required this.item,
    required this.active,
    required this.audioController,
    required this.socialRepository,
  });

  @override
  State<_MediaFeedPage> createState() => _MediaFeedPageState();
}

class _MediaFeedPageState extends State<_MediaFeedPage> {
  VideoPlayerController? _videoController;

  CreatorProfile? _creator;

  bool _videoInitialized = false;
  bool _showPlayButton = false;

  bool _liked = false;
  bool _following = false;
  bool _reposted = false;

  int _likeCount = 0;
  int _commentCount = 0;

  double _speed = 1.0;

  String? _videoError;

  Timer? _holdTimer;
  bool _holdTriggered = false;
  Offset? _pointerStartPosition;
  bool _pointerMoved = false;

  static const _speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();

    _loadSocialState();

    if (widget.item.hasVideo) {
      _initializeVideo();
    }
  }

  @override
  void didUpdateWidget(covariant _MediaFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.active != widget.active) {
      if (widget.active) {
        if (widget.item.hasVideo) {
          widget.audioController.pause();
          _playVideoIfReady();
        } else if (widget.item.hasAudio) {
          widget.audioController.playItem(widget.item);
        }
      } else {
        _videoController?.pause();

        if (widget.item.hasAudio &&
            widget.audioController.currentItem?.id == widget.item.id) {
          widget.audioController.pause();
        }
      }
    }
  }

  Future<void> _loadSocialState() async {
    try {
      final creatorId = widget.item.creatorId;

      CreatorProfile? creator;
      bool following = false;

      if (creatorId != null) {
        creator = await widget.socialRepository.getCreatorProfile(creatorId);

        following = await widget.socialRepository.isFollowing(creatorId);
      }

      final liked = await widget.socialRepository.hasLiked(widget.item.id);

      final reposted = await widget.socialRepository.hasReposted(
        widget.item.id,
      );

      final likeCount = await widget.socialRepository.getLikeCount(
        widget.item.id,
      );

      final commentCount = await widget.socialRepository.getCommentCount(
        widget.item.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _creator = creator;
        _following = following;
        _liked = liked;
        _reposted = reposted;
        _likeCount = likeCount;
        _commentCount = commentCount;
      });
    } catch (_) {
      // The Media itself should remain usable even if
      // one social request temporarily fails.
    }
  }

  Future<void> _initializeVideo() async {
    final url = widget.item.videoUrl;

    if (url == null || url.trim().isEmpty) {
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));

    _videoController = controller;
    controller.addListener(_videoChanged);

    try {
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.setPlaybackSpeed(_speed);

      setState(() {
        _videoInitialized = true;
      });

      if (widget.active) {
        await widget.audioController.pause();
        await controller.play();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _videoError = 'The video could not be loaded.';
      });
    }
  }

  void _videoChanged() {
    if (!mounted || _videoController == null) {
      return;
    }

    final playing = _videoController!.value.isPlaying;
    final shouldShow = !playing;

    if (_showPlayButton != shouldShow) {
      setState(() {
        _showPlayButton = shouldShow;
      });
    }
  }

  Future<void> _playVideoIfReady() async {
    final controller = _videoController;

    if (controller == null || !_videoInitialized) {
      return;
    }

    await controller.play();
  }

  Future<void> _togglePlayback() async {
    if (widget.item.hasVideo) {
      final controller = _videoController;

      if (controller == null || !_videoInitialized) {
        return;
      }

      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await widget.audioController.pause();
        await controller.play();
      }

      return;
    }

    if (!widget.item.hasAudio) {
      return;
    }

    final player = widget.audioController.player;

    if (widget.audioController.currentItem?.id != widget.item.id) {
      await widget.audioController.playItem(widget.item);
      return;
    }

    if (player.playing) {
      await widget.audioController.pause();
    } else {
      await widget.audioController.play();
    }
  }

  void _pointerDown(PointerDownEvent event) {
    _holdTimer?.cancel();
    _holdTriggered = false;
    _pointerMoved = false;
    _pointerStartPosition = event.position;

    _holdTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _pointerMoved) {
        return;
      }

      _holdTriggered = true;
      _showPostMenu();
    });
  }

  void _pointerMove(PointerMoveEvent event) {
    final start = _pointerStartPosition;

    if (start == null || _pointerMoved) {
      return;
    }

    if ((event.position - start).distance > 12) {
      _pointerMoved = true;
      _holdTimer?.cancel();
    }
  }

  void _pointerUp(PointerUpEvent event) {
    _holdTimer?.cancel();

    if (!_holdTriggered && !_pointerMoved) {
      _togglePlayback();
    }

    _holdTriggered = false;
    _pointerMoved = false;
    _pointerStartPosition = null;
  }

  void _pointerCancel(PointerCancelEvent event) {
    _holdTimer?.cancel();
    _holdTriggered = false;
    _pointerMoved = false;
    _pointerStartPosition = null;
  }

  Future<void> _showPostMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171717),
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.download_outlined,
                  color: Colors.white,
                ),
                title: const Text(
                  'Download',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Download will be connected with '
                        'the secure media storage step.',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.white),
                title: const Text(
                  'Report',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showReportSheet();
                },
              ),
              ListTile(
                leading: const Icon(Icons.speed, color: Colors.white),
                title: const Text(
                  'Playback speed',
                  style: TextStyle(color: Colors.white),
                ),
                trailing: Text(
                  '$_speed×',
                  style: const TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showSpeedSheet();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSpeedSheet() async {
    final selected = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: const Color(0xFF171717),
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _speeds
                .map(
                  (speed) => ListTile(
                    title: Text(
                      '$speed×',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: speed == _speed
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                    onTap: () {
                      Navigator.pop(context, speed);
                    },
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    if (widget.item.hasVideo) {
      await _videoController?.setPlaybackSpeed(selected);
    } else if (widget.item.hasAudio) {
      await widget.audioController.setSpeed(selected);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _speed = selected;
    });
  }

  Future<void> _showReportSheet() async {
    const reasons = <String>[
      'Inappropriate content',
      'Spam',
      'Misleading content',
      'Copyright concern',
      'Other',
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171717),
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Report this post',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...reasons.map(
                (reason) => ListTile(
                  title: Text(
                    reason,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);

                    try {
                      await widget.socialRepository.reportMedia(
                        mediaId: widget.item.id,
                        reason: reason,
                      );

                      if (!mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Report sent for admin review.'),
                        ),
                      );
                    } catch (_) {
                      if (!mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not send the report.'),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleLike() async {
    final previous = _liked;

    setState(() {
      _liked = !previous;

      if (_liked) {
        _likeCount++;
      } else if (_likeCount > 0) {
        _likeCount--;
      }
    });

    try {
      if (previous) {
        await widget.socialRepository.unlike(widget.item.id);
      } else {
        await widget.socialRepository.like(widget.item.id);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _liked = previous;

        if (previous) {
          _likeCount++;
        } else if (_likeCount > 0) {
          _likeCount--;
        }
      });
    }
  }

  Future<void> _toggleFollow() async {
    final creatorId = widget.item.creatorId;

    if (creatorId == null ||
        creatorId == widget.socialRepository.currentUserId) {
      return;
    }

    final previous = _following;

    setState(() {
      _following = !previous;
    });

    try {
      if (previous) {
        await widget.socialRepository.unfollow(creatorId);
      } else {
        await widget.socialRepository.follow(creatorId);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _following = previous;
      });
    }
  }

  Future<void> _toggleRepost() async {
    final previous = _reposted;

    setState(() {
      _reposted = !previous;
    });

    try {
      if (previous) {
        await widget.socialRepository.removeRepost(widget.item.id);
      } else {
        await widget.socialRepository.repost(widget.item.id);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _reposted = previous;
      });
    }
  }

  Future<void> _openComments() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171717),
      builder: (context) {
        return _CommentsSheet(
          item: widget.item,
          repository: widget.socialRepository,
        );
      },
    );

    try {
      final count = await widget.socialRepository.getCommentCount(
        widget.item.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _commentCount = count;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _holdTimer?.cancel();

    final controller = _videoController;

    if (controller != null) {
      controller.removeListener(_videoChanged);
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(child: _buildMedia()),

          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _pointerDown,
              onPointerMove: _pointerMove,
              onPointerUp: _pointerUp,
              onPointerCancel: _pointerCancel,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),

          if (widget.item.hasVideo && _videoInitialized && _showPlayButton)
            const Center(
              child: IgnorePointer(
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: Color(0x99000000),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 46,
                  ),
                ),
              ),
            ),

          Positioned(right: 12, bottom: 90, child: _buildActionRail()),

          Positioned(
            left: 14,
            right: 78,
            bottom: 48,
            child: _buildPostInformation(),
          ),

          if (widget.item.hasVideo &&
              _videoInitialized &&
              _videoController != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 4,
              child: VideoProgressIndicator(
                _videoController!,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),

          if (widget.item.hasAudio)
            Positioned(
              left: 8,
              right: 8,
              bottom: 4,
              child: _AudioProgress(
                controller: widget.audioController,
                item: widget.item,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMedia() {
    if (widget.item.hasVideo) {
      if (_videoError != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Text(
              _videoError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }

      final controller = _videoController;

      if (!_videoInitialized || controller == null) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }

      final aspectRatio = controller.value.aspectRatio > 0
          ? controller.value.aspectRatio
          : 9 / 16;

      return Center(
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: VideoPlayer(controller),
        ),
      );
    }

    return _AudioArtwork(item: widget.item);
  }

  Widget _buildActionRail() {
    final creatorId = widget.item.creatorId;

    final ownPost =
        creatorId != null && creatorId == widget.socialRepository.currentUserId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white24,
              backgroundImage:
                  _creator?.avatarUrl != null &&
                      _creator!.avatarUrl!.trim().isNotEmpty
                  ? NetworkImage(_creator!.avatarUrl!)
                  : null,
              child:
                  _creator?.avatarUrl == null ||
                      _creator!.avatarUrl!.trim().isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            if (!ownPost && creatorId != null && !_following)
              Positioned(
                bottom: -9,
                child: GestureDetector(
                  onTap: _toggleFollow,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Icon(Icons.add, size: 16, color: Colors.black),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),

        _ActionButton(
          icon: _liked ? Icons.favorite : Icons.favorite_border,
          label: _compactNumber(_likeCount),
          onPressed: _toggleLike,
        ),

        _ActionButton(
          icon: Icons.mode_comment_outlined,
          label: _compactNumber(_commentCount),
          onPressed: _openComments,
        ),

        _ActionButton(
          icon: _reposted ? Icons.repeat_on_rounded : Icons.repeat_rounded,
          label: 'Repost',
          onPressed: _toggleRepost,
        ),

        _ActionButton(
          icon: Icons.share_outlined,
          label: 'Share',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'System sharing will be connected '
                  'with the Media link step.',
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPostInformation() {
    final creatorName =
        _creator?.visibleName ?? widget.item.speaker ?? 'Quran Life';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '@$creatorName',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
            shadows: [Shadow(blurRadius: 5, color: Colors.black)],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          widget.item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
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
    );
  }

  String _compactNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return '$value';
  }
}

class _AudioArtwork extends StatelessWidget {
  final MediaItem item;

  const _AudioArtwork({required this.item});

  @override
  Widget build(BuildContext context) {
    final hasImage =
        item.thumbnailUrl != null && item.thumbnailUrl!.trim().isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasImage)
          Image.network(
            item.thumbnailUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallbackBackground(),
          )
        else
          _fallbackBackground(),

        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x33000000), Color(0x55000000), Color(0xDD000000)],
            ),
          ),
        ),

        Center(
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.48),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallbackBackground() {
    return const ColoredBox(
      color: Color(0xFF17231D),
      child: Center(
        child: Icon(Icons.headphones_rounded, color: Colors.white24, size: 150),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        children: [
          IconButton(
            onPressed: onPressed,
            iconSize: 32,
            color: Colors.white,
            visualDensity: VisualDensity.compact,
            icon: Icon(icon),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              shadows: [Shadow(blurRadius: 4, color: Colors.black)],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioProgress extends StatelessWidget {
  final MediaAudioController controller;
  final MediaItem item;

  const _AudioProgress({required this.controller, required this.item});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.currentItem?.id != item.id) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<Duration?>(
          stream: controller.player.durationStream,
          builder: (context, durationSnapshot) {
            return StreamBuilder<Duration>(
              stream: controller.player.positionStream,
              builder: (context, positionSnapshot) {
                final duration = durationSnapshot.data ?? Duration.zero;

                final position = positionSnapshot.data ?? Duration.zero;

                final durationMs = duration.inMilliseconds;

                final max = durationMs > 0 ? durationMs.toDouble() : 1.0;

                final current = position.inMilliseconds
                    .clamp(0, durationMs > 0 ? durationMs : 0)
                    .toDouble();

                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 4,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10,
                    ),
                  ),
                  child: Slider(
                    value: current,
                    max: max,
                    onChanged: durationMs > 0
                        ? (value) {
                            controller.seek(
                              Duration(milliseconds: value.round()),
                            );
                          }
                        : null,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final MediaItem item;
  final MediaSocialRepository repository;

  const _CommentsSheet({required this.item, required this.repository});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _textController = TextEditingController();

  late Future<List<MediaComment>> _comments;

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _comments = widget.repository.getComments(widget.item.id);
  }

  Future<void> _send() async {
    final text = _textController.text.trim();

    if (text.isEmpty || _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await widget.repository.addComment(mediaId: widget.item.id, text: text);

      _textController.clear();

      if (!mounted) {
        return;
      }

      setState(() {
        _sending = false;
        _load();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _sending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not post the comment.')),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Text(
                'Comments',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<MediaComment>>(
                future: _comments,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Could not load comments.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  final comments = snapshot.data ?? const <MediaComment>[];

                  if (comments.isEmpty) {
                    return const Center(
                      child: Text(
                        'No comments yet.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];

                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(
                          comment.displayName ?? 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          comment.text,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Post comment',
                    onPressed: _sending ? null : _send,
                    color: Colors.white,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
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
