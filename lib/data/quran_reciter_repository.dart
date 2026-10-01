import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audio/quran_reciter.dart';

class QuranReciterRepository {
  final SupabaseClient _supabase;

  QuranReciterRepository({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  Future<List<QuranReciter>> getPublishedReciters() async {
    final rows = await _supabase
        .from('quran_reciters')
        .select('id, name, source_type')
        .eq('published', true)
        .order('name');

    return rows.map<QuranReciter>((row) {
      return QuranReciter(
        id: row['id'] as String,
        name: row['name'] as String,
        sourceType: row['source_type'] as String? ?? 'custom',
      );
    }).toList();
  }

  Future<Set<String>> getAvailableReciterIdsForSurah(int surahNumber) async {
    final rows = await _supabase
        .from('quran_reciter_surahs')
        .select('reciter_id')
        .eq('surah_number', surahNumber);

    return rows.map<String>((row) => row['reciter_id'] as String).toSet();
  }

  Future<String?> getSurahAudioUrl({
    required String reciterId,
    required int surahNumber,
  }) async {
    final row = await _supabase
        .from('quran_reciter_surahs')
        .select('audio_url')
        .eq('reciter_id', reciterId)
        .eq('surah_number', surahNumber)
        .maybeSingle();

    return row?['audio_url'] as String?;
  }

  Future<List<QuranAyahTimestamp>> getAyahTimestamps({
    required String reciterId,
    required int surahNumber,
  }) async {
    final rows = await _supabase
        .from('quran_reciter_ayah_timestamps')
        .select('ayah_number, start_ms, end_ms')
        .eq('reciter_id', reciterId)
        .eq('surah_number', surahNumber)
        .order('ayah_number');

    return rows.map<QuranAyahTimestamp>((row) {
      return QuranAyahTimestamp(
        ayahNumber: row['ayah_number'] as int,
        startMs: row['start_ms'] as int,
        endMs: row['end_ms'] as int?,
      );
    }).toList();
  }
}
