class QuranReciter {
  final String id;
  final String name;
  final String sourceType;

  const QuranReciter({
    required this.id,
    required this.name,
    required this.sourceType,
  });

  bool get isCustom => sourceType == 'custom';
  bool get isGlobal => sourceType == 'global';
}

class QuranAyahTimestamp {
  final int ayahNumber;
  final int startMs;
  final int? endMs;

  const QuranAyahTimestamp({
    required this.ayahNumber,
    required this.startMs,
    this.endMs,
  });
}
