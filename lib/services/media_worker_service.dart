import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class MediaWorkerService {
  static const String _baseUrl =
      'https://quran-media-worker.muhammedbajinka02.workers.dev';

  final SupabaseClient _supabase;

  MediaWorkerService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

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
