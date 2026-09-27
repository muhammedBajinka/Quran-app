import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressState extends ChangeNotifier {
  static const _pointsKey = 'progress_points';
  static const _currentStreakKey = 'progress_current_streak';
  static const _longestStreakKey = 'progress_longest_streak';
  static const _lastActiveDateKey = 'progress_last_active_date';
  static const _totalOpenDaysKey = 'progress_total_open_days';

  int _points = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalOpenDays = 0;
  String? _lastActiveDate;

  int get points => _points;
  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  int get totalOpenDays => _totalOpenDays;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    _points = prefs.getInt(_pointsKey) ?? 0;
    _currentStreak = prefs.getInt(_currentStreakKey) ?? 0;
    _longestStreak = prefs.getInt(_longestStreakKey) ?? 0;
    _totalOpenDays = prefs.getInt(_totalOpenDaysKey) ?? 0;
    _lastActiveDate = prefs.getString(_lastActiveDateKey);

    notifyListeners();
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String _yesterday() {
    final date = DateTime.now().subtract(const Duration(days: 1));
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(_pointsKey, _points);
    await prefs.setInt(_currentStreakKey, _currentStreak);
    await prefs.setInt(_longestStreakKey, _longestStreak);
    await prefs.setInt(_totalOpenDaysKey, _totalOpenDays);

    if (_lastActiveDate != null) {
      await prefs.setString(_lastActiveDateKey, _lastActiveDate!);
    }
  }

  /// Keeps the user's streak alive and awards the daily app-open point.
  /// Multiple opens on the same day do not give extra points.
  Future<void> registerAppOpen() async {
    final today = _today();

    if (_lastActiveDate == today) {
      return;
    }

    if (_lastActiveDate == _yesterday()) {
      _currentStreak++;
    } else {
      _currentStreak = 1;
    }

    if (_currentStreak > _longestStreak) {
      _longestStreak = _currentStreak;
    }

    _points += 1;
    _totalOpenDays++;
    _lastActiveDate = today;

    notifyListeners();
    await _save();
  }

  /// Records activity and keeps the streak alive.
  Future<void> recordActivity(int earnedPoints) async {
    final today = _today();

    if (_lastActiveDate != today) {
      if (_lastActiveDate == _yesterday()) {
        _currentStreak++;
      } else {
        _currentStreak = 1;
      }

      if (_currentStreak > _longestStreak) {
        _longestStreak = _currentStreak;
      }

      _lastActiveDate = today;
      _totalOpenDays++;
    }

    _points += earnedPoints;

    notifyListeners();
    await _save();
  }

  Future<void> recordMemorizationSession() async {
    await recordActivity(5);
  }

  Future<void> recordMemorizationCompletion(int newAyahCount) async {
    await recordActivity(5 + newAyahCount);
  }

  Future<void> recordRevisionSession() async {
    await recordActivity(3);
  }

  Future<void> recordRecording() async {
    await recordActivity(2);
  }

  Future<void> recordAyahMemorized() async {
    await recordActivity(1);
  }
}
