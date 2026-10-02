import 'dart:convert';
import 'dart:io';

import '../models/audio/quran_reciter.dart';

class GlobalQuranAudio {
  static const Map<String, String> _servers = {
    'muhammad_al_faqih':
        'https://server16.mp3quran.net/M_Alfaqih/Rewayat-Hafs-A-n-Assem/',
    'uqasha_kameeni':
        'https://server16.mp3quran.net/okasha/Rewayat-Albizi-A-n-Ibn-Katheer/',
    'saad_alghamdi': 'https://server7.mp3quran.net/s_gmd/',
    'yasser_aldosari': 'https://server11.mp3quran.net/yasser/',
    'abdullah_ali_jaber': 'https://server11.mp3quran.net/a_jbr/',
    'sudais': 'https://server11.mp3quran.net/sds/',
    'muhammad_ayyub': 'https://server8.mp3quran.net/ayyub/',
    'minshawi': 'https://server10.mp3quran.net/minsh/',
    'husary': 'https://server13.mp3quran.net/husr/',
    'noreen_muhammad_siddiq': 'https://server16.mp3quran.net/nourin_siddig/Rewayat-Aldori-A-n-Abi-Amr/',
    'mansour_alsalimi': 'https://server14.mp3quran.net/mansor/',
    'adel_alkalbani': 'https://server8.mp3quran.net/a_klb/',
    'saud_alshuraim': 'https://server7.mp3quran.net/shur/',
    'mohammed_jibreel': 'https://server8.mp3quran.net/jbrl/',
    'mahmoud_ali_albanna': 'https://server8.mp3quran.net/bna/',
    'sahl_yassin': 'https://server6.mp3quran.net/shl/',
    'abdul_basit': 'https://server7.mp3quran.net/basit/',
    'mustafa_ismail': 'https://server8.mp3quran.net/mustafa/',
    'hasan_saleh':
        'https://server16.mp3quran.net/h_saleh/Rewayat-Hafs-A-n-Assem/',
    'omar_alqazabri': 'https://server9.mp3quran.net/omar_warsh/',
    'salah_bukhatir': 'https://server8.mp3quran.net/bu_khtr/',
    'ahmad_nuaina': 'https://server11.mp3quran.net/ahmad_nu/',
  };

  // MP3Quran read IDs with verified ayah timing data.
  static const Map<String, int> _timingReadIds = {
    'saad_alghamdi': 30,
    'sudais': 54,
    'abdullah_ali_jaber': 76,
    'yasser_aldosari': 92,
    'muhammad_ayyub': 109,
    'minshawi': 112,
    'husary': 118,
    'mansour_alsalimi': 245,
    'saud_alshuraim': 31,
    'sahl_yassin': 32,
    'abdul_basit': 53,
    'hasan_saleh': 299,
    'omar_alqazabri': 80,
    'salah_bukhatir': 46,
    'ahmad_nuaina': 9,
    'uqasha_kameeni': 296,
  };

  static bool supports(QuranReciter reciter) {
    return reciter.isGlobal && _servers.containsKey(reciter.id);
  }

  static bool hasSurah(QuranReciter reciter, int surahNumber) {
    return supports(reciter) && surahNumber >= 1 && surahNumber <= 114;
  }

  static bool hasAyahTiming(QuranReciter reciter) {
    return reciter.isGlobal && _timingReadIds.containsKey(reciter.id);
  }

  static String? audioUrl(QuranReciter reciter, int surahNumber) {
    final server = _servers[reciter.id];

    if (server == null || surahNumber < 1 || surahNumber > 114) {
      return null;
    }

    final fileName = surahNumber.toString().padLeft(3, '0');
    return '$server$fileName.mp3';
  }

  static Future<List<QuranAyahTimestamp>> getAyahTimestamps(
    QuranReciter reciter,
    int surahNumber,
  ) async {
    final readId = _timingReadIds[reciter.id];

    if (readId == null || surahNumber < 1 || surahNumber > 114) {
      return const [];
    }

    final uri = Uri.https('mp3quran.net', '/api/v3/ayat_timing', {
      'surah': surahNumber.toString(),
      'read': readId.toString(),
    });

    final client = HttpClient();

    try {
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        return const [];
      }

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);

      if (decoded is! List) {
        return const [];
      }

      final timestamps = <QuranAyahTimestamp>[];

      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final ayah = item['ayah'];
        final start = item['start_time'];
        final end = item['end_time'];

        if (ayah is! num || start is! num) {
          continue;
        }

        timestamps.add(
          QuranAyahTimestamp(
            ayahNumber: ayah.toInt(),
            startMs: start.toInt(),
            endMs: end is num ? end.toInt() : null,
          ),
        );
      }

      timestamps.sort((a, b) => a.ayahNumber.compareTo(b.ayahNumber));
      return timestamps;
    } catch (_) {
      return const [];
    } finally {
      client.close(force: true);
    }
  }
}
