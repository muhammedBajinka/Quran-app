import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_app/services/media_links.dart';
import 'package:quran_app/services/media_download.dart';
import 'package:quran_app/data/media_social_repository.dart';

void main() {
  const id = '12345678-1234-1234-1234-123456789abc';
  test('Shared URLs identify the normal app feed, with malformed IDs rejected', () {
    final link = MediaLinks.forPost(id);
    expect(link.path, '/Quran-app/');
    expect(MediaLinks.postId(link), id);
    expect(MediaLinks.postId(Uri.parse('https://example.com/?media=bad')), isNull);
    expect(MediaLinks.postId(Uri.parse('https://example.com/')), isNull);
  });
  test('Missing creator settings enable downloads and comments', () {
    expect(const CreatorPrivacySettings().allowDownloads, isTrue);
    expect(CreatorPrivacySettings.fromMap({}).commentPermission, 'everyone');
    expect(CreatorPrivacySettings.fromMap({}).allowDownloads, isTrue);
  });
  test('Download reports transferred bytes and returns the actual file', () async {
    final updates = <int>[];
    final client = MockClient.streaming((request, body) async => http.StreamedResponse(
      Stream.fromIterable([[1, 2], [3, 4, 5]]), 200, contentLength: 5,
    ));
    final bytes = await MediaDownload(client: client).fetch(Uri.parse('https://example.com/file'),
      (received, total) { updates.add(received); expect(total, 5); });
    expect(bytes, [1, 2, 3, 4, 5]);
    expect(updates, [0, 2, 5]);
  });
  test('Unknown lengths still report byte progress', () async {
    final client = MockClient.streaming((request, body) async => http.StreamedResponse(
      Stream.value([1, 2]), 200,
    ));
    final bytes = await MediaDownload(client: client).fetch(Uri.parse('https://example.com/file'),
      (received, total) => expect(total, isNull));
    expect(bytes.length, 2);
  });
  test('HTTP errors and truncated files are not reported as successful', () async {
    for (final status in [200, 403, 404, 500]) {
      final client = MockClient.streaming((request, body) async => http.StreamedResponse(
        Stream.value([1]), status, contentLength: 2,
      ));
      await expectLater(MediaDownload(client: client).fetch(Uri.parse('https://example.com/file'),
        (_, _) {}), throwsStateError);
    }
  });
  test('Cancelling stops the download before it can report success', () async {
    final controller = StreamController<List<int>>();
    final client = MockClient.streaming((request, body) async => http.StreamedResponse(controller.stream, 200));
    final download = MediaDownload(client: client);
    final result = download.fetch(Uri.parse('https://example.com/file'), (_, _) => download.cancel());
    final assertion = expectLater(result, throwsStateError);
    controller.add([1]);
    await controller.close();
    await assertion;
  });
}
