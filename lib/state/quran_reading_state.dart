import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SurahReadingStatus { start, inProgress, completed }

class QuranReadingState extends ChangeNotifier {
  static const String _startedKey = 'quran_reading_started_surahs';
  static const String _completionPrefix = 'quran_surah_completion_';

  final Set<int> _startedSurahs = <int>{};
  final Map<int, int> _completionCounts = <int, int>{};

  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final started = prefs.getStringList(_startedKey) ?? const <String>[];

    _startedSurahs
      ..clear()
      ..addAll(started.map(int.tryParse).whereType<int>());

    _completionCounts.clear();

    for (int surahNumber = 1; surahNumber <= 114; surahNumber++) {
      final count = prefs.getInt('$_completionPrefix$surahNumber') ?? 0;

      if (count > 0) {
        _completionCounts[surahNumber] = count;
      }
    }

    _loaded = true;
    notifyListeners();
  }

  SurahReadingStatus statusFor(int surahNumber) {
    if (completionCountFor(surahNumber) > 0) {
      return SurahReadingStatus.completed;
    }

    if (_startedSurahs.contains(surahNumber)) {
      return SurahReadingStatus.inProgress;
    }

    return SurahReadingStatus.start;
  }

  int completionCountFor(int surahNumber) {
    return _completionCounts[surahNumber] ?? 0;
  }

  Future<void> markStarted(int surahNumber) async {
    if (_startedSurahs.contains(surahNumber)) {
      return;
    }

    _startedSurahs.add(surahNumber);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      _startedKey,
      _startedSurahs.map((number) => number.toString()).toList(),
    );
  }

  Future<void> markCompleted(int surahNumber) async {
    final newCount = completionCountFor(surahNumber) + 1;

    _startedSurahs.add(surahNumber);
    _completionCounts[surahNumber] = newCount;

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      _startedKey,
      _startedSurahs.map((number) => number.toString()).toList(),
    );

    await prefs.setInt('$_completionPrefix$surahNumber', newCount);
  }
}
