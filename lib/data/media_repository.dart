import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audio/media_item.dart';

class MediaRepository {
  final SupabaseClient _supabase;

  MediaRepository({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  Future<List<MediaItem>> getItems(MediaItemType type) async {
    final contentType = switch (type) {
      MediaItemType.dua => 'dua',
      MediaItemType.sermon => 'sermon',
      MediaItemType.recitation => 'recitation',
    };

    final rows = await _supabase
        .from('media_content')
        .select(
          'id, content_type, title, description, media_type, media_url, created_at',
        )
        .eq('content_type', contentType)
        .eq('published', true)
        .order('created_at', ascending: false);

    return rows.map<MediaItem>(_mapRow).toList();
  }

  Future<List<MediaItem>> getAllPublished({
    String? mediaType,
    bool shuffle = false,
  }) async {
    var query = _supabase
        .from('media_content')
        .select(
          'id, content_type, title, description, media_type, media_url, created_at',
        )
        .eq('published', true);

    if (mediaType != null) {
      query = query.eq('media_type', mediaType);
    }

    final rows = await query.order('created_at', ascending: false);

    final items = rows.map<MediaItem>(_mapRow).toList();

    if (shuffle && items.length > 1) {
      items.shuffle(Random());
    }

    return items;
  }

  Future<List<MediaItem>> getVideoFeed() {
    return getAllPublished(mediaType: 'video', shuffle: true);
  }

  Future<List<MediaItem>> getAudioFeed() {
    return getAllPublished(mediaType: 'audio', shuffle: true);
  }

  MediaItem _mapRow(Map<String, dynamic> row) {
    final mediaType = row['media_type'] as String?;
    final mediaUrl = row['media_url'] as String?;

    final contentType = row['content_type'] as String?;

    final type = switch (contentType) {
      'dua' => MediaItemType.dua,
      'sermon' => MediaItemType.sermon,
      'recitation' => MediaItemType.recitation,
      _ => MediaItemType.recitation,
    };

    return MediaItem(
      id: row['id'] as String,
      type: type,
      title: row['title'] as String,
      description: row['description'] as String?,
      audioUrl: mediaType == 'audio' ? mediaUrl : null,
      videoUrl: mediaType == 'video' ? mediaUrl : null,
    );
  }
}
