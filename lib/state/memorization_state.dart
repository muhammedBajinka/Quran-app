import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AyahStrength { strong, needsReview, bad }

enum MemorizationSessionType { memorization, revision }

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'surahNumber': surahNumber,
    'ayahNumbers': ayahNumbers,
    'strength': strength.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory MemorizationPortion.fromJson(Map<String, dynamic> json) {
    return MemorizationPortion(
      id: json['id'] as String,
      surahNumber: json['surahNumber'] as int,
      ayahNumbers: List<int>.from(json['ayahNumbers'] as List),
      strength: AyahStrength.values.firstWhere(
        (value) => value.name == json['strength'],
        orElse: () => AyahStrength.needsReview,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'surahNumber': surahNumber,
    'ayahNumbers': ayahNumbers,
    'filePath': filePath,
    'createdAt': createdAt.toIso8601String(),
    'durationSeconds': durationSeconds,
  };

  factory MemorizationRecording.fromJson(Map<String, dynamic> json) {
    return MemorizationRecording(
      id: json['id'] as String,
      surahNumber: json['surahNumber'] as int,
      ayahNumbers: List<int>.from(json['ayahNumbers'] as List),
      filePath: json['filePath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      durationSeconds: json['durationSeconds'] as int,
    );
  }
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'surahNumber': surahNumber,
    'ayahNumbers': ayahNumbers,
    'mistakeAyahs': mistakeAyahs,
    'type': type.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MemorizationSession.fromJson(Map<String, dynamic> json) {
    return MemorizationSession(
      id: json['id'] as String,
      surahNumber: json['surahNumber'] as int,
      ayahNumbers: List<int>.from(json['ayahNumbers'] as List),
      mistakeAyahs: List<int>.from(json['mistakeAyahs'] as List? ?? []),
      type: MemorizationSessionType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => MemorizationSessionType.memorization,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class RevisionSession {
  final String id;
  final int surahNumber;
  final List<int> ayahNumbers;
  final List<int> mistakeAyahs;
  final DateTime createdAt;

  const RevisionSession({
    required this.id,
    required this.surahNumber,
    required this.ayahNumbers,
    this.mistakeAyahs = const [],
    required this.createdAt,
  });

  int get mistakeCount => mistakeAyahs.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'surahNumber': surahNumber,
    'ayahNumbers': ayahNumbers,
    'mistakeAyahs': mistakeAyahs,
    'createdAt': createdAt.toIso8601String(),
  };

  factory RevisionSession.fromJson(Map<String, dynamic> json) {
    return RevisionSession(
      id: json['id'] as String,
      surahNumber: json['surahNumber'] as int,
      ayahNumbers: List<int>.from(json['ayahNumbers'] as List),
      mistakeAyahs: List<int>.from(json['mistakeAyahs'] as List? ?? []),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class MemorizationState extends ChangeNotifier {
  static const String _storageKey = 'quran_memorization_state_v2';
  static const String _learningSecondsKey = 'learningSeconds';

  final Map<int, Set<int>> _memorizedAyahs = {};
  final List<MemorizationPortion> _memorizationPortions = [];
  final List<MemorizationRecording> _recordings = [];
  final List<RevisionSession> _revisionSessions = [];
  final List<MemorizationSession> _memorizationSessions = [];

  int _learningSeconds = 0;
  DateTime? _learningStartedAt;

  int get learningSeconds {
    if (_learningStartedAt == null) {
      return _learningSeconds;
    }

    return _learningSeconds +
        DateTime.now().difference(_learningStartedAt!).inSeconds;
  }

  bool get isLearningTimerRunning => _learningStartedAt != null;

  MemorizationState() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);

      if (raw == null || raw.isEmpty) {
        return;
      }

      final data = jsonDecode(raw) as Map<String, dynamic>;

      _learningSeconds = data[_learningSecondsKey] as int? ?? 0;

      final memorized = data['memorizedAyahs'] as Map<String, dynamic>?;

      if (memorized != null) {
        for (final entry in memorized.entries) {
          _memorizedAyahs[int.parse(entry.key)] = Set<int>.from(
            entry.value as List,
          );
        }
      }

      final portions = data['portions'] as List? ?? [];
      _memorizationPortions.addAll(
        portions.map(
          (item) => MemorizationPortion.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      );

      final recordings = data['recordings'] as List? ?? [];
      _recordings.addAll(
        recordings.map(
          (item) => MemorizationRecording.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      );

      final revisions = data['revisionSessions'] as List? ?? [];
      _revisionSessions.addAll(
        revisions.map(
          (item) =>
              RevisionSession.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );

      final sessions = data['memorizationSessions'] as List? ?? [];
      _memorizationSessions.addAll(
        sessions.map(
          (item) => MemorizationSession.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      );

      notifyListeners();
    } catch (error) {
      debugPrint('Could not load memorization data: $error');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final memorizedAyahs = <String, List<int>>{};

      for (final entry in _memorizedAyahs.entries) {
        memorizedAyahs[entry.key.toString()] = entry.value.toList()..sort();
      }

      final data = {
        _learningSecondsKey: _learningSeconds,
        'memorizedAyahs': memorizedAyahs,
        'portions': _memorizationPortions
            .map((portion) => portion.toJson())
            .toList(),
        'recordings': _recordings
            .map((recording) => recording.toJson())
            .toList(),
        'revisionSessions': _revisionSessions
            .map((session) => session.toJson())
            .toList(),
        'memorizationSessions': _memorizationSessions
            .map((session) => session.toJson())
            .toList(),
      };

      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (error) {
      debugPrint('Could not save memorization data: $error');
    }
  }

  void startLearningTimer() {
    if (_learningStartedAt != null) {
      return;
    }

    _learningStartedAt = DateTime.now();
    notifyListeners();
  }

  Future<void> stopLearningTimer() async {
    final startedAt = _learningStartedAt;

    if (startedAt == null) {
      return;
    }

    _learningSeconds += DateTime.now().difference(startedAt).inSeconds;

    _learningStartedAt = null;

    await _persist();
    notifyListeners();
  }

  Future<void> saveActiveLearningTime() async {
    final startedAt = _learningStartedAt;

    if (startedAt == null) {
      return;
    }

    _learningSeconds += DateTime.now().difference(startedAt).inSeconds;

    _learningStartedAt = DateTime.now();

    await _persist();
    notifyListeners();
  }

  Set<int> memorizedAyahsForSurah(int surahNumber) {
    return Set.unmodifiable(_memorizedAyahs[surahNumber] ?? <int>{});
  }

  bool isAyahMemorized(int surahNumber, int ayahNumber) {
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
          (surahNumber) => _memorizedAyahs[surahNumber]?.isNotEmpty ?? false,
        )
        .length;
  }

  bool isMemorized(int surahNumber) {
    return memorizedAyahCountForSurah(surahNumber) > 0;
  }

  void setAyahsMemorized(int surahNumber, Iterable<int> ayahNumbers) {
    final ayahs = _memorizedAyahs.putIfAbsent(surahNumber, () => <int>{});

    ayahs.addAll(ayahNumbers);

    _persist();
    notifyListeners();
  }

  void removeMemorizedAyah(int surahNumber, int ayahNumber) {
    final ayahs = _memorizedAyahs[surahNumber];

    if (ayahs == null) {
      return;
    }

    ayahs.remove(ayahNumber);

    if (ayahs.isEmpty) {
      _memorizedAyahs.remove(surahNumber);
    }

    _persist();
    notifyListeners();
  }

  void clearMemorizedAyahs(int surahNumber) {
    _memorizedAyahs.remove(surahNumber);
    _persist();
    notifyListeners();
  }

  void toggleMemorized(int surahNumber) {
    if (isMemorized(surahNumber)) {
      clearMemorizedAyahs(surahNumber);
      return;
    }

    notifyListeners();
  }

  List<MemorizationPortion> portionsForSurah(int surahNumber) {
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
          setEquals({...portion.ayahNumbers}, requested)) {
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

    final existingIndex = _memorizationPortions.indexWhere(
      (portion) =>
          portion.surahNumber == surahNumber &&
          setEquals({...portion.ayahNumbers}, {...sortedAyahs}),
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

    // Choosing a strength does NOT mark the ayahs as memorized.
    _persist();
    notifyListeners();
  }

  void completeMemorization({
    required MemorizationSession session,
    required AyahStrength strength,
  }) {
    if (session.type != MemorizationSessionType.memorization) {
      return;
    }

    _memorizationSessions.add(session);

    setAyahsMemorized(session.surahNumber, session.ayahNumbers);

    saveMemorizationPortion(
      surahNumber: session.surahNumber,
      ayahNumbers: session.ayahNumbers,
      strength: strength,
    );

    notifyListeners();
  }

  List<MemorizationRecording> recordingsForSurah(int surahNumber) {
    return List.unmodifiable(
      _recordings.where((recording) => recording.surahNumber == surahNumber),
    );
  }

  List<MemorizationRecording> get recordings => List.unmodifiable(_recordings);

  void addRecording(MemorizationRecording recording) {
    _recordings.add(recording);
    _persist();
    notifyListeners();
  }

  void removeRecording(String recordingId) {
    _recordings.removeWhere((recording) => recording.id == recordingId);

    _persist();
    notifyListeners();
  }

  List<RevisionSession> revisionSessionsForSurah(int surahNumber) {
    return List.unmodifiable(
      _revisionSessions.where((session) => session.surahNumber == surahNumber),
    );
  }

  List<RevisionSession> get revisionSessions =>
      List.unmodifiable(_revisionSessions);

  void addRevisionSession(RevisionSession session) {
    _revisionSessions.add(session);
    _persist();
    notifyListeners();
  }

  int get totalRevisionSessions => _revisionSessions.length;

  List<MemorizationSession> sessionsForSurah(int surahNumber) {
    return List.unmodifiable(
      _memorizationSessions.where(
        (session) =>
            session.surahNumber == surahNumber &&
            session.type == MemorizationSessionType.memorization,
      ),
    );
  }

  List<MemorizationSession> get memorizationSessions =>
      List.unmodifiable(_memorizationSessions);

  int memorizationSessionCountForSurah(int surahNumber) {
    return _memorizationSessions
        .where(
          (session) =>
              session.surahNumber == surahNumber &&
              session.type == MemorizationSessionType.memorization,
        )
        .length;
  }

  int revisionSessionCountForSurah(int surahNumber) {
    return _revisionSessions
        .where((session) => session.surahNumber == surahNumber)
        .length;
  }

  void addMemorizationSession(MemorizationSession session) {
    if (session.type == MemorizationSessionType.revision) {
      addRevisionSession(
        RevisionSession(
          id: session.id,
          surahNumber: session.surahNumber,
          ayahNumbers: session.ayahNumbers,
          mistakeAyahs: session.mistakeAyahs,
          createdAt: session.createdAt,
        ),
      );
      return;
    }

    _memorizationSessions.add(session);
    _persist();
    notifyListeners();
  }

  int get totalMemorizationSessions => _memorizationSessions.length;

  int get totalRevisionSessionsLogged => _revisionSessions.length;
}
