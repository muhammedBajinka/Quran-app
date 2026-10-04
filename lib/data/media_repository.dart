import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audio/media_item.dart';

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
    creator_id,
    pinned,
    pin_order,
    downloads_enabled,
    created_at
  ''';

  Future<List<MediaItem>> getItems(MediaItemType type) async {
    final rows = await _client
        .from('media_content')
        .select(_columns)
        .eq('published', true)
        .eq('content_type', type.name)
        .order('created_at', ascending: false);

    return _mapRows(rows);
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

    final items = _mapRows(rows);

    if (shuffle) {
      items.shuffle(Random());
    }

    return items;
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

  Future<List<MediaItem>> getCreatorPosts(String creatorId) async {
    final rows = await _client
        .from('media_content')
        .select(_columns)
        .eq('published', true)
        .eq('creator_id', creatorId)
        .order('created_at', ascending: false);

    return _mapRows(rows);
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
      creatorId: row['creator_id'] as String?,
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      pinned: row['pinned'] as bool? ?? false,
      pinOrder: row['pin_order'] as int?,
      downloadsEnabled: row['downloads_enabled'] as bool? ?? false,
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
