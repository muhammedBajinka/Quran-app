import 'package:flutter/material.dart';

import '../data/media_social_repository.dart';
import '../models/audio/media_item.dart';
import 'media_creator_identity.dart';

/// Search previews do not create players. Playback starts after a tap.
class MediaSearchResults extends StatelessWidget {
  final List<MediaItem> items;
  final List<CreatorProfile> creators;
  final ValueChanged<int> onOpenMedia;
  final ValueChanged<String> onOpenCreator;
  const MediaSearchResults({
    super.key,
    required this.items,
    required this.creators,
    required this.onOpenMedia,
    required this.onOpenCreator,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && creators.isEmpty) {
      return const Center(
        child: Text(
          'No posts or creators found.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    return CustomScrollView(
      slivers: [
        if (creators.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Creators',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final creator = creators[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: creator.avatarUrl?.isNotEmpty == true
                      ? NetworkImage(creator.avatarUrl!)
                      : null,
                  child: creator.avatarUrl?.isNotEmpty == true
                      ? null
                      : const Icon(Icons.person),
                ),
                title: MediaCreatorIdentity(
                  creator: creator,
                  fallbackName: creator.visibleName,
                ),
                subtitle: creator.username == null
                    ? null
                    : Text(
                        creator.visibleName,
                        style: const TextStyle(color: Colors.white70),
                      ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
                ),
                onTap: () => onOpenCreator(creator.userId),
              );
            }, childCount: creators.length),
          ),
        ],
        if (items.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Posts',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 12,
                childAspectRatio: .62,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = items[index];
                return Semantics(
                  button: true,
                  label: 'Open ${item.title}',
                  child: InkWell(
                    onTap: () => onOpenMedia(index),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SizedBox(
                            width: double.infinity,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ColoredBox(
                                color: Colors.white12,
                                child: item.hasThumbnail
                                    ? Image.network(
                                        item.thumbnailUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, error, stack) => Icon(
                                          item.hasVideo
                                              ? Icons.videocam
                                              : Icons.graphic_eq,
                                          color: Colors.white70,
                                        ),
                                      )
                                    : Icon(
                                        item.hasVideo
                                            ? Icons.videocam
                                            : Icons.graphic_eq,
                                        color: Colors.white70,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          item.speaker ?? (item.hasVideo ? 'Video' : 'Audio'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }, childCount: items.length),
            ),
          ),
        ],
      ],
    );
  }
}
