/// Shared posts stay inside the normal Media feed.
class MediaLinks {
  static final _id = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  static String? postId(Uri uri) {
    final value = uri.queryParameters['media'];
    return value != null && _id.hasMatch(value) ? value : null;
  }

  static Uri forPost(String id) => Uri.https(
    'muhammedbajinka.github.io', '/Quran-app/', {'media': id},
  );
}
