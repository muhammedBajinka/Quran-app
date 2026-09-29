enum MediaItemType { dua, sermon, recitation }

class MediaItem {
  final String id;
  final MediaItemType type;
  final String title;
  final String? speaker;
  final String? description;
  final String? audioUrl;
  final String? videoUrl;
  final String? thumbnailUrl;

  const MediaItem({
    required this.id,
    required this.type,
    required this.title,
    this.speaker,
    this.description,
    this.audioUrl,
    this.videoUrl,
    this.thumbnailUrl,
  });

  bool get hasAudio => audioUrl != null && audioUrl!.trim().isNotEmpty;

  bool get hasVideo => videoUrl != null && videoUrl!.trim().isNotEmpty;
}
