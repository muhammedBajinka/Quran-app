import 'package:flutter/material.dart';
import '../data/media_social_repository.dart';

/// Uses the creator's chosen handle and the backend-controlled badge.
class MediaCreatorIdentity extends StatelessWidget {
  final CreatorProfile? creator;
  final String fallbackName;
  final VoidCallback? onPressed;
  const MediaCreatorIdentity({super.key, required this.creator, required this.fallbackName, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final username = creator?.username?.trim();
    final name = username?.isNotEmpty == true ? '@$username' : creator?.visibleName ?? fallbackName;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15,
                shadows: [Shadow(blurRadius: 5, color: Colors.black)]))),
            if (creator?.isVerified == true) ...[
              const SizedBox(width: 5),
              const Icon(Icons.verified_rounded, color: Color(0xFF2E7D5B), size: 19, semanticLabel: 'Verified creator'),
            ],
          ],
        ),
      ),
    );
  }
}
