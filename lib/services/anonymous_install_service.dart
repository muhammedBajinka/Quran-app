import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class AnonymousInstallService {
  static const _storageKey = 'anonymous_install_id';

  Future<String> getInstallId() async {
    final preferences = await SharedPreferences.getInstance();

    final existing = preferences.getString(_storageKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final id = _generateUuidV4();
    await preferences.setString(_storageKey, id);
    return id;
  }

  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int value) => value.toRadixString(16).padLeft(2, '0');

    final value = bytes.map(hex).join();

    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
