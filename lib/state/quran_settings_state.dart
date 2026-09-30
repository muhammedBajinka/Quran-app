import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuranSettingsState extends ChangeNotifier {
  static const String _arabicTextSizeKey = 'quran_arabic_text_size';
  static const String _enabledReciterIdsKey = 'quran_enabled_reciter_ids';
  static const String _defaultReciterIdKey = 'quran_default_reciter_id';

  static const double minArabicTextSize = 20.0;
  static const double maxArabicTextSize = 34.0;
  static const double defaultArabicTextSize = 25.0;

  double _arabicTextSize = defaultArabicTextSize;
  Set<String> _enabledReciterIds = {};
  String? _defaultReciterId;

  double get arabicTextSize => _arabicTextSize;
  Set<String> get enabledReciterIds => Set.unmodifiable(_enabledReciterIds);
  String? get defaultReciterId => _defaultReciterId;

  bool isReciterEnabled(String reciterId) {
    return _enabledReciterIds.contains(reciterId);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSize = prefs.getDouble(_arabicTextSizeKey);
    final savedEnabledReciters =
        prefs.getStringList(_enabledReciterIdsKey) ?? const <String>[];
    final savedDefaultReciter = prefs.getString(_defaultReciterIdKey);

    if (savedSize != null) {
      _arabicTextSize = savedSize.clamp(minArabicTextSize, maxArabicTextSize);
    }

    _enabledReciterIds = savedEnabledReciters.toSet();
    _defaultReciterId = savedDefaultReciter;

    notifyListeners();
  }

  Future<void> setArabicTextSize(double size) async {
    final newSize = size.clamp(minArabicTextSize, maxArabicTextSize);

    if (_arabicTextSize == newSize) {
      return;
    }

    _arabicTextSize = newSize;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_arabicTextSizeKey, newSize);
  }

  Future<void> resetArabicTextSize() async {
    await setArabicTextSize(defaultArabicTextSize);
  }

  Future<void> setReciterEnabled(String reciterId, bool enabled) async {
    if (enabled) {
      _enabledReciterIds.add(reciterId);
    } else {
      _enabledReciterIds.remove(reciterId);

      if (_defaultReciterId == reciterId) {
        _defaultReciterId = null;
      }
    }

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _enabledReciterIdsKey,
      _enabledReciterIds.toList(),
    );

    if (_defaultReciterId == null) {
      await prefs.remove(_defaultReciterIdKey);
    }
  }

  Future<void> setDefaultReciter(String reciterId) async {
    if (!_enabledReciterIds.contains(reciterId)) {
      _enabledReciterIds.add(reciterId);
    }

    _defaultReciterId = reciterId;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      _enabledReciterIdsKey,
      _enabledReciterIds.toList(),
    );

    await prefs.setString(_defaultReciterIdKey, reciterId);
  }
}
