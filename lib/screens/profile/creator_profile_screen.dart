import 'package:flutter/material.dart';

import '../../data/media_repository.dart';
import '../../data/media_social_repository.dart';
import '../../models/audio/media_item.dart';

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
  Map<String, int> _viewCounts = const {};

  bool _loading = true;
  bool _following = false;
  bool _followBusy = false;
  int _followerCount = 0;
  int _followingCount = 0;
  int _totalLikes = 0;
  Object? _error;

  bool get _isOwnProfile => _socialRepository.currentUserId == widget.creatorId;

  @override
  void initState() {
    super.initState();
    _load();
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
        _socialRepository.getFollowingCount(widget.creatorId),
      ]);

      final posts = results[1] as List<MediaItem>;

      final likeCounts = await Future.wait(
        posts.map((item) => _socialRepository.getLikeCount(item.id)),
      );

      final viewCounts = await Future.wait(
        posts.map((item) => _socialRepository.getViewCount(item.id)),
      );

      final viewsByMediaId = <String, int>{
        for (var i = 0; i < posts.length; i++) posts[i].id: viewCounts[i],
      };

      final totalLikes = likeCounts.fold<int>(
        0,
        (total, count) => total + count,
      );

      if (!mounted) return;

      setState(() {
        _profile = results[0] as CreatorProfile?;
        _posts = posts;
        _viewCounts = viewsByMediaId;
        _following = results[2] as bool;
        _followerCount = results[3] as int;
        _followingCount = results[4] as int;
        _totalLikes = totalLikes;
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

  void _openUpload() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Creator Studio is being connected next.')),
    );
  }

  void _openEditProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile editing is being connected next.')),
    );
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

    if (profile == null || profile.isSuspended) {
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

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _ProfileHeader(
            profile: profile,
            followerCount: _followerCount,
            followingCount: _followingCount,
            totalLikes: _totalLikes,
            isOwnProfile: _isOwnProfile,
            following: _following,
            followBusy: _followBusy,
            onFollowPressed: _toggleFollow,
            onEditProfile: _openEditProfile,
            onUpload: _openUpload,
          ),
        ),
        if (_posts.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No posts yet.',
                  style: TextStyle(color: Colors.black54, fontSize: 16),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(2),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = _posts[index];

                return _ProfileMediaTile(
                  item: item,
                  viewCount: _viewCounts[item.id] ?? 0,
                );
              }, childCount: _posts.length),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 0.78,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final CreatorProfile profile;
  final int followerCount;
  final int followingCount;
  final int totalLikes;
  final bool isOwnProfile;
  final bool following;
  final bool followBusy;
  final VoidCallback onFollowPressed;
  final VoidCallback onEditProfile;
  final VoidCallback onUpload;

  const _ProfileHeader({
    required this.profile,
    required this.followerCount,
    required this.followingCount,
    required this.totalLikes,
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
          Text(
            profile.visibleName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            '@${profile.username}',
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ProfileStat(value: '$followingCount', label: 'Following'),
              const SizedBox(width: 44),
              _ProfileStat(value: '$followerCount', label: 'Followers'),
              const SizedBox(width: 44),
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

  const _ProfileMediaTile({required this.item, required this.viewCount});

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

    return Container(
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
                  shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
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
    );
  }

  Widget _fallback() {
    return const Center(
      child: Icon(Icons.perm_media_outlined, color: Colors.black38, size: 34),
    );
  }
}
