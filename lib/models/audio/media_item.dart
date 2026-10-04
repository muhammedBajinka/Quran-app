enum MediaItemType { dua, sermon, recitation, other }

class MediaItem {
  final String id;
  final MediaItemType type;
  final String title;
  final String? speaker;
  final String? description;

  final String? audioUrl;
  final String? videoUrl;
  final String? thumbnailUrl;

  final String? creatorId;
  final DateTime? createdAt;

  final bool pinned;
  final int? pinOrder;

  const MediaItem({
    required this.id,
    required this.type,
    required this.title,
    this.speaker,
    this.description,
    this.audioUrl,
    this.videoUrl,
    this.thumbnailUrl,
    this.creatorId,
    this.createdAt,
    this.pinned = false,
    this.pinOrder,
  });

  bool get hasAudio => audioUrl != null && audioUrl!.trim().isNotEmpty;

  bool get hasVideo => videoUrl != null && videoUrl!.trim().isNotEmpty;

  bool get hasThumbnail =>
      thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty;
}
