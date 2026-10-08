import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

import '../profile/creator_profile_screen.dart';
import '../profile/upload_media_screen.dart';

import '../../data/media_repository.dart';
import '../../widgets/media_search_results.dart';
import '../../services/media_worker_service.dart';
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
  MediaItem? _currentVisibleItem;
  final MediaRepository _repository = MediaRepository();
  final MediaSocialRepository _socialRepository = MediaSocialRepository();

  _MediaFeedTab _selectedTab = _MediaFeedTab.forYou;

  bool _searchMode = false;
  final TextEditingController _searchController = TextEditingController();
  late Future<List<MediaItem>> _items;
  Future<List<MediaItem>>? _searchResults;
  Future<List<CreatorProfile>>? _creatorSearchResults;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _items = _loadSelectedFeed();
  }

  void _openSearch() {
    widget.audioController.pause();

    setState(() {
      _searchMode = true;
      _searchController.clear();
      _searchResults = null;
      _creatorSearchResults = null;
    });
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    widget.audioController.pause();

    setState(() {
      _searchMode = false;
      _searchController.clear();
      _searchResults = null;
      _creatorSearchResults = null;
      _currentVisibleItem = null;
    });
  }

  void _runSearch(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = null;
        _creatorSearchResults = null;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || !_searchMode) return;
      setState(() {
        _searchResults = _repository.searchPublished(query.trim());
        _creatorSearchResults = _socialRepository.searchCreators(query.trim());
      });
    });
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
      _currentVisibleItem = null;
      _load();
    });
  }

  @override
  void dispose() {
    widget.audioController.pause();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  static const _tabOrder = <_MediaFeedTab>[
    _MediaFeedTab.other,
    _MediaFeedTab.sermon,
    _MediaFeedTab.dua,
    _MediaFeedTab.recitation,
    _MediaFeedTab.following,
    _MediaFeedTab.forYou,
  ];

  void _swipeLeft() {
    final index = _tabOrder.indexOf(_selectedTab);

    // The tabs are rendered Other ... For You from left to right.
    // A left swipe therefore moves one tab left repeatedly. Only after the
    // left-most tab does another left swipe transition to the creator.
    if (index > 0) {
      _selectTab(_tabOrder[index - 1]);
    } else {
      _openCurrentCreatorProfile();
    }
  }

  void _swipeRight() {
    final index = _tabOrder.indexOf(_selectedTab);
    if (index >= 0 && index < _tabOrder.length - 1) {
      _selectTab(_tabOrder[index + 1]);
    }
  }

  void _currentItemChanged(MediaItem item) {
    _currentVisibleItem = item;
  }

  void _openCurrentCreatorProfile() {
    final creatorId = _currentVisibleItem?.creatorId;

    if (creatorId == null || creatorId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This post does not have a creator profile.'),
        ),
      );
      return;
    }

    _openCreatorProfile(creatorId);
  }

  Future<void> _openCreatorProfile(String creatorId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreatorProfileScreen(creatorId: creatorId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_searchMode) {
      return _MediaSearchView(
        controller: _searchController,
        results: _searchResults,
        creatorResults: _creatorSearchResults,
        repository: _repository,
        audioController: widget.audioController,
        socialRepository: _socialRepository,
        onBack: _closeSearch,
        onSearch: _runSearch,
        onCreatorPressed: _openCreatorProfile,
      );
    }

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
                onSwipeLeft: _swipeLeft,
                onSwipeRight: _swipeRight,
                onCurrentItemChanged: _currentItemChanged,
                onCreatorPressed: _openCreatorProfile,
              );
            },
          ),

          _TopNavigation(
            selectedTab: _selectedTab,
            onSelected: _selectTab,
            onSearch: _openSearch,
            onRefresh: _refresh,
          ),
        ],
      ),
    );
  }
}

class _MediaSearchView extends StatelessWidget {
  final TextEditingController controller;
  final Future<List<MediaItem>>? results;
  final Future<List<CreatorProfile>>? creatorResults;
  final MediaRepository repository;
  final MediaAudioController audioController;
  final MediaSocialRepository socialRepository;
  final VoidCallback onBack;
  final ValueChanged<String> onSearch;
  final Future<void> Function(String) onCreatorPressed;

  const _MediaSearchView({
    required this.controller,
    required this.results,
    required this.creatorResults,
    required this.repository,
    required this.audioController,
    required this.socialRepository,
    required this.onBack,
    required this.onSearch,
    required this.onCreatorPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    color: Colors.white,
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      textInputAction: TextInputAction.search,
                      onChanged: onSearch,
                      onSubmitted: onSearch,
                      decoration: InputDecoration(
                        hintText: 'Search posts and creators',
                        hintStyle: const TextStyle(color: Colors.white60),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white70,
                        ),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildResults(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final future = results;

    if (future == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Search for a title, speaker, description, or creator.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    return FutureBuilder<List<MediaItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Search failed. Please try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        final items = snapshot.data ?? const <MediaItem>[];

        return FutureBuilder<List<CreatorProfile>>(
          future: creatorResults,
          builder: (context, creatorsSnapshot) {
            if (creatorsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            return Column(
              children: [
                if (creatorsSnapshot.hasError)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Creator search is unavailable. Try searching again.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                Expanded(
                  child: MediaSearchResults(
                    items: items,
                    creators: creatorsSnapshot.data ?? const [],
                    onOpenCreator: (id) {
                      onCreatorPressed(id);
                    },
                    onOpenMedia: (index) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CreatorMediaFeedScreen(
                            items: items,
                            initialIndex: index,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TopNavigation extends StatelessWidget {
  final _MediaFeedTab selectedTab;
  final ValueChanged<_MediaFeedTab> onSelected;
  final VoidCallback onSearch;
  final Future<void> Function() onRefresh;

  const _TopNavigation({
    required this.selectedTab,
    required this.onSelected,
    required this.onSearch,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 48,
          color: Colors.black.withValues(alpha: 0.18),
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
                tooltip: 'Refresh Media',
                color: Colors.white,
                onPressed: () => onRefresh(),
                icon: const Icon(Icons.refresh_rounded),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13,
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

class CreatorMediaFeedScreen extends StatefulWidget {
  final List<MediaItem> items;
  final int initialIndex;
  final bool allowManagement;
  const CreatorMediaFeedScreen({
    super.key,
    required this.items,
    required this.initialIndex,
    this.allowManagement = false,
  });

  @override
  State<CreatorMediaFeedScreen> createState() => _CreatorMediaFeedScreenState();
}

class _CreatorMediaFeedScreenState extends State<CreatorMediaFeedScreen> {
  final _audio = MediaAudioController();
  final _social = MediaSocialRepository();

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        _UnifiedMediaFeed(
          items: widget.items,
          initialIndex: widget.initialIndex,
          allowManagement: widget.allowManagement,
          audioController: _audio,
          socialRepository: _social,
          onSwipeLeft: () {},
          onSwipeRight: () {},
          onCurrentItemChanged: (_) {},
          onCreatorPressed: (id) async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CreatorProfileScreen(creatorId: id),
              ),
            );
          },
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: IconButton.filledTonal(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
        ),
      ],
    ),
  );
}

class _UnifiedMediaFeed extends StatefulWidget {
  final List<MediaItem> items;
  final int initialIndex;
  final bool allowManagement;
  final MediaAudioController audioController;
  final MediaSocialRepository socialRepository;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final ValueChanged<MediaItem> onCurrentItemChanged;
  final Future<void> Function(String) onCreatorPressed;

  const _UnifiedMediaFeed({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.allowManagement = false,
    required this.audioController,
    required this.socialRepository,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.onCurrentItemChanged,
    required this.onCreatorPressed,
  });

  @override
  State<_UnifiedMediaFeed> createState() => _UnifiedMediaFeedState();
}

class _UnifiedMediaFeedState extends State<_UnifiedMediaFeed> {
  late final PageController _pageController;

  int _currentIndex = 0;
  late final List<MediaItem> _items;
  bool _autoScroll = false;
  bool _advancing = false;
  StreamSubscription<PlayerState>? _audioSubscription;
  Offset? _pointerStart;
  bool _horizontalSwipeHandled = false;

  @override
  void initState() {
    super.initState();

    _items = List.of(widget.items);
    _currentIndex = widget.initialIndex.clamp(0, _items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _audioSubscription = widget.audioController.player.playerStateStream.listen(
      (state) {
        if (_items.isEmpty) return;
        final item = _items[_currentIndex];
        if (item.hasAudio &&
            widget.audioController.currentItem?.id == item.id &&
            state.processingState == ProcessingState.completed) {
          _completed(item.id);
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _items.isEmpty) {
        return;
      }

      final item = _items[_currentIndex];

      widget.onCurrentItemChanged(item);
      _recordView(item);
      _activateItem(item);
    });
  }

  Future<void> _recordView(MediaItem item) async {
    try {
      await widget.socialRepository.recordView(item.id, watchSeconds: 0);
    } catch (_) {
      // A view failure must never interrupt media playback.
    }
  }

  Future<void> _activateItem(MediaItem item) async {
    if (item.hasAudio) {
      try {
        await widget.audioController.playItem(item);
      } catch (_) {
        if (mounted &&
            _items.isNotEmpty &&
            _items[_currentIndex].id == item.id) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not play this audio. Tap to retry.'),
            ),
          );
        }
      }
    } else {
      await widget.audioController.pause();
    }
  }

  void _pageChanged(int index) {
    final item = _items[index];

    setState(() {
      _currentIndex = index;
    });

    widget.onCurrentItemChanged(item);
    _recordView(item);
    _activateItem(item);
  }

  void _completed(String id) {
    if (!mounted ||
        !_autoScroll ||
        _advancing ||
        _items.isEmpty ||
        _items[_currentIndex].id != id ||
        _currentIndex + 1 >= _items.length ||
        !_pageController.hasClients) {
      return;
    }
    _advancing = true;
    _pageController
        .animateToPage(
          _currentIndex + 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        )
        .whenComplete(() => _advancing = false);
  }

  void _deleted(String id) {
    if (!mounted) return;
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    widget.audioController.pause();
    setState(() {
      _items.removeAt(index);
      _currentIndex = _items.isEmpty
          ? 0
          : _currentIndex.clamp(0, _items.length - 1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _items.isEmpty) return;
      _pageController.jumpToPage(_currentIndex);
      _pageChanged(_currentIndex);
    });
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    widget.audioController.pause();
    _pageController.dispose();
    super.dispose();
  }

  void _pointerDown(PointerDownEvent event) {
    _pointerStart = event.position;
    _horizontalSwipeHandled = false;
  }

  void _pointerMove(PointerMoveEvent event) {
    final start = _pointerStart;
    if (start == null || _horizontalSwipeHandled) return;

    final delta = event.position - start;
    if (delta.dx.abs() < 56 || delta.dx.abs() <= delta.dy.abs() * 1.25) {
      return;
    }

    _horizontalSwipeHandled = true;
    if (delta.dx < 0) {
      widget.onSwipeLeft();
    } else {
      widget.onSwipeRight();
    }
  }

  void _pointerEnd(PointerEvent event) {
    _pointerStart = null;
    _horizontalSwipeHandled = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'No posts remaining.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _pointerDown,
      onPointerMove: _pointerMove,
      onPointerUp: _pointerEnd,
      onPointerCancel: _pointerEnd,
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _items.length,
        onPageChanged: _pageChanged,
        itemBuilder: (context, index) {
          final item = _items[index];

          return _MediaFeedPage(
            key: ValueKey(item.id),
            item: item,
            active: index == _currentIndex,
            allowManagement: widget.allowManagement,
            audioController: widget.audioController,
            socialRepository: widget.socialRepository,
            onCreatorPressed: widget.onCreatorPressed,
            autoScroll: _autoScroll,
            onAutoScrollChanged: (value) => setState(() => _autoScroll = value),
            onCompleted: () => _completed(item.id),
            onDeleted: () => _deleted(item.id),
          );
        },
      ),
    );
  }
}

class _MediaFeedPage extends StatefulWidget {
  final MediaItem item;
  final bool active;
  final bool allowManagement;
  final bool autoScroll;
  final ValueChanged<bool> onAutoScrollChanged;
  final VoidCallback onCompleted;
  final VoidCallback onDeleted;
  final MediaAudioController audioController;
  final MediaSocialRepository socialRepository;
  final Future<void> Function(String) onCreatorPressed;

  const _MediaFeedPage({
    super.key,
    required this.item,
    required this.active,
    required this.allowManagement,
    required this.autoScroll,
    required this.onAutoScrollChanged,
    required this.onCompleted,
    required this.onDeleted,
    required this.audioController,
    required this.socialRepository,
    required this.onCreatorPressed,
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
  int _repostCount = 0;

  bool _showLikeHeart = false;
  double _speed = 1.0;

  String? _videoError;
  bool _deleteBusy = false;

  bool get _canDelete =>
      widget.allowManagement &&
      widget.item.creatorId != null &&
      widget.item.creatorId == widget.socialRepository.currentUserId;
  bool _completionReported = false;

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
        _completionReported = false;
        if (widget.item.hasVideo) _playVideoIfReady();
      } else {
        _videoController?.pause();
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

      final repostCount = await widget.socialRepository.getRepostCount(
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
        _repostCount = repostCount;
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
      if (!mounted) return;

      setState(() {
        _videoInitialized = true;
      });

      if (widget.active) await controller.play();
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

    final value = _videoController!.value;
    if (widget.active && value.isCompleted && !_completionReported) {
      _completionReported = true;
      widget.onCompleted();
    } else if (!value.isCompleted) {
      _completionReported = false;
    }
    final playing = value.isPlaying;
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

    if (controller.value.isCompleted) await controller.seekTo(Duration.zero);
    if (mounted && widget.active) await controller.play();
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
        if (mounted && widget.active) await controller.play();
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

  void _tapMedia() {
    _togglePlayback();
  }

  Future<void> _doubleTapLike() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _showLikeHeart = true;
    });

    if (!_liked) {
      final previousCount = _likeCount;

      setState(() {
        _liked = true;
        _likeCount++;
      });

      try {
        await widget.socialRepository.like(widget.item.id);
      } catch (_) {
        if (mounted) {
          setState(() {
            _liked = false;
            _likeCount = previousCount;
          });
        }
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (!mounted) {
      return;
    }

    setState(() {
      _showLikeHeart = false;
    });
  }

  Future<void> _downloadMedia() async {
    final mediaUrl = widget.item.videoUrl ?? widget.item.audioUrl;

    if (mediaUrl == null || mediaUrl.trim().isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This post does not have a downloadable media file.'),
        ),
      );
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download is allowed. Device saving is being connected.'),
      ),
    );
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
              SwitchListTile(
                secondary: const Icon(Icons.swipe_up, color: Colors.white),
                title: const Text(
                  'Auto-scroll',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Next post when playback finishes',
                  style: TextStyle(color: Colors.white70),
                ),
                value: widget.autoScroll,
                onChanged: (value) {
                  Navigator.pop(sheetContext);
                  widget.onAutoScrollChanged(value);
                },
              ),
              if (!widget.item.published &&
                  widget.item.creatorId != null &&
                  widget.item.creatorId ==
                      widget.socialRepository.currentUserId)
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Colors.white),
                  title: const Text(
                    'Edit draft',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await Navigator.of(context).push(
                      MaterialPageRoute<bool>(
                        builder: (_) => EditDraftScreen(item: widget.item),
                      ),
                    );
                  },
                ),
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

                  if (!widget.item.downloadsEnabled) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Downloads are disabled by this creator.',
                        ),
                      ),
                    );
                    return;
                  }

                  _downloadMedia();
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
              if (_canDelete)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  enabled: !_deleteBusy,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _deletePost();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deletePost() async {
    if (_deleteBusy || !_canDelete) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text(
          'This permanently removes your post and its media file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_canDelete) return;
    setState(() => _deleteBusy = true);
    _videoController?.pause();
    widget.audioController.pause();
    final navigator = Navigator.of(context, rootNavigator: true);
    final progress = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Expanded(child: Text('Deleting your post…')),
            ],
          ),
        ),
      ),
    );
    navigator.push(progress);
    var deleted = false;
    String? failure;
    try {
      await MediaRepository().deleteOwnMedia(widget.item);
      deleted = true;
    } on MediaDeletionException catch (error) {
      failure = error.message;
    } catch (_) {
      failure = 'Could not delete this post. Please try again.';
    } finally {
      if (progress.isActive) navigator.removeRoute(progress);
      if (mounted) setState(() => _deleteBusy = false);
    }
    if (!mounted) return;
    if (deleted) {
      widget.onDeleted();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Post deleted.')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure!)));
    }
  }

  Future<void> _openCreator(String id) async {
    _videoController?.pause();
    await widget.audioController.pause();
    await widget.onCreatorPressed(id);
    if (!mounted || !widget.active) return;
    if (widget.item.hasVideo) {
      _playVideoIfReady();
    } else if (widget.item.hasAudio) {
      widget.audioController.playItem(widget.item);
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in with an account to follow creators.'),
        ),
      );
    }
  }

  Future<void> _toggleRepost() async {
    final previous = _reposted;
    final previousCount = _repostCount;

    setState(() {
      _reposted = !previous;

      if (_reposted) {
        _repostCount++;
      } else if (_repostCount > 0) {
        _repostCount--;
      }
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
        _repostCount = previousCount;
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _tapMedia,
              onDoubleTap: _doubleTapLike,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),

          if (_showLikeHeart)
            const Center(
              child: IgnorePointer(
                child: Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 105,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 18,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
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

          Positioned(right: 12, bottom: 62, child: _buildActionRail()),

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

      return LayoutBuilder(
        builder: (context, constraints) {
          final boxRatio = constraints.maxWidth / constraints.maxHeight;
          final width = aspectRatio > boxRatio
              ? constraints.maxHeight * aspectRatio
              : constraints.maxWidth;
          final height = aspectRatio > boxRatio
              ? constraints.maxHeight
              : constraints.maxWidth / aspectRatio;
          return ClipRect(
            child: Center(
              child: SizedBox(
                width: width,
                height: height,
                child: VideoPlayer(controller),
              ),
            ),
          );
        },
      );
    }

    return _AudioArtwork(item: widget.item);
  }

  Future<void> _sharePost() async {
    final item = widget.item;
    final mediaUrl = item.videoUrl ?? item.audioUrl;

    if (mediaUrl == null || mediaUrl.trim().isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This post does not have a shareable media link.'),
        ),
      );
      return;
    }

    final creatorName = _creator?.visibleName ?? item.speaker ?? 'Quran Life';

    final shareText = [item.title, 'By $creatorName', mediaUrl].join('\n');

    try {
      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: item.title),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open sharing. Please try again.'),
        ),
      );
    }
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
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: creatorId == null ? null : () => _openCreator(creatorId),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 7,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Color(0xFF333333),
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
              ),
            ),
            if (!ownPost && creatorId != null)
              Positioned(
                bottom: -9,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleFollow,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D5B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 5),
                      ],
                    ),
                    child: Icon(
                      _following ? Icons.check : Icons.add,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        _ActionButton(
          icon: _liked ? Icons.favorite : Icons.favorite_border,
          label: _compactNumber(_likeCount),
          onPressed: _toggleLike,
          active: _liked,
        ),

        _ActionButton(
          icon: Icons.mode_comment_outlined,
          label: _compactNumber(_commentCount),
          onPressed: _openComments,
        ),

        _ActionButton(
          icon: _reposted ? Icons.repeat_on_rounded : Icons.repeat_rounded,
          label: _compactNumber(_repostCount),
          onPressed: _toggleRepost,
          active: _reposted,
        ),

        _ActionButton(
          icon: Icons.share_outlined,
          label: 'Share',
          onPressed: _sharePost,
        ),

        _ActionButton(
          icon: Icons.more_horiz_rounded,
          label: 'More',
          onPressed: _showPostMenu,
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
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.item.creatorId == null
              ? null
              : () => _openCreator(widget.item.creatorId!),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
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
  final bool active;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.30),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: IconButton(
              onPressed: onPressed,
              iconSize: 32,
              color: active ? const Color(0xFF2E7D5B) : Colors.white,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                icon,
                shadows: const [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  blurRadius: 5,
                  color: Colors.black,
                  offset: Offset(0, 1),
                ),
              ],
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
