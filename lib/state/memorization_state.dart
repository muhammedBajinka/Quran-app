import 'package:flutter/foundation.dart';

class MemorizationState extends ChangeNotifier {
  final Set<int> _memorizedSurahNumbers = {};

  int get memorizedCount => _memorizedSurahNumbers.length;

  bool isMemorized(int surahNumber) {
    return _memorizedSurahNumbers.contains(surahNumber);
  }

  void toggleMemorized(int surahNumber) {
    if (_memorizedSurahNumbers.contains(surahNumber)) {
      _memorizedSurahNumbers.remove(surahNumber);
    } else {
      _memorizedSurahNumbers.add(surahNumber);
    }

    notifyListeners();
  }
}
