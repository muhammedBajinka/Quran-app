import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Streams progress and owns its request so cancellation closes the connection.
class MediaDownload {
  final http.Client client;
  bool _cancelled = false;

  MediaDownload({http.Client? client}) : client = client ?? http.Client();

  void cancel() {
    _cancelled = true;
    client.close();
  }

  Future<Uint8List> fetch(Uri uri, void Function(int, int?) onProgress,
      {Map<String, String> headers = const {}}) async {
    try {
      final request = http.Request('GET', uri)..headers.addAll(headers);
      final response = await client.send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw StateError('Media HTTP ${response.statusCode}: download failed.');
      }
      final total = response.contentLength;
      final bytes = BytesBuilder(copy: false);
      onProgress(0, total);
      await for (final chunk in response.stream.timeout(const Duration(seconds: 30))) {
        if (_cancelled) throw StateError('Download cancelled.');
        bytes.add(chunk);
        onProgress(bytes.length, total);
      }
      if (_cancelled) throw StateError('Download cancelled.');
      if (bytes.length == 0 || (total != null && bytes.length != total)) {
        throw StateError('The download was incomplete. Please try again.');
      }
      return bytes.takeBytes();
    } finally {
      client.close();
    }
  }
}
