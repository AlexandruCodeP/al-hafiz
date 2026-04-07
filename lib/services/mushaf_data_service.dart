import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A single word (or verse-end marker) on a Mushaf page.
class MushafWord {
  final int id;
  final String text;
  final int lineNumber;
  final int position; // position within the verse (1-based)
  final int verseNumber;
  final int surahNumber;
  final bool isEnd; // true for verse-number markers

  const MushafWord({
    required this.id,
    required this.text,
    required this.lineNumber,
    required this.position,
    required this.verseNumber,
    required this.surahNumber,
    required this.isEnd,
  });

  /// 0-based word index (for matching with timing data).
  /// Only meaningful when isEnd == false.
  int get wordIndex => position - 1;
}

/// Layout data for a single Mushaf page, grouped by line.
class MushafPageData {
  final int pageNumber;
  final Map<int, List<MushafWord>> lines; // lineNumber → words

  const MushafPageData({
    required this.pageNumber,
    required this.lines,
  });

  /// All distinct surah numbers present on this page.
  Set<int> get surahIds {
    final ids = <int>{};
    for (final words in lines.values) {
      for (final w in words) {
        ids.add(w.surahNumber);
      }
    }
    return ids;
  }

  /// First line number that has content (for header detection).
  int get firstContentLine {
    final keys = lines.keys.toList()..sort();
    return keys.isEmpty ? 1 : keys.first;
  }
}

/// Fetches and caches Mushaf page layout data from the Quran.com v4 API.
class MushafDataService {
  static final MushafDataService instance = MushafDataService._();
  MushafDataService._();

  final Map<int, MushafPageData> _cache = {};

  /// Fetch word layout for [pageNumber] (1-604).
  Future<MushafPageData?> getPage(int pageNumber) async {
    if (_cache.containsKey(pageNumber)) return _cache[pageNumber];

    try {
      final uri = Uri.parse(
        'https://api.quran.com/api/v4/verses/by_page/$pageNumber'
        '?words=true'
        '&word_fields=text_uthmani,line_number'
        '&per_page=50',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final verses = json['verses'] as List? ?? [];

      final lines = <int, List<MushafWord>>{};

      for (final verse in verses) {
        final vk = verse['verse_key'] as String;
        final parts = vk.split(':');
        final surahNum = int.parse(parts[0]);
        final verseNum = int.parse(parts[1]);

        final words = verse['words'] as List? ?? [];
        for (final word in words) {
          // Only include words belonging to this page
          final wpn = word['page_number'] as int?;
          if (wpn != null && wpn != pageNumber) continue;

          final lineNum = word['line_number'] as int? ?? 1;
          final pos = word['position'] as int? ?? 1;
          final charType = word['char_type_name'] as String? ?? 'word';
          final text =
              word['text_uthmani'] as String? ?? word['text'] as String? ?? '';

          lines.putIfAbsent(lineNum, () => []).add(MushafWord(
            id: word['id'] as int? ?? 0,
            text: text,
            lineNumber: lineNum,
            position: pos,
            verseNumber: verseNum,
            surahNumber: surahNum,
            isEnd: charType == 'end',
          ));
        }
      }

      // Sort words within each line by position (RTL: high position = right)
      for (final line in lines.values) {
        line.sort((a, b) => a.position.compareTo(b.position));
      }

      final data = MushafPageData(pageNumber: pageNumber, lines: lines);
      _cache[pageNumber] = data;
      return data;
    } catch (e) {
      debugPrint('MushafDataService: error loading page $pageNumber: $e');
      return null;
    }
  }

  /// Pre-fetch several pages in the background.
  void prefetch(List<int> pageNumbers) {
    for (final p in pageNumbers) {
      if (!_cache.containsKey(p)) {
        getPage(p); // fire and forget
      }
    }
  }
}
