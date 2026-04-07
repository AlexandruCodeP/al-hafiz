import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Timing data for a single word within a verse.
class WordTiming {
  /// 0-based word index within the verse.
  final int wordIndex;

  /// Start time in milliseconds, relative to the verse start.
  final int startMs;

  /// End time in milliseconds, relative to the verse start.
  final int endMs;

  const WordTiming({
    required this.wordIndex,
    required this.startMs,
    required this.endMs,
  });
}

/// Timing data for all words of a single verse.
class VerseTimings {
  final String verseKey;

  /// Duration of this verse in the API's audio file (ms).
  final int verseDurationMs;

  /// Per-word timings, relative to verse start.
  final List<WordTiming> words;

  const VerseTimings({
    required this.verseKey,
    required this.verseDurationMs,
    required this.words,
  });
}

/// Fetches and caches word-level timing data from the Quran.com CDN API.
///
/// Timestamps are for full-surah audio files. We convert them to
/// per-verse-relative values and scale to match our per-ayah audio duration.
class WordTimingService {
  static final WordTimingService instance = WordTimingService._();
  WordTimingService._();

  /// Cache: "{surahId}_{reciterId}" → { ayahId: VerseTimings }
  final Map<String, Map<int, VerseTimings>> _cache = {};

  /// Maps our internal reciter IDs to Quran.com /qdc/audio/reciters IDs.
  static const Map<String, int> _reciterMapping = {
    'alafasy': 6,
    'abdulbasit_murattal': 1,
    'abdulbasit_mujawwad': 1,
    'sudais': 2,
    'shatri': 3,
    'hani_rifai': 4,
    'husary': 5,
    'husary_mujawwad': 5,
    'husary_muallim': 5,
    'minshawy_mujawwad': 7,
    'minshawy_murattal': 7,
    'shuraym': 8,
    'khalefa_tunaiji': 11,
    'yasser_dussary': 20,
    'maher_muaiqly': 5, // fallback – Husary timings as rough guide
  };

  /// Whether we have a Quran.com mapping for this reciter.
  bool hasMapping(String reciterId) => _reciterMapping.containsKey(reciterId);

  /// Fetch word timings for every verse of [surahId].
  /// Returns null if the reciter has no mapping or the request fails.
  Future<Map<int, VerseTimings>?> fetchTimings(
    int surahId,
    String reciterId,
  ) async {
    final cacheKey = '${surahId}_$reciterId';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    final quranComId = _reciterMapping[reciterId];
    if (quranComId == null) return null;

    try {
      final uri = Uri.parse(
        'https://api.qurancdn.com/api/qdc/audio/reciters/'
        '$quranComId/audio_files?chapter=$surahId&segments=true',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final audioFiles = json['audio_files'] as List?;
      if (audioFiles == null || audioFiles.isEmpty) return null;

      final verseTimingsList = audioFiles[0]['verse_timings'] as List?;
      if (verseTimingsList == null) return null;

      final result = <int, VerseTimings>{};

      for (final vt in verseTimingsList) {
        final verseKey = vt['verse_key'] as String;
        final ayahId = int.parse(verseKey.split(':')[1]);
        final tsFrom = (vt['timestamp_from'] as num).toInt();
        final tsTo = (vt['timestamp_to'] as num).toInt();
        final verseDuration = tsTo - tsFrom;
        final segments = vt['segments'] as List? ?? [];

        final words = <WordTiming>[];
        for (final seg in segments) {
          if (seg is! List || seg.length < 3) continue;
          final wordPos = (seg[0] as num).toInt(); // 1-indexed
          final startAbs = (seg[1] as num).toInt();
          final endAbs = (seg[2] as num).toInt();
          words.add(WordTiming(
            wordIndex: wordPos - 1, // convert to 0-indexed
            startMs: startAbs - tsFrom, // relative to verse start
            endMs: endAbs - tsFrom,
          ));
        }

        result[ayahId] = VerseTimings(
          verseKey: verseKey,
          verseDurationMs: verseDuration,
          words: words,
        );
      }

      _cache[cacheKey] = result;
      return result;
    } catch (e) {
      debugPrint('WordTimingService: error fetching timings: $e');
      return null;
    }
  }

  /// Determine which word (0-based index) is being recited at [position]
  /// within a verse whose API timing is [timings].
  ///
  /// [actualDuration] is the real duration of our per-ayah audio file,
  /// used to scale the API timestamps proportionally.
  static int? getCurrentWordIndex(
    VerseTimings timings,
    Duration position,
    Duration actualDuration,
  ) {
    if (timings.words.isEmpty) return null;
    if (actualDuration.inMilliseconds <= 0 || timings.verseDurationMs <= 0) {
      return null;
    }

    final scale = actualDuration.inMilliseconds / timings.verseDurationMs;
    final posMs = position.inMilliseconds;

    for (final word in timings.words) {
      final scaledStart = (word.startMs * scale).round();
      final scaledEnd = (word.endMs * scale).round();
      if (posMs >= scaledStart && posMs < scaledEnd) {
        return word.wordIndex;
      }
    }

    // If past all words, return the last one
    if (posMs > 0 && timings.words.isNotEmpty) {
      final lastEnd = (timings.words.last.endMs * scale).round();
      if (posMs >= lastEnd) return timings.words.last.wordIndex;
    }

    return null;
  }
}
