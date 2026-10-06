import 'dart:typed_data';

import 'package:flutter/material.dart';

class CreatorMediaEditor extends StatelessWidget {
  final Uint8List bytes;
  final String mediaType;
  final String mimeType;
  final String? sourcePath;
  final ValueChanged<RangeValues> onTrimChanged;
  final RangeValues trim;

  const CreatorMediaEditor({
    super.key,
    required this.bytes,
    required this.mediaType,
    required this.mimeType,
    required this.sourcePath,
    required this.trim,
    required this.onTrimChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 260),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          mediaType == 'video'
              ? 'Video preview and trimming are available in the Android app.'
              : 'Audio preview and trimming are available in the Android app.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
