import 'package:supabase_flutter/supabase_flutter.dart';

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

  MediaSocialRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// The currently signed-in Supabase user.
  User? get currentUser => _client.auth.currentUser;

  String? get currentUserId => currentUser?.id;

  // ---------------------------------------------------------------------------
  // CREATOR PROFILE
  // ---------------------------------------------------------------------------

  /// Loads the public profile used beside a Media post.
  Future<CreatorProfile?> getCreatorProfile(String creatorId) async {
    final row = await _client
        .from('profiles')
        .select(
          'user_id, username, display_name, bio, avatar_url, is_suspended',
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

  /// Returns the number of likes for a Media post.
  Future<int> getLikeCount(String mediaId) async {
    final rows = await _client
        .from('media_likes')
        .select('id')
        .eq('media_id', mediaId);

    return (rows as List<dynamic>).length;
  }

  /// Adds the current user's like.
  Future<void> like(String mediaId) async {
    final userId = currentUserId;

    if (userId == null) {
      return;
    }

    await _client.from('media_likes').insert({
      'media_id': mediaId,
      'anonymous_install_id': userId,
      'auth_user_id': userId,
      'user_id': userId,
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

    await _client.from('media_comments').insert({
      'media_id': mediaId,
      'anonymous_install_id': userId,
      'user_id': userId,
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

  Future<void> repost(String mediaId) async {
    final userId = currentUserId;

    if (userId == null) {
      return;
    }

    await _client.from('media_reposts').insert({
      'media_id': mediaId,
      'anonymous_install_id': userId,
      'user_id': userId,
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

    await _client.from('media_reports').insert({
      'media_id': mediaId,
      'anonymous_install_id': userId,
      'user_id': userId,
      'auth_user_id': userId,
      'reason': reason,
      'details': details?.trim().isEmpty == true ? null : details?.trim(),
      'status': 'pending',
    });
  }
}

/// Public information shown for the creator of a Media post.
class CreatorProfile {
  final String userId;
  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final bool isSuspended;

  const CreatorProfile({
    required this.userId,
    required this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
    required this.isSuspended,
  });

  String get visibleName {
    final name = displayName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    return username;
  }

  factory CreatorProfile.fromMap(Map<String, dynamic> row) {
    return CreatorProfile(
      userId: row['user_id'] as String,
      username: row['username'] as String? ?? 'creator',
      displayName: row['display_name'] as String?,
      bio: row['bio'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      isSuspended: row['is_suspended'] as bool? ?? false,
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
