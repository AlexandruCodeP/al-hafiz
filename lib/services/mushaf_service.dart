import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/mushaf.dart';

/// Fetches and caches mushaf page data from the Quran.com v4 API.
///
/// Transforms the API response (organized by verse) into our page > line > token
/// structure matching the physical mushaf layout.
class MushafService {
  static final MushafService instance = MushafService._();
  MushafService._();

  final Map<int, MushafPage> _cache = {};

  /// Returns a [MushafPage] for the given [pageNumber] (1–604).
  ///
  /// Returns null if the fetch fails.
  Future<MushafPage?> getPage(int pageNumber) async {
    if (_cache.containsKey(pageNumber)) return _cache[pageNumber];

    try {
      final uri = Uri.parse(
        'https://api.quran.com/api/v4/verses/by_page/$pageNumber'
        '?words=true'
        '&word_fields=code_v2,v2_page,line_number,text_uthmani'
        '&per_page=50',
      );

      final response =
          await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final page = _parse(pageNumber, json);

      _cache[pageNumber] = page;
      return page;
    } catch (e) {
      debugPrint('MushafService: error loading page $pageNumber: $e');
      return null;
    }
  }

  /// Pre-fetch pages in the background.
  void prefetch(List<int> pages) {
    for (final p in pages) {
      if (!_cache.containsKey(p)) getPage(p);
    }
  }

  /// Parses the Quran.com API response into a [MushafPage].
  MushafPage _parse(int pageNumber, Map<String, dynamic> json) {
    final verses = json['verses'] as List? ?? [];

    // Collect juz number from the first verse.
    int juzNumber = 1;

    // Group tokens by line number.
    final lineMap = <int, List<MushafToken>>{};

    for (final verse in verses) {
      final vk = verse['verse_key'] as String; // "2:6"
      final parts = vk.split(':');
      final surahNum = int.parse(parts[0]);
      final ayahNum = int.parse(parts[1]);
      juzNumber = verse['juz_number'] as int? ?? juzNumber;

      final words = verse['words'] as List? ?? [];
      for (final word in words) {
        // Skip words that belong to a different page.
        final wordPage = word['page_number'] as int?;
        if (wordPage != null && wordPage != pageNumber) continue;

        final lineNum = word['line_number'] as int? ?? 1;
        final position = word['position'] as int? ?? 1;
        final charType = word['char_type_name'] as String? ?? 'word';
        final textUthmani =
            word['text_uthmani'] as String? ?? word['text'] as String? ?? '';
        final codeV2 = word['code_v2'] as String? ?? '';

        lineMap.putIfAbsent(lineNum, () => []).add(MushafToken(
          surah: surahNum,
          ayah: ayahNum,
          wordIndex: position,
          text: textUthmani,
          codeV2: codeV2,
          type: charType == 'end' ? TokenType.end : TokenType.word,
        ));
      }
    }

    // Sort tokens within each line by position.
    for (final tokens in lineMap.values) {
      tokens.sort((a, b) => a.wordIndex.compareTo(b.wordIndex));
    }

    // Build ordered list of MushafLines.
    final sortedLineNums = lineMap.keys.toList()..sort();
    final lines = sortedLineNums
        .map((ln) => MushafLine(lineNumber: ln, tokens: lineMap[ln]!))
        .toList();

    return MushafPage(
      pageNumber: pageNumber,
      juzNumber: juzNumber,
      lines: lines,
    );
  }
}
