import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:video_trimmer/video_trimmer.dart';

Future<Uint8List?> trimVideoFile({
  required String? sourcePath,
  required double startMs,
  required double endMs,
}) async {
  if (sourcePath == null || sourcePath.isEmpty || endMs <= startMs) return null;

  final trimmer = Trimmer();
  try {
    await trimmer.loadVideo(videoFile: File(sourcePath));

    final outputCompleter = Completer<String?>();
    await trimmer.saveTrimmedVideo(
      startValue: startMs,
      endValue: endMs,
      onSave: (outputPath) {
        if (!outputCompleter.isCompleted) {
          outputCompleter.complete(outputPath);
        }
      },
    );

    final outputPath = await outputCompleter.future;
    if (outputPath == null || outputPath.isEmpty) return null;
    return await File(outputPath).readAsBytes();
  } finally {
    trimmer.dispose();
  }
}
