import 'package:flutter/material.dart';

/// Participates in the gesture arena so vertical pages and child seek controls
/// keep their own gestures. A completed horizontal drag triggers only once.
class MediaSwipeSurface extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  const MediaSwipeSurface({super.key, required this.child, required this.onSwipeLeft, required this.onSwipeRight});

  @override
  State<MediaSwipeSurface> createState() => _MediaSwipeSurfaceState();
}

class _MediaSwipeSurfaceState extends State<MediaSwipeSurface> {
  double _distance = 0;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: (_) => _distance = 0,
    onHorizontalDragUpdate: (details) => _distance += details.primaryDelta ?? 0,
    onHorizontalDragCancel: () => _distance = 0,
    onHorizontalDragEnd: (details) {
      final distance = _distance;
      _distance = 0;
      final velocity = details.primaryVelocity ?? 0;
      if (distance.abs() < 48 && velocity.abs() < 450) return;
      final direction = distance.abs() >= 48 ? distance : velocity;
      if (direction < 0) {
        widget.onSwipeLeft();
      } else {
        widget.onSwipeRight();
      }
    },
    child: widget.child,
  );
}
