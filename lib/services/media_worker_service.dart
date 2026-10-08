import 'error_report_service.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class MediaDeletionException implements Exception {
  final String message;
  const MediaDeletionException(this.message);

  static MediaDeletionException fromResponse(int status, String body) {
    String detail = '';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        detail = decoded['error']?.toString() ?? '';
      }
    } catch (_) {
      // A non-JSON gateway error is still a failed deletion.
    }
    if (status == 401) {
      return const MediaDeletionException(
        'Your session expired. Sign in again and retry.',
      );
    }
    if (status == 403) {
      return const MediaDeletionException(
        'You do not have permission to delete this post.',
      );
    }
    if (status == 404) {
      return const MediaDeletionException(
        'This post is unavailable. Reopen your profile to check it.',
      );
    }
    if (status == 409 && detail.contains('migration')) {
      return const MediaDeletionException(
        'This older upload needs a storage update before it can be deleted.',
      );
    }
    if (status == 409) {
      return const MediaDeletionException(
        'The media file could not be verified for deletion.',
      );
    }
    return MediaDeletionException(
      'Delete failed (server $status). Please try again.',
    );
  }
}

class MediaWorkerService {
  static const String _baseUrl =
      'https://quran-media-worker.muhammedbajinka02.workers.dev';

  final SupabaseClient _supabase;

  MediaWorkerService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  Future<Map<String, dynamic>> uploadMedia({
    required Uint8List bytes,
    required String mimeType,
    required String contentType,
    required String mediaType,
    required String title,
    String? description,
    String? speaker,
    void Function(double progress)? onProgress,
  }) async {
    final session = _supabase.auth.currentSession;

    if (session == null) {
      throw StateError('No active Supabase session.');
    }

    final user = session.user;

    debugPrint('[UPLOAD] Starting Worker upload');
    debugPrint('[UPLOAD] User ID: ${user.id}');
    debugPrint('[UPLOAD] Anonymous: ${user.isAnonymous}');
    debugPrint('[UPLOAD] Bytes: ${bytes.length}');
    debugPrint('[UPLOAD] MIME: $mimeType');
    debugPrint('[UPLOAD] Content type: $contentType');
    debugPrint('[UPLOAD] Media type: $mediaType');

    if (user.isAnonymous) {
      throw StateError('A Google or other real account is required to upload.');
    }

    final request = http.StreamedRequest('POST', Uri.parse('$_baseUrl/upload'));

    request.headers.addAll({
      'Authorization': 'Bearer ${session.accessToken}',
      'Accept': 'application/json',
      'Content-Type': mimeType,
      'X-Content-Type': contentType,
      'X-Media-Type': mediaType,
      'X-Title': title,
    });

    final cleanDescription = description?.trim();
    final cleanSpeaker = speaker?.trim();

    if (cleanDescription != null && cleanDescription.isNotEmpty) {
      request.headers['X-Description'] = cleanDescription;
    }

    if (cleanSpeaker != null && cleanSpeaker.isNotEmpty) {
      request.headers['X-Speaker'] = cleanSpeaker;
    }

    request.contentLength = bytes.length;

    debugPrint('[UPLOAD] Sending request to $_baseUrl/upload');
    final responseFuture = request.send();
    const chunkSize = 256 * 1024;
    var sent = 0;

    for (var offset = 0; offset < bytes.length; offset += chunkSize) {
      final end = (offset + chunkSize < bytes.length)
          ? offset + chunkSize
          : bytes.length;
      request.sink.add(bytes.sublist(offset, end));
      sent = end;
      onProgress?.call(sent / bytes.length);
      await Future<void>.delayed(Duration.zero);
    }

    await request.sink.close();
    try {
      final streamedResponse = await responseFuture;
      debugPrint('[UPLOAD] Worker HTTP status: ${streamedResponse.statusCode}');

      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('[UPLOAD] Worker response body: ${response.body}');

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (error, stackTrace) {
        debugPrint('[UPLOAD] Invalid Worker JSON: $error');
        debugPrintStack(stackTrace: stackTrace);
        throw StateError(
          'Worker HTTP ${response.statusCode}: invalid response body.',
        );
      }

      if (decoded is! Map<String, dynamic>) {
        throw StateError(
          'Worker HTTP ${response.statusCode}: invalid response from media server.',
        );
      }

      if (response.statusCode != 201) {
        final workerError =
            decoded['error']?.toString() ??
            decoded['message']?.toString() ??
            'Media upload failed.';
        throw StateError('Worker HTTP ${response.statusCode}: $workerError');
      }

      debugPrint('[UPLOAD] Worker upload succeeded.');
      return decoded;
    } catch (error, stackTrace) {
      unawaited(ErrorReportService.report('WORKER_UPLOAD_FAILED', error: error, source: 'media_worker'));
      debugPrint('[UPLOAD] FAILURE: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> deleteMedia(String mediaId) async {
    var session = _supabase.auth.currentSession;
    if (session == null || session.user.isAnonymous) {
      throw const MediaDeletionException('Sign in to delete your post.');
    }
    final expiresAt = session.expiresAt;
    if (expiresAt != null &&
        expiresAt <= DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60) {
      try {
        session = (await _supabase.auth.refreshSession()).session;
      } catch (_) {
        throw const MediaDeletionException(
          'Your session expired. Sign in again and retry.',
        );
      }
      if (session == null) {
        throw const MediaDeletionException(
          'Your session expired. Sign in again and retry.',
        );
      }
    }
    final http.Response response;
    try {
      response = await http
          .delete(
            Uri.parse('$_baseUrl/media/${Uri.encodeComponent(mediaId)}'),
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException catch (error) {
      unawaited(ErrorReportService.report('DELETE_FAILED', error: error, source: 'media_worker'));
      throw const MediaDeletionException(
        'The request timed out. Check whether the post is gone before retrying.',
      );
    } on http.ClientException catch (error) {
      unawaited(ErrorReportService.report('DELETE_FAILED', error: error, source: 'media_worker'));
      throw const MediaDeletionException(
        'Could not connect. Check your internet connection and retry.',
      );
    }
    if (response.statusCode != 200) {
      unawaited(ErrorReportService.report('DELETE_FAILED', error: StateError('Worker HTTP ${response.statusCode}:'), source: 'media_worker'));
      debugPrint('[DELETE] HTTP ${response.statusCode}: ${response.body}');
      throw MediaDeletionException.fromResponse(
        response.statusCode,
        response.body,
      );
    }
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      throw const MediaDeletionException(
        'The server did not confirm deletion. Please try again.',
      );
    }
    if (body is! Map<String, dynamic> || body['deleted'] != mediaId) {
      throw const MediaDeletionException(
        'The server did not confirm deletion. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> testAuthentication() async {
    final session = _supabase.auth.currentSession;

    if (session == null) {
      throw StateError('No active Supabase session.');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/auth-test'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Accept': 'application/json',
      },
    );

    final body = jsonDecode(response.body);

    if (body is! Map<String, dynamic>) {
      throw StateError('Invalid response from media server.');
    }

    if (response.statusCode != 200) {
      throw StateError(body['error']?.toString() ?? 'Authentication failed.');
    }

    return body;
  }
}
