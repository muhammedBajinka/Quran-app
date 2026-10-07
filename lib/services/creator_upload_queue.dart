import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'media_worker_service.dart';

enum CreatorUploadState { queued, uploading, finalizing, completed, failed, needsReview }

class CreatorUploadJob {
  final String localId;
  final String fileName;
  final Uint8List bytes;
  final String mimeType;
  final String contentType;
  final String mediaType;
  final String title;
  final String description;
  final String speaker;
  final String visibility;
  final bool draft;
  final Uint8List? thumbnailBytes;
  final String? thumbnailMimeType;

  CreatorUploadState state;
  double progress;
  String? error;
  String? mediaId;
  bool uploadAttempted = false;

  CreatorUploadJob({
    required this.localId,
    required this.fileName,
    required this.bytes,
    required this.mimeType,
    required this.contentType,
    required this.mediaType,
    required this.title,
    required this.description,
    required this.speaker,
    required this.visibility,
    required this.draft,
    this.thumbnailBytes,
    this.thumbnailMimeType,
    this.state = CreatorUploadState.queued,
    this.progress = 0,
    this.error,
    this.mediaId,
  });

  bool get canRetry =>
      state == CreatorUploadState.failed && mediaId != null;

  bool get isActive =>
      state == CreatorUploadState.queued ||
      state == CreatorUploadState.uploading ||
      state == CreatorUploadState.finalizing;
}

class CreatorUploadQueue extends ChangeNotifier {
  CreatorUploadQueue._();

  static final CreatorUploadQueue instance = CreatorUploadQueue._();

  final MediaWorkerService _worker = MediaWorkerService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final List<CreatorUploadJob> _jobs = [];

  bool _processing = false;

  List<CreatorUploadJob> get jobs => List.unmodifiable(_jobs);
  bool get hasActiveUploads => _jobs.any((job) => job.isActive);

  void enqueue(CreatorUploadJob job) {
    _jobs.insert(0, job);
    notifyListeners();
    _process();
  }

  void retry(String localId) {
    CreatorUploadJob? job;
    for (final item in _jobs) {
      if (item.localId == localId) {
        job = item;
        break;
      }
    }
    if (job == null || !job.canRetry) return;

    job
      ..state = CreatorUploadState.queued
      ..progress = 0
      ..error = null;
    notifyListeners();
    _process();
  }

  void removeCompleted(String localId) {
    _jobs.removeWhere(
      (job) =>
          job.localId == localId &&
          (job.state == CreatorUploadState.completed ||
              job.state == CreatorUploadState.failed ||
              job.state == CreatorUploadState.needsReview),
    );
    notifyListeners();
  }

  Future<void> _process() async {
    if (_processing) return;
    _processing = true;

    try {
      while (true) {
        CreatorUploadJob? next;
        for (final job in _jobs.reversed) {
          if (job.state == CreatorUploadState.queued) {
            next = job;
            break;
          }
        }
        if (next == null) break;
        await _run(next);
      }
    } finally {
      _processing = false;
      notifyListeners();
    }
  }

  Future<void> _run(CreatorUploadJob job) async {
    job
      ..state = CreatorUploadState.uploading
      ..progress = job.mediaId == null ? 0 : 1
      ..error = null;
    notifyListeners();

    try {
      var mediaId = job.mediaId;

      if (mediaId == null) {
        // Once a request might have reached R2, never blindly upload it again.
        job.uploadAttempted = true;
        final result = await _worker.uploadMedia(
          bytes: job.bytes,
          mimeType: job.mimeType,
          contentType: job.contentType,
          mediaType: job.mediaType,
          title: job.title,
          description: job.description,
          speaker: job.speaker,
          onProgress: (progress) {
            job.progress = progress.clamp(0.0, 1.0).toDouble();
            notifyListeners();
          },
        );

        mediaId = _extractMediaId(result);
        if (mediaId == null) {
          throw StateError('Upload finished but the media ID was not returned.');
        }
        job.mediaId = mediaId;
      }

      job
        ..state = CreatorUploadState.finalizing
        ..progress = 1;
      notifyListeners();

      String? thumbnailPath;
      final thumbnailBytes = job.thumbnailBytes;
      final thumbnailMimeType = job.thumbnailMimeType;
      final userId = _supabase.auth.currentUser?.id;

      if (thumbnailBytes != null &&
          thumbnailMimeType != null &&
          userId != null) {
        thumbnailPath = '$userId/$mediaId';
        await _supabase.storage.from('media-thumbnails').uploadBinary(
          thumbnailPath,
          thumbnailBytes,
          fileOptions: FileOptions(
            contentType: thumbnailMimeType,
            upsert: true,
            cacheControl: '3600',
          ),
        );
      }

      await _supabase.rpc(
        'finalize_creator_media',
        params: {
          'p_id': mediaId,
          'p_visibility': job.visibility,
          'p_published': !job.draft,
          'p_thumbnail_path': thumbnailPath,
        },
      );

      job.state = CreatorUploadState.completed;
      notifyListeners();
    } catch (error) {
      if (job.uploadAttempted && job.mediaId == null) {
        job
          ..state = CreatorUploadState.needsReview
          ..error = 'Upload result uncertain. Check your posts before selecting the file again. Retry is disabled to prevent duplicate R2 uploads.';
      } else {
        job
          ..state = CreatorUploadState.failed
          ..error = _friendlyError(error);
      }
      notifyListeners();
    }
  }

  String? _extractMediaId(Map<String, dynamic> result) {
    final direct =
        result['mediaId']?.toString() ?? result['id']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;

    final media = result['media'];
    if (media is Map) {
      final id = media['mediaId']?.toString() ?? media['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }

    final data = result['data'];
    if (data is Map) {
      final id = data['mediaId']?.toString() ?? data['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }

    return null;
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('StateError: ', '').trim();
    if (message.isEmpty) return 'Upload failed. Check your connection and retry.';
    if (message.length > 180) {
      return 'Upload failed. Check your connection and retry.';
    }
    return message;
  }
}
