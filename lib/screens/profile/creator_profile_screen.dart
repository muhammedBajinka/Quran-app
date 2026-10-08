import 'package:flutter/material.dart';

import '../audio/audio_screen.dart';

import '../../data/media_repository.dart';
import '../../data/media_social_repository.dart';
import '../../models/audio/media_item.dart';
import '../../services/creator_upload_queue.dart';
import 'upload_media_screen.dart';
import 'creator_settings_screen.dart';
import 'edit_profile_screen.dart';

class CreatorProfileScreen extends StatefulWidget {
  final String creatorId;

  const CreatorProfileScreen({super.key, required this.creatorId});

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  final MediaRepository _mediaRepository = MediaRepository();
  final MediaSocialRepository _socialRepository = MediaSocialRepository();

  CreatorProfile? _profile;
  List<MediaItem> _posts = const [];
  List<MediaItem> _reposts = const [];
  List<MediaItem> _likedPosts = const [];
  List<MediaItem> _drafts = const [];
  List<MediaItem> _privatePosts = const [];
  Map<String, int> _viewCounts = const {};
  int _completedUploadCount = 0;

  bool _loading = true;
  bool _following = false;
  bool _followBusy = false;
  int _followerCount = 0;
  int _postCount = 0;
  int _totalLikes = 0;
  int _totalReposts = 0;
  Object? _error;

  bool get _isOwnProfile => _socialRepository.currentUserId == widget.creatorId;

  @override
  void initState() {
    super.initState();
    _completedUploadCount = CreatorUploadQueue.instance.jobs
        .where((job) => job.state == CreatorUploadState.completed)
        .length;
    CreatorUploadQueue.instance.addListener(_uploadQueueChanged);
    _load();
  }

  @override
  void dispose() {
    CreatorUploadQueue.instance.removeListener(_uploadQueueChanged);
    super.dispose();
  }

  void _uploadQueueChanged() {
    if (!mounted) return;
    final completed = CreatorUploadQueue.instance.jobs
        .where((job) => job.state == CreatorUploadState.completed)
        .length;
    setState(() {});
    if (completed > _completedUploadCount) {
      _completedUploadCount = completed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _socialRepository.getCreatorProfile(widget.creatorId),
        _mediaRepository.getCreatorPosts(widget.creatorId),
        if (!_isOwnProfile)
          _socialRepository.isFollowing(widget.creatorId)
        else
          Future<bool>.value(false),
        _socialRepository.getFollowerCount(widget.creatorId),
        _socialRepository.getRepostedMediaIds(widget.creatorId),
        _socialRepository.getLikedMediaIds(widget.creatorId),
        if (_isOwnProfile)
          _mediaRepository.getOwnDrafts()
        else
          Future<List<MediaItem>>.value(const []),
        if (_isOwnProfile)
          _mediaRepository.getOwnPrivatePosts()
        else
          Future<List<MediaItem>>.value(const []),
        _socialRepository.getCreatorMediaStats(widget.creatorId),
      ]);

      final posts = results[1] as List<MediaItem>;
      final repostIds = results[4] as List<String>;
      final likedIds = results[5] as List<String>;
      final drafts = results[6] as List<MediaItem>;
      final privatePosts = results[7] as List<MediaItem>;
      final mediaStats = results[8] as CreatorMediaStats;

      final mediaResults = await Future.wait([
        _mediaRepository.getPublishedMediaByIds(repostIds),
        _mediaRepository.getPublishedMediaByIds(likedIds),
      ]);

      final reposts = mediaResults[0];
      final likedPosts = mediaResults[1];

      final allVisibleItems = <String, MediaItem>{
        for (final item in posts) item.id: item,
        for (final item in reposts) item.id: item,
        for (final item in likedPosts) item.id: item,
      }.values.toList();

      final viewCounts = await Future.wait(
        allVisibleItems.map((item) => _socialRepository.getViewCount(item.id)),
      );

      final viewsByMediaId = <String, int>{
        for (var i = 0; i < allVisibleItems.length; i++)
          allVisibleItems[i].id: viewCounts[i],
      };

      if (!mounted) return;

      setState(() {
        _profile = results[0] as CreatorProfile?;
        _posts = posts;
        _reposts = reposts;
        _likedPosts = likedPosts;
        _drafts = drafts;
        _privatePosts = privatePosts;
        _viewCounts = viewsByMediaId;
        _following = results[2] as bool;
        _followerCount = results[3] as int;
        _postCount = mediaStats.postCount;
        _totalLikes = mediaStats.totalLikeCount;
        _totalReposts = mediaStats.totalRepostCount;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_followBusy || _isOwnProfile) return;

    setState(() {
      _followBusy = true;
    });

    try {
      if (_following) {
        await _socialRepository.unfollow(widget.creatorId);
      } else {
        await _socialRepository.follow(widget.creatorId);
      }

      if (!mounted) return;

      setState(() {
        _following = !_following;

        if (_following) {
          _followerCount++;
        } else if (_followerCount > 0) {
          _followerCount--;
        }
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You need a creator account before you can follow people.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _followBusy = false;
        });
      }
    }
  }

  Future<void> _openUpload() async {
    if (!_isOwnProfile) {
      return;
    }

    final uploaded = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const UploadMediaScreen()),
    );

    if (uploaded == true && mounted) {
      await _load();
    }
  }

  Future<void> _openMedia(List<MediaItem> items, int initialIndex) async {
    if (items.isEmpty || initialIndex < 0 || initialIndex >= items.length) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreatorMediaFeedScreen(
          items: items,
          initialIndex: initialIndex,
          allowManagement: _isOwnProfile,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openEditProfile() async {
    final profile = _profile;

    if (profile == null || !_isOwnProfile) {
      return;
    }

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditProfileScreen(profile: profile),
      ),
    );

    if (updated == true && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          _profile?.username ?? 'Profile',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_isOwnProfile)
            IconButton(
              tooltip: 'Creator settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CreatorSettingsScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.black45),
          const SizedBox(height: 16),
          const Center(child: Text('Could not load this profile.')),
          const SizedBox(height: 12),
          Center(
            child: FilledButton(
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    final profile = _profile;

    if (profile == null || (profile.isSuspended && !_isOwnProfile)) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Icon(Icons.person_off_outlined, size: 52, color: Colors.black45),
          SizedBox(height: 16),
          Center(child: Text('This profile is unavailable.')),
        ],
      );
    }

    final tabs = <({String label, List<MediaItem> items, String empty})>[
      (label: 'Posts', items: _posts, empty: 'No posts yet.'),
      if (_isOwnProfile)
        (label: 'Drafts', items: _drafts, empty: 'No drafts yet.'),
      if (_isOwnProfile)
        (
          label: 'Private',
          items: _privatePosts,
          empty: 'No private posts yet.',
        ),
      (label: 'Reposts', items: _reposts, empty: 'No reposts yet.'),
      (label: 'Likes', items: _likedPosts, empty: 'No liked posts yet.'),
    ];

    return DefaultTabController(
      key: ValueKey<String>(tabs.map((tab) => tab.label).join('|')),
      length: tabs.length,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          if (_isOwnProfile && profile.isSuspended)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Your creator account is suspended. Uploading and publishing are disabled. You can still manage and delete your posts.\n${profile.moderationReason ?? "Contact admin through Settings → Feedback for help."}'),
              ),
            ),
          SliverToBoxAdapter(
            child: _ProfileHeader(
              profile: profile,
              followerCount: _followerCount,
              postCount: _postCount,
              totalLikes: _totalLikes,
              totalReposts: _totalReposts,
              isOwnProfile: _isOwnProfile,
              following: _following,
              followBusy: _followBusy,
              onFollowPressed: _toggleFollow,
              onEditProfile: _openEditProfile,
              onUpload: _openUpload,
            ),
          ),
          if (_isOwnProfile &&
              CreatorUploadQueue.instance.jobs.any(
                (job) => job.state != CreatorUploadState.completed,
              ))
            SliverToBoxAdapter(
              child: _UploadQueuePanel(
                jobs: CreatorUploadQueue.instance.jobs,
                onRetry: CreatorUploadQueue.instance.retry,
                onDismiss: CreatorUploadQueue.instance.removeCompleted,
              ),
            ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _ProfileTabsHeaderDelegate(
              labels: tabs.map((tab) => tab.label).toList(growable: false),
            ),
          ),
        ],
        body: TabBarView(
          children: [
            for (final tab in tabs)
              _ProfileMediaGrid(
                items: tab.items,
                viewCounts: _viewCounts,
                emptyMessage: tab.empty,
                onOpen: (index) => _openMedia(tab.items, index),
              ),
          ],
        ),
      ),
    );
  }
}

class _UploadQueuePanel extends StatelessWidget {
  final List<CreatorUploadJob> jobs;
  final ValueChanged<String> onRetry;
  final ValueChanged<String> onDismiss;

  const _UploadQueuePanel({
    required this.jobs,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final pending = jobs.toList();
    if (pending.isEmpty) return const SizedBox.shrink();

    final failed = pending
        .where(
          (job) =>
              job.state == CreatorUploadState.failed ||
              job.state == CreatorUploadState.needsReview,
        )
        .length;
    final label = failed > 0
        ? 'Uploads · ${pending.length} · $failed failed'
        : 'Uploading · ${pending.length}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: ActionChip(
          avatar: Icon(
            failed > 0 ? Icons.error_outline : Icons.cloud_upload_outlined,
            size: 18,
          ),
          label: Text(label),
          onPressed: () => _showDetails(context, pending),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, List<CreatorUploadJob> _) {
    final queue = CreatorUploadQueue.instance;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => AnimatedBuilder(
        animation: queue,
        builder: (context, _) {
          final pending = queue.jobs.toList(growable: false);
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                const Text(
                  'Uploads',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Upload progress appears here. Retry only resumes finalization; uncertain uploads must be checked before uploading again.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (pending.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('No pending uploads.'),
                  )
                else
                  for (final job in pending) _jobTile(job),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _jobTile(CreatorUploadJob job) {
    final percent = (job.progress * 100).round();
    String status;
    switch (job.state) {
      case CreatorUploadState.queued:
        status = 'Waiting';
      case CreatorUploadState.uploading:
        status = 'Uploading $percent%';
      case CreatorUploadState.finalizing:
        status = 'Finalizing post';
      case CreatorUploadState.completed:
        status = job.draft ? 'Draft saved' : 'Published';
      case CreatorUploadState.failed:
        status = job.error ?? 'Finalization failed';
      case CreatorUploadState.needsReview:
        status = job.error ?? 'Check your posts before uploading again';
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        job.mediaType == 'audio'
            ? Icons.audio_file_outlined
            : Icons.video_file_outlined,
      ),
      title: Text(job.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status),
          if (job.canRetry)
            TextButton(
              onPressed: () => onRetry(job.localId),
              child: const Text('Retry finalization'),
            ),
          if (job.state == CreatorUploadState.uploading)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: LinearProgressIndicator(value: job.progress),
            ),
        ],
      ),
      trailing:
          (job.state == CreatorUploadState.failed ||
              job.state == CreatorUploadState.needsReview ||
              job.state == CreatorUploadState.completed)
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [

                IconButton(
                  tooltip: 'Clear from queue',
                  onPressed: () => onDismiss(job.localId),
                  icon: const Icon(Icons.close),
                ),
              ],
            )
          : null,
    );
  }
}

class _ProfileTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<String> labels;

  const _ProfileTabsHeaderDelegate({required this.labels});

  @override
  double get minExtent => 52;

  @override
  double get maxExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Colors.white,
      elevation: overlapsContent ? 1 : 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5))),
        ),
        child: TabBar(
          indicatorColor: const Color(0xFF2E7D5B),
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: [for (final label in labels) Tab(text: label)],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ProfileTabsHeaderDelegate oldDelegate) {
    if (oldDelegate.labels.length != labels.length) return true;
    for (var i = 0; i < labels.length; i++) {
      if (oldDelegate.labels[i] != labels[i]) return true;
    }
    return false;
  }
}

class _ProfileMediaGrid extends StatelessWidget {
  final List<MediaItem> items;
  final Map<String, int> viewCounts;
  final String emptyMessage;
  final ValueChanged<int> onOpen;

  const _ProfileMediaGrid({
    required this.items,
    required this.viewCounts,
    required this.emptyMessage,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyMessage,
            style: const TextStyle(color: Colors.black54, fontSize: 16),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900
            ? 6
            : width >= 600
            ? 4
            : 3;
        return GridView.builder(
          key: PageStorageKey<String>(emptyMessage),
          padding: const EdgeInsets.all(2),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _ProfileMediaTile(
              item: item,
              viewCount: viewCounts[item.id] ?? 0,
              onTap: () => onOpen(index),
            );
          },
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final CreatorProfile profile;
  final int followerCount;
  final int postCount;
  final int totalLikes;
  final int totalReposts;
  final bool isOwnProfile;
  final bool following;
  final bool followBusy;
  final VoidCallback onFollowPressed;
  final VoidCallback onEditProfile;
  final VoidCallback onUpload;

  const _ProfileHeader({
    required this.profile,
    required this.followerCount,
    required this.postCount,
    required this.totalLikes,
    required this.totalReposts,
    required this.isOwnProfile,
    required this.following,
    required this.followBusy,
    required this.onFollowPressed,
    required this.onEditProfile,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile.avatarUrl?.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: const Color(0xFFE7F1EC),
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(
                    profile.visibleName.isEmpty
                        ? '?'
                        : profile.visibleName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E7D5B),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  profile.visibleName,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (profile.isVerified) ...[
                const SizedBox(width: 5),
                const _VerifiedBadge(),
              ],
            ],
          ),
          if (profile.username?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 3),
            Text(
              '@${profile.username!.trim()}',
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ] else if (isOwnProfile) ...[
            const SizedBox(height: 3),
            const Text(
              'Choose a username',
              style: TextStyle(color: Colors.black45, fontSize: 14),
            ),
          ],
          if (profile.bio?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              profile.bio!.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ProfileStat(value: '$postCount', label: 'Posts'),
              _ProfileStat(value: '$followerCount', label: 'Followers'),
              _ProfileStat(value: '$totalReposts', label: 'Reposts'),
              _ProfileStat(value: '$totalLikes', label: 'Likes'),
            ],
          ),
          const SizedBox(height: 20),
          if (isOwnProfile)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEditProfile,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit profile'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onUpload,
                    icon: const Icon(Icons.add),
                    label: const Text('Upload'),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: followBusy ? null : onFollowPressed,
                child: followBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(following ? 'Following' : 'Follow'),
              ),
            ),
          const SizedBox(height: 22),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return const Tooltip(
      message: 'Verified account',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFF2E7D5B),
          shape: BoxShape.circle,
        ),
        child: SizedBox(
          width: 18,
          height: 18,
          child: Icon(Icons.check_rounded, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;

  const _ProfileStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }
}

class _ProfileMediaTile extends StatelessWidget {
  final MediaItem item;
  final int viewCount;
  final VoidCallback onTap;

  const _ProfileMediaTile({
    required this.item,
    required this.viewCount,
    required this.onTap,
  });

  String _compactNumber(int value) {
    if (value >= 1000000000) {
      final number = value / 1000000000;
      return number >= 10
          ? '${number.toStringAsFixed(0)}B'
          : '${number.toStringAsFixed(1)}B';
    }

    if (value >= 1000000) {
      final number = value / 1000000;
      return number >= 10
          ? '${number.toStringAsFixed(0)}M'
          : '${number.toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      final number = value / 1000;
      return number >= 10
          ? '${number.toStringAsFixed(0)}K'
          : '${number.toStringAsFixed(1)}K';
    }

    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    final thumbnail = item.thumbnailUrl?.trim();

    return Semantics(
      button: true,
      label: 'Open ${item.title}',
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: const Color(0xFFF1F4F2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbnail != null && thumbnail.isNotEmpty)
                Image.network(
                  thumbnail,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fallback(),
                )
              else
                _fallback(),
              if (item.moderationBlocked)
                const Positioned(
                  top: 4,
                  left: 4,
                  right: 4,
                  child: ColoredBox(
                    color: Colors.black87,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Text('Blocked by admin', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              Positioned(
                left: 7,
                bottom: 7,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.hasVideo
                          ? Icons.play_arrow_rounded
                          : Icons.graphic_eq_rounded,
                      color: Colors.white,
                      size: 20,
                      shadows: const [
                        Shadow(blurRadius: 6, color: Colors.black87),
                      ],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _compactNumber(viewCount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF163D31), Color(0xFF2E7D5B)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.hasVideo ? Icons.play_circle_fill_rounded : Icons.graphic_eq,
              color: Colors.white,
              size: 38,
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
