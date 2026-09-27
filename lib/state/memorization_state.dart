import 'package:flutter/foundation.dart';

enum AyahStrength {
  strong,
  needsReview,
  bad,
}

enum MemorizationSessionType {
  memorization,
  revision,
}

class MemorizationPortion {
  final String id;
  final int surahNumber;
  final List<int> ayahNumbers;
  final AyahStrength strength;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemorizationPortion({
    required this.id,
    required this.surahNumber,
    required this.ayahNumbers,
    required this.strength,
    required this.createdAt,
    required this.updatedAt,
  });
}

class MemorizationRecording {
  final String id;
  final int surahNumber;
  final List<int> ayahNumbers;
  final String filePath;
  final DateTime createdAt;
  final int durationSeconds;

  const MemorizationRecording({
    required this.id,
    required this.surahNumber,
    required this.ayahNumbers,
    required this.filePath,
    required this.createdAt,
    required this.durationSeconds,
  });
}

class MemorizationSession {
  final String id;
  final int surahNumber;
  final List<int> ayahNumbers;
  final List<int> mistakeAyahs;
  final MemorizationSessionType type;
  final DateTime createdAt;

  const MemorizationSession({
    required this.id,
    required this.surahNumber,
    required this.ayahNumbers,
    required this.mistakeAyahs,
    required this.type,
    required this.createdAt,
  });

  int get mistakeCount => mistakeAyahs.length;
}

class RevisionSession {
  final String id;
  final int surahNumber;
  final List<int> ayahNumbers;
  final DateTime createdAt;

  const RevisionSession({
    required this.id,
    required this.surahNumber,
    required this.ayahNumbers,
    required this.createdAt,
  });
}

class MemorizationState extends ChangeNotifier {
  final Map<int, Set<int>> _memorizedAyahs = {};

  final List<MemorizationPortion> _memorizationPortions = [];

  final List<MemorizationRecording> _recordings = [];

  final List<RevisionSession> _revisionSessions = [];

  final List<MemorizationSession> _memorizationSessions = [];

  Set<int> memorizedAyahsForSurah(int surahNumber) {
    return Set.unmodifiable(
      _memorizedAyahs[surahNumber] ?? <int>{},
    );
  }

  bool isAyahMemorized(
    int surahNumber,
    int ayahNumber,
  ) {
    return _memorizedAyahs[surahNumber]?.contains(ayahNumber) ?? false;
  }

  int memorizedAyahCountForSurah(int surahNumber) {
    return _memorizedAyahs[surahNumber]?.length ?? 0;
  }

  int get totalMemorizedAyahs {
    var total = 0;

    for (final ayahs in _memorizedAyahs.values) {
      total += ayahs.length;
    }

    return total;
  }

  int get memorizedCount {
    return _memorizedAyahs.keys
        .where(
          (surahNumber) =>
              _memorizedAyahs[surahNumber]?.isNotEmpty ?? false,
        )
        .length;
  }

  bool isMemorized(int surahNumber) {
    return memorizedAyahCountForSurah(surahNumber) > 0;
  }

  void setAyahsMemorized(
    int surahNumber,
    Iterable<int> ayahNumbers,
  ) {
    final ayahs = _memorizedAyahs.putIfAbsent(
      surahNumber,
      () => <int>{},
    );

    ayahs.addAll(ayahNumbers);

    notifyListeners();
  }

  void removeMemorizedAyah(
    int surahNumber,
    int ayahNumber,
  ) {
    final ayahs = _memorizedAyahs[surahNumber];

    if (ayahs == null) {
      return;
    }

    ayahs.remove(ayahNumber);

    if (ayahs.isEmpty) {
      _memorizedAyahs.remove(surahNumber);
    }

    notifyListeners();
  }

  void clearMemorizedAyahs(int surahNumber) {
    _memorizedAyahs.remove(surahNumber);
    notifyListeners();
  }

  void toggleMemorized(int surahNumber) {
    if (isMemorized(surahNumber)) {
      clearMemorizedAyahs(surahNumber);
      return;
    }

    notifyListeners();
  }

  List<MemorizationPortion> portionsForSurah(
    int surahNumber,
  ) {
    return List.unmodifiable(
      _memorizationPortions.where(
        (portion) => portion.surahNumber == surahNumber,
      ),
    );
  }

  MemorizationPortion? portionForSelection(
    int surahNumber,
    Iterable<int> ayahNumbers,
  ) {
    final requested = {...ayahNumbers};

    for (final portion in _memorizationPortions) {
      if (portion.surahNumber == surahNumber &&
          setEquals(
            {...portion.ayahNumbers},
            requested,
          )) {
        return portion;
      }
    }

    return null;
  }

  void saveMemorizationPortion({
    required int surahNumber,
    required Iterable<int> ayahNumbers,
    required AyahStrength strength,
  }) {
    final sortedAyahs = [...ayahNumbers]..sort();
    final now = DateTime.now();

    final existingIndex =
        _memorizationPortions.indexWhere(
      (portion) =>
          portion.surahNumber == surahNumber &&
          setEquals(
            {...portion.ayahNumbers},
            {...sortedAyahs},
          ),
    );

    final portion = MemorizationPortion(
      id: existingIndex == -1
          ? now.microsecondsSinceEpoch.toString()
          : _memorizationPortions[existingIndex].id,
      surahNumber: surahNumber,
      ayahNumbers: List.unmodifiable(sortedAyahs),
      strength: strength,
      createdAt: existingIndex == -1
          ? now
          : _memorizationPortions[existingIndex].createdAt,
      updatedAt: now,
    );

    if (existingIndex == -1) {
      _memorizationPortions.add(portion);
    } else {
      _memorizationPortions[existingIndex] = portion;
    }

    setAyahsMemorized(
      surahNumber,
      sortedAyahs,
    );

    notifyListeners();
  }

  List<MemorizationRecording> recordingsForSurah(
    int surahNumber,
  ) {
    return List.unmodifiable(
      _recordings.where(
        (recording) => recording.surahNumber == surahNumber,
      ),
    );
  }

  List<MemorizationRecording> get recordings =>
      List.unmodifiable(_recordings);

  void addRecording(
    MemorizationRecording recording,
  ) {
    _recordings.add(recording);
    notifyListeners();
  }

  void removeRecording(String recordingId) {
    _recordings.removeWhere(
      (recording) => recording.id == recordingId,
    );

    notifyListeners();
  }

  List<RevisionSession> revisionSessionsForSurah(
    int surahNumber,
  ) {
    return List.unmodifiable(
      _revisionSessions.where(
        (session) => session.surahNumber == surahNumber,
      ),
    );
  }

  List<RevisionSession> get revisionSessions =>
      List.unmodifiable(_revisionSessions);

  void addRevisionSession(
    RevisionSession session,
  ) {
    _revisionSessions.add(session);
    notifyListeners();
  }

  int get totalRevisionSessions =>
      _revisionSessions.length;

  List<MemorizationSession> sessionsForSurah(
    int surahNumber,
  ) {
    return List.unmodifiable(
      _memorizationSessions.where(
        (session) => session.surahNumber == surahNumber,
      ),
    );
  }

  List<MemorizationSession> get memorizationSessions =>
      List.unmodifiable(_memorizationSessions);

  int memorizationSessionCountForSurah(
    int surahNumber,
  ) {
    return _memorizationSessions
        .where(
          (session) =>
              session.surahNumber == surahNumber &&
              session.type ==
                  MemorizationSessionType.memorization,
        )
        .length;
  }

  int revisionSessionCountForSurah(
    int surahNumber,
  ) {
    return _memorizationSessions
        .where(
          (session) =>
              session.surahNumber == surahNumber &&
              session.type ==
                  MemorizationSessionType.revision,
        )
        .length;
  }

  void addMemorizationSession(
    MemorizationSession session,
  ) {
    _memorizationSessions.add(session);

    if (session.type ==
        MemorizationSessionType.revision) {
      _revisionSessions.add(
        RevisionSession(
          id: session.id,
          surahNumber: session.surahNumber,
          ayahNumbers: session.ayahNumbers,
          createdAt: session.createdAt,
        ),
      );
    }

    notifyListeners();
  }

  int get totalMemorizationSessions =>
      _memorizationSessions
          .where(
            (session) =>
                session.type ==
                MemorizationSessionType.memorization,
          )
          .length;

  int get totalRevisionSessionsLogged =>
      _memorizationSessions
          .where(
            (session) =>
                session.type ==
                MemorizationSessionType.revision,
          )
          .length;
}
