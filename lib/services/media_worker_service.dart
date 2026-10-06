import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

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
  }) async {
    final session = _supabase.auth.currentSession;

    if (session == null) {
      throw StateError('No active Supabase session.');
    }

    final user = session.user;

    if (user.isAnonymous) {
      throw StateError('A Google or other real account is required to upload.');
    }

    final request = http.Request('POST', Uri.parse('$_baseUrl/upload'));

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

    request.bodyBytes = bytes;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw StateError('Invalid response from media server.');
    }

    if (response.statusCode != 201) {
      throw StateError(decoded['error']?.toString() ?? 'Media upload failed.');
    }

    return decoded;
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
