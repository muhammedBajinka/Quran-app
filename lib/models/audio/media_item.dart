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
  final String? thumbnailPath;

  final String? creatorId;
  final DateTime? createdAt;

  final bool pinned;
  final int? pinOrder;
  final bool downloadsEnabled;
  final String commentPermission;
  final String visibility;
  final bool published;

  const MediaItem({
    required this.id,
    required this.type,
    required this.title,
    this.speaker,
    this.description,
    this.audioUrl,
    this.videoUrl,
    this.thumbnailUrl,
    this.thumbnailPath,
    this.creatorId,
    this.createdAt,
    this.pinned = false,
    this.pinOrder,
    this.downloadsEnabled = true,
    this.commentPermission = 'everyone',
    this.visibility = 'public',
    this.published = true,
  });

  bool get hasAudio => audioUrl != null && audioUrl!.trim().isNotEmpty;

  bool get hasVideo => videoUrl != null && videoUrl!.trim().isNotEmpty;

  bool get hasThumbnail =>
      thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty;

  MediaItem copyWith({String? thumbnailUrl}) {
    return MediaItem(
      id: id,
      type: type,
      title: title,
      speaker: speaker,
      description: description,
      audioUrl: audioUrl,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      thumbnailPath: thumbnailPath,
      creatorId: creatorId,
      createdAt: createdAt,
      pinned: pinned,
      pinOrder: pinOrder,
      downloadsEnabled: downloadsEnabled,
      commentPermission: commentPermission,
      visibility: visibility,
      published: published,
    );
  }
}
