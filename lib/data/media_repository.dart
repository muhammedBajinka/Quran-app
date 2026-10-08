import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audio/media_item.dart';
import '../services/media_worker_service.dart';

class MediaRepository {
  final SupabaseClient _client;

  MediaRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const _columns = '''
    id,
    content_type,
    title,
    speaker,
    description,
    media_type,
    media_url,
    thumbnail_url,
    thumbnail_path,
    creator_id,
    pinned,
    pin_order,
    downloads_enabled,
    comment_permission,
    visibility,
    published,
    created_at
  ''';

  Future<void> deleteOwnMedia(MediaItem item) async {
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous || item.creatorId != user.id) {
      throw StateError('Only the owner can delete this post.');
    }
    // The server validates ownership again and cleans storage before reporting
    // success. Never delete the database row directly from the app.
    await MediaWorkerService(supabase: _client).deleteMedia(item.id);
  }

  Future<List<MediaItem>> getItems(MediaItemType type) async {
    final rows = await _client
        .from('media_content')
        .select(_columns)
        .eq('published', true)
        .eq('content_type', type.name)
        .order('created_at', ascending: false);

    return _withSignedThumbnails(_mapRows(rows));
  }

  Future<List<MediaItem>> getAllPublished({
    String? mediaType,
    MediaItemType? contentType,
    bool shuffle = false,
  }) async {
    dynamic query = _client
        .from('media_content')
        .select(_columns)
        .eq('published', true);

    if (mediaType != null) {
      query = query.eq('media_type', mediaType);
    }

    if (contentType != null) {
      query = query.eq('content_type', contentType.name);
    }

    final rows = await query.order('created_at', ascending: false);

    final items = await _withSignedThumbnails(_mapRows(rows));

    if (shuffle) {
      items.shuffle(Random());
    }

    return items;
  }

  Future<List<MediaItem>> getSharedFeed(String id) async {
    final rows = await _client.from('media_content').select(_columns)
        .eq('id', id).eq('published', true).neq('visibility', 'private');
    final target = await _withSignedThumbnails(_mapRows(rows));
    if (target.isEmpty) return const [];
    final rest = await getForYouFeed();
    return [...target, ...rest.where((item) => item.id != id)];
  }

  Future<List<MediaItem>> getForYouFeed() async {
    final items = await getAllPublished();

    final pinned = items.where((item) => item.pinned).toList()
      ..sort((a, b) {
        final aOrder = a.pinOrder ?? 999999;
        final bOrder = b.pinOrder ?? 999999;
        return aOrder.compareTo(bOrder);
      });

    final regular = items.where((item) => !item.pinned).toList()
      ..shuffle(Random());

    return [...pinned, ...regular];
  }

  Future<List<MediaItem>> getCategoryFeed(MediaItemType type) {
    return getAllPublished(contentType: type, shuffle: true);
  }

  Future<List<MediaItem>> getVideoFeed() {
    return getAllPublished(mediaType: 'video', shuffle: true);
  }

  Future<List<MediaItem>> getAudioFeed() {
    return getAllPublished(mediaType: 'audio', shuffle: true);
  }

  Future<List<MediaItem>> searchPublished(String query) async {
    final search = query.trim();

    if (search.isEmpty) {
      return const [];
    }

    final pattern = '%$search%';

    final results = await Future.wait([
      _client
          .from('media_content')
          .select(_columns)
          .eq('published', true)
          .ilike('title', pattern)
          .order('created_at', ascending: false),
      _client
          .from('media_content')
          .select(_columns)
          .eq('published', true)
          .ilike('speaker', pattern)
          .order('created_at', ascending: false),
      _client
          .from('media_content')
          .select(_columns)
          .eq('published', true)
          .ilike('description', pattern)
          .order('created_at', ascending: false),
    ]);

    final seen = <String>{};
    final rows = <dynamic>[];

    for (final result in results) {
      for (final row in result) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = map['id']?.toString();

        if (id != null && seen.add(id)) {
          rows.add(map);
        }
      }
    }

    return _withSignedThumbnails(_mapRows(rows));
  }

  Future<List<MediaItem>> getPublishedMediaByIds(List<String> mediaIds) async {
    if (mediaIds.isEmpty) {
      return const [];
    }

    final rows = await _client
        .from('media_content')
        .select(_columns)
        .eq('published', true)
        .inFilter('id', mediaIds);

    final items = await _withSignedThumbnails(_mapRows(rows));
    final itemsById = <String, MediaItem>{
      for (final item in items) item.id: item,
    };

    return mediaIds.map((id) => itemsById[id]).whereType<MediaItem>().toList();
  }

  Future<List<MediaItem>> getCreatorPosts(String creatorId) async {
    final rows = await _client
        .from('media_content')
        .select(_columns)
        .eq('published', true)
        .eq('creator_id', creatorId)
        .neq('visibility', 'private')
        .order('created_at', ascending: false);

    return _withSignedThumbnails(_mapRows(rows));
  }

  Future<List<MediaItem>> getOwnDrafts() async {
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous) return const [];

    final rows = await _client
        .from('media_content')
        .select(_columns)
        .eq('creator_id', user.id)
        .eq('published', false)
        .order('created_at', ascending: false);

    return _withSignedThumbnails(_mapRows(rows));
  }

  Future<void> publishOwnDraft(
    String mediaId, {
    required String title,
    required String description,
    required String speaker,
    required String visibility,
    required bool publish,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Sign in required.');
    }

    if (title.trim().isEmpty || !['public', 'followers', 'private'].contains(visibility)) {
      throw ArgumentError('A title and valid visibility are required.');
    }
    final values = <String, dynamic>{
      'title': title.trim(),
      'description': description.isEmpty ? null : description,
      'speaker': speaker.isEmpty ? null : speaker,
      'visibility': publish ? visibility : 'private',
      'published': publish,
    };

    final updated = await _client
        .from('media_content')
        .update(values)
        .eq('id', mediaId)
        .eq('creator_id', user.id)
        .eq('published', false)
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw StateError('Draft unavailable or already published. Refresh your profile.');
    }
  }

  Future<List<MediaItem>> getOwnPrivatePosts() async {
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous) return const [];

    final rows = await _client
        .from('media_content')
        .select(_columns)
        .eq('creator_id', user.id)
        .eq('published', true)
        .eq('visibility', 'private')
        .order('created_at', ascending: false);

    return _withSignedThumbnails(_mapRows(rows));
  }

  Future<List<MediaItem>> _withSignedThumbnails(List<MediaItem> items) async {
    return Future.wait(
      items.map((item) async {
        final path = item.thumbnailPath?.trim();
        if (path == null || path.isEmpty) return item;

        try {
          final signed = await _client.storage
              .from('media-thumbnails')
              .createSignedUrl(path, 3600);
          return item.copyWith(thumbnailUrl: signed);
        } catch (_) {
          return item;
        }
      }),
    );
  }

  List<MediaItem> _mapRows(dynamic rows) {
    return (rows as List<dynamic>)
        .map((row) => _mapRow(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  MediaItem _mapRow(Map<String, dynamic> row) {
    final mediaType = (row['media_type'] as String?)?.toLowerCase();
    final mediaUrl = row['media_url'] as String?;

    return MediaItem(
      id: row['id'] as String,
      type: _parseType(row['content_type'] as String?),
      title: row['title'] as String? ?? 'Untitled',
      speaker: row['speaker'] as String?,
      description: row['description'] as String?,
      audioUrl: mediaType == 'audio' ? mediaUrl : null,
      videoUrl: mediaType == 'video' ? mediaUrl : null,
      thumbnailUrl: row['thumbnail_url'] as String?,
      thumbnailPath: row['thumbnail_path'] as String?,
      creatorId: row['creator_id'] as String?,
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      pinned: row['pinned'] as bool? ?? false,
      pinOrder: row['pin_order'] as int?,
      downloadsEnabled: row['downloads_enabled'] as bool? ?? true,
      commentPermission: row['comment_permission'] as String? ?? 'everyone',
      visibility: row['visibility'] as String? ?? 'public',
      published: row['published'] as bool? ?? true,
    );
  }

  MediaItemType _parseType(String? value) {
    switch (value?.toLowerCase()) {
      case 'sermon':
        return MediaItemType.sermon;
      case 'recitation':
        return MediaItemType.recitation;
      case 'other':
        return MediaItemType.other;
      case 'dua':
      default:
        return MediaItemType.dua;
    }
  }
}
