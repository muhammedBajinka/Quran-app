import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/anonymous_install_service.dart';

/// Handles social actions for Media posts.
///
/// This repository keeps Supabase/database code out of the UI.
/// The Media feed will use it for:
/// - creator profiles
/// - following/unfollowing
/// - likes
/// - comments
/// - reposts
/// - reports
class MediaSocialRepository {
  final SupabaseClient _client;
  final AnonymousInstallService _installService;

  MediaSocialRepository({
    SupabaseClient? client,
    AnonymousInstallService? installService,
  }) : _client = client ?? Supabase.instance.client,
       _installService = installService ?? AnonymousInstallService();

  /// The currently signed-in Supabase user.
  User? get currentUser => _client.auth.currentUser;

  String? get currentUserId => currentUser?.id;

  /// Returns the profile user ID only when this auth user has a real profile.
  ///
  /// Anonymous browsing sessions normally have no profiles row, so social
  /// actions must leave user_id null instead of violating its foreign key.
  Future<String?> _currentProfileUserId() async {
    final userId = currentUserId;

    if (userId == null) {
      return null;
    }

    final row = await _client
        .from('profiles')
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();

    return row?['user_id']?.toString();
  }

  // ---------------------------------------------------------------------------
  // CREATOR PROFILE
  // ---------------------------------------------------------------------------

  /// Creates the signed-in user's creator profile if it does not exist.
  ///
  /// New accounts start without a username. The creator chooses their public
  /// username later from Edit profile.
  Future<void> ensureCurrentUserProfile() async {
    final user = currentUser;

    if (user == null || user.isAnonymous) {
      return;
    }

    final existing = await _client
        .from('profiles')
        .select('user_id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing != null) {
      return;
    }

    await _client.from('profiles').insert({'user_id': user.id});
  }

  /// Loads the public profile used beside a Media post.
  Future<CreatorProfile?> getCreatorProfile(String creatorId) async {
    final row = await _client
        .from('profiles')
        .select(
          'user_id, username, display_name, bio, avatar_url, is_suspended, is_verified',
        )
        .eq('user_id', creatorId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return CreatorProfile.fromMap(Map<String, dynamic>.from(row));
  }

  // ---------------------------------------------------------------------------
  // FOLLOWING
  // ---------------------------------------------------------------------------

  /// Returns true when the current user follows [creatorId].
  Future<bool> isFollowing(String creatorId) async {
    final userId = currentUserId;

    if (userId == null || userId == creatorId) {
      return false;
    }

    final row = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId)
        .eq('following_id', creatorId)
        .maybeSingle();

    return row != null;
  }

  /// Follows a creator.
  ///
  /// follower_id must equal auth.uid(), which matches the RLS policy.
  Future<void> follow(String creatorId) async {
    final userId = currentUserId;

    if (userId == null || userId == creatorId) {
      return;
    }

    await _client.from('follows').insert({
      'follower_id': userId,
      'following_id': creatorId,
    });
  }

  /// Removes the current user's follow for a creator.
  Future<void> unfollow(String creatorId) async {
    final userId = currentUserId;

    if (userId == null || userId == creatorId) {
      return;
    }

    await _client
        .from('follows')
        .delete()
        .eq('follower_id', userId)
        .eq('following_id', creatorId);
  }

  /// Returns the public aggregate follower count without exposing follow rows.
  Future<int> getFollowerCount(String creatorId) async {
    final count = await _client.rpc(
      'get_follower_count',
      params: {'p_user_id': creatorId},
    );
    return (count as num).toInt();
  }

  /// Returns the signed-in user's private following count.
  Future<int> getOwnFollowingCount() async {
    final user = currentUser;
    if (user == null || user.isAnonymous) return 0;

    final count = await _client.rpc('get_own_following_count');
    return (count as num).toInt();
  }

  /// Returns the IDs of creators followed by the current user.
  Future<List<String>> getFollowingCreatorIds() async {
    final userId = currentUserId;

    if (userId == null) {
      return const [];
    }

    final rows = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);

    return (rows as List<dynamic>)
        .map((row) => row['following_id']?.toString())
        .whereType<String>()
        .toList();
  }

  // ---------------------------------------------------------------------------
  // LIKES
  // ---------------------------------------------------------------------------

  /// Returns media IDs liked by this profile, newest first.
  Future<List<String>> getLikedMediaIds(String userId) async {
    final rows = await _client
        .from('media_likes')
        .select('media_id, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => row['media_id']?.toString())
        .whereType<String>()
        .toList();
  }

  /// Returns whether the current user has liked a Media post.
  Future<bool> hasLiked(String mediaId) async {
    final userId = currentUserId;

    if (userId == null) {
      return false;
    }

    final row = await _client
        .from('media_likes')
        .select('id')
        .eq('media_id', mediaId)
        .eq('auth_user_id', userId)
        .maybeSingle();

    return row != null;
  }

  /// Records a qualified Media view.
  Future<void> recordView(
    String mediaId, {
    int watchSeconds = 3,
    bool completed = false,
  }) async {
    final authUserId = currentUserId;
    final profileUserId = await _currentProfileUserId();

    await _client.from('media_views').insert({
      'media_id': mediaId,
      'anonymous_install_id': await _installService.getInstallId(),
      'auth_user_id': authUserId,
      'user_id': profileUserId,
      'watch_seconds': watchSeconds,
      'completed': completed,
    });
  }

  /// Returns the number of views for a Media post without exposing viewer rows.
  Future<int> getViewCount(String mediaId) async {
    final count = await _client.rpc(
      'get_media_view_count',
      params: {'p_media_id': mediaId},
    );

    return (count as num).toInt();
  }

  /// Returns the number of likes without exposing individual like rows.
  Future<int> getLikeCount(String mediaId) async {
    final count = await _client.rpc(
      'get_media_like_count',
      params: {'p_media_id': mediaId},
    );

    return (count as num).toInt();
  }

  /// Adds the current user's like.
  Future<void> like(String mediaId) async {
    final userId = currentUserId;

    if (userId == null) {
      return;
    }

    final profileUserId = await _currentProfileUserId();

    await _client.from('media_likes').insert({
      'media_id': mediaId,
      'anonymous_install_id': await _installService.getInstallId(),
      'auth_user_id': userId,
      'user_id': profileUserId,
    });
  }

  /// Removes the current user's like.
  Future<void> unlike(String mediaId) async {
    final userId = currentUserId;

    if (userId == null) {
      return;
    }

    await _client
        .from('media_likes')
        .delete()
        .eq('media_id', mediaId)
        .eq('auth_user_id', userId);
  }

  // ---------------------------------------------------------------------------
  // COMMENTS
  // ---------------------------------------------------------------------------

  /// Loads comments newest-first.
  Future<List<MediaComment>> getComments(String mediaId) async {
    final rows = await _client
        .from('media_comments')
        .select(
          'id, media_id, user_id, auth_user_id, display_name, '
          'comment_text, created_at',
        )
        .eq('media_id', mediaId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map(
          (row) => MediaComment.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  /// Returns the number of comments on a post.
  Future<int> getCommentCount(String mediaId) async {
    final rows = await _client
        .from('media_comments')
        .select('id')
        .eq('media_id', mediaId);

    return (rows as List<dynamic>).length;
  }

  /// Creates a comment owned by the current signed-in user.
  Future<void> addComment({
    required String mediaId,
    required String text,
    String? displayName,
  }) async {
    final userId = currentUserId;
    final cleanText = text.trim();

    if (userId == null || cleanText.isEmpty) {
      return;
    }

    final profileUserId = await _currentProfileUserId();

    await _client.from('media_comments').insert({
      'media_id': mediaId,
      'anonymous_install_id': await _installService.getInstallId(),
      'user_id': profileUserId,
      'auth_user_id': userId,
      'display_name': displayName,
      'comment_text': cleanText,
    });
  }

  /// Deletes one of the current user's own comments.
  Future<void> deleteComment(String commentId) async {
    final userId = currentUserId;

    if (userId == null) {
      return;
    }

    await _client
        .from('media_comments')
        .delete()
        .eq('id', commentId)
        .eq('auth_user_id', userId);
  }

  // ---------------------------------------------------------------------------
  // REPOSTS
  // ---------------------------------------------------------------------------

  /// Returns public reposted media IDs without exposing repost identity rows.
  Future<List<String>> getRepostedMediaIds(String userId) async {
    final rows = await _client.rpc(
      'get_profile_reposted_media_ids',
      params: {'p_user_id': userId},
    );

    return (rows as List<dynamic>)
        .map((row) => row['media_id']?.toString())
        .whereType<String>()
        .toList();
  }

  Future<bool> hasReposted(String mediaId) async {
    final userId = currentUserId;

    if (userId == null) {
      return false;
    }

    final row = await _client
        .from('media_reposts')
        .select('id')
        .eq('media_id', mediaId)
        .eq('auth_user_id', userId)
        .maybeSingle();

    return row != null;
  }

  Future<int> getRepostCount(String mediaId) async {
    final count = await _client.rpc(
      'get_media_repost_count',
      params: {'p_media_id': mediaId},
    );
    return (count as num).toInt();
  }

  Future<void> repost(String mediaId) async {
    final userId = currentUserId;

    if (userId == null) {
      return;
    }

    final profileUserId = await _currentProfileUserId();

    await _client.from('media_reposts').insert({
      'media_id': mediaId,
      'anonymous_install_id': await _installService.getInstallId(),
      'user_id': profileUserId,
      'auth_user_id': userId,
    });
  }

  Future<void> removeRepost(String mediaId) async {
    final userId = currentUserId;

    if (userId == null) {
      return;
    }

    await _client
        .from('media_reposts')
        .delete()
        .eq('media_id', mediaId)
        .eq('auth_user_id', userId);
  }

  // ---------------------------------------------------------------------------
  // REPORTING
  // ---------------------------------------------------------------------------

  /// Sends a report to the moderation/admin system.
  ///
  /// Creating a report does NOT automatically remove or punish a creator.
  /// An admin can review the report separately.
  Future<void> reportMedia({
    required String mediaId,
    required String reason,
    String? details,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      return;
    }

    final profileUserId = await _currentProfileUserId();

    await _client.from('media_reports').insert({
      'media_id': mediaId,
      'anonymous_install_id': await _installService.getInstallId(),
      'user_id': profileUserId,
      'auth_user_id': userId,
      'reason': reason,
      'details': details?.trim().isEmpty == true ? null : details?.trim(),
      'status': 'pending',
    });
  }

  /// Uploads a new avatar for the signed-in creator and stores its public URL.
  Future<String> uploadCurrentUserAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final user = currentUser;

    if (user == null || user.isAnonymous) {
      throw StateError('A signed-in account is required to upload an avatar.');
    }

    if (bytes.isEmpty) {
      throw const ProfileValidationException('The selected image is empty.');
    }

    if (bytes.length > 5 * 1024 * 1024) {
      throw const ProfileValidationException(
        'Profile photo must be 5 MB or smaller.',
      );
    }

    if (contentType != 'image/jpeg' &&
        contentType != 'image/png' &&
        contentType != 'image/webp') {
      throw const ProfileValidationException(
        'Choose a JPEG, PNG, or WebP image.',
      );
    }

    await ensureCurrentUserProfile();

    final storage = _client.storage.from('profile-avatars');
    final objectPath = '${user.id}/avatar';

    await storage.uploadBinary(
      objectPath,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: true,
        cacheControl: '3600',
      ),
    );

    final publicUrl = storage.getPublicUrl(objectPath);
    final avatarUrl = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

    await _client
        .from('profiles')
        .update({'avatar_url': avatarUrl})
        .eq('user_id', user.id);

    return avatarUrl;
  }

  /// Updates the signed-in creator's editable public profile fields.
  ///
  /// Usernames are normalized to lowercase before being saved. Database
  /// constraints remain the final authority for format and uniqueness.
  Future<void> updateCurrentUserProfile({
    required String username,
    required String displayName,
    required String bio,
  }) async {
    final user = currentUser;

    if (user == null || user.isAnonymous) {
      throw StateError('A signed-in account is required to edit a profile.');
    }

    final normalizedUsername = username.trim().toLowerCase();
    final normalizedDisplayName = displayName.trim();
    final normalizedBio = bio.trim();

    if (normalizedUsername.length < 3 ||
        normalizedUsername.length > 30 ||
        !RegExp(r'^[a-z0-9_]+$').hasMatch(normalizedUsername)) {
      throw const ProfileValidationException(
        'Username must be 3–30 characters using only lowercase letters, numbers, and underscores.',
      );
    }

    await ensureCurrentUserProfile();

    try {
      await _client
          .from('profiles')
          .update({
            'username': normalizedUsername,
            'display_name': normalizedDisplayName.isEmpty
                ? null
                : normalizedDisplayName,
            'bio': normalizedBio.isEmpty ? null : normalizedBio,
          })
          .eq('user_id', user.id);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw const ProfileValidationException(
          'That username is already taken.',
        );
      }

      rethrow;
    }
  }
}

class ProfileValidationException implements Exception {
  final String message;

  const ProfileValidationException(this.message);

  @override
  String toString() => message;
}

/// Public information shown for the creator of a Media post.
class CreatorProfile {
  final String userId;
  final String? username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final bool isSuspended;
  final bool isVerified;

  const CreatorProfile({
    required this.userId,
    this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
    required this.isSuspended,
    required this.isVerified,
  });

  String get visibleName {
    final name = displayName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final handle = username?.trim();

    if (handle != null && handle.isNotEmpty) {
      return handle;
    }

    return 'New creator';
  }

  factory CreatorProfile.fromMap(Map<String, dynamic> row) {
    return CreatorProfile(
      userId: row['user_id'] as String,
      username: row['username'] as String?,
      displayName: row['display_name'] as String?,
      bio: row['bio'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      isSuspended: row['is_suspended'] as bool? ?? false,
      isVerified: row['is_verified'] as bool? ?? false,
    );
  }
}

/// A comment displayed in the Media comments sheet.
class MediaComment {
  final String id;
  final String mediaId;
  final String? userId;
  final String? authUserId;
  final String? displayName;
  final String text;
  final DateTime? createdAt;

  const MediaComment({
    required this.id,
    required this.mediaId,
    this.userId,
    this.authUserId,
    this.displayName,
    required this.text,
    this.createdAt,
  });

  factory MediaComment.fromMap(Map<String, dynamic> row) {
    return MediaComment(
      id: row['id'] as String,
      mediaId: row['media_id'] as String,
      userId: row['user_id'] as String?,
      authUserId: row['auth_user_id'] as String?,
      displayName: row['display_name'] as String?,
      text: row['comment_text'] as String? ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
    );
  }
}
