import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/mushaf.dart';

/// Fetches and caches mushaf page data from the Quran.com v4 API.
///
/// Transforms the API response (organized by verse) into our
/// page → line → concatenated QCF string structure.
class MushafService {
  static final MushafService instance = MushafService._();
  MushafService._();

  final Map<int, MushafPage> _cache = {};

  /// Returns a [MushafPage] for the given [pageNumber] (1–604).
  Future<MushafPage?> getPage(int pageNumber) async {
    if (_cache.containsKey(pageNumber)) return _cache[pageNumber];

    try {
      final uri = Uri.parse(
        'https://api.quran.com/api/v4/verses/by_page/$pageNumber'
        '?words=true'
        '&word_fields=code_v2,v2_page,line_number'
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
    int juzNumber = 1;

    // Intermediate: collect raw words grouped by line number.
    // Each word keeps its codeV2 + ayah identity.
    final lineWords = <int, List<_RawWord>>{};

    for (final verse in verses) {
      final vk = verse['verse_key'] as String;
      final parts = vk.split(':');
      final surahNum = int.parse(parts[0]);
      final ayahNum = int.parse(parts[1]);
      juzNumber = verse['juz_number'] as int? ?? juzNumber;

      final words = verse['words'] as List? ?? [];
      for (final word in words) {
        final wordPage = word['page_number'] as int?;
        if (wordPage != null && wordPage != pageNumber) continue;

        final lineNum = word['line_number'] as int? ?? 1;
        final position = word['position'] as int? ?? 1;
        final codeV2 = word['code_v2'] as String? ?? '';

        if (codeV2.isEmpty) {
          debugPrint(
              'MushafService: MISSING code_v2 for page $pageNumber '
              'line $lineNum surah $surahNum ayah $ayahNum word $position');
        }

        lineWords.putIfAbsent(lineNum, () => []).add(_RawWord(
          codeV2: codeV2,
          surah: surahNum,
          ayah: ayahNum,
          position: position,
        ));
      }
    }

    // Build MushafLines: sort words, concatenate QCF, collect ayah refs.
    final sortedLineNums = lineWords.keys.toList()..sort();
    final lines = <MushafLine>[];

    for (final ln in sortedLineNums) {
      final words = lineWords[ln]!;
      words.sort((a, b) => a.position.compareTo(b.position));

      // Concatenate all QCF glyphs into a single string.
      final textQcf = words.map((w) => w.codeV2).join();

      // Collect distinct ayahs in order of appearance.
      final ayahs = <AyahRef>[];
      for (final w in words) {
        final ref = AyahRef(surah: w.surah, ayah: w.ayah);
        if (ayahs.isEmpty || ayahs.last != ref) {
          ayahs.add(ref);
        }
      }

      lines.add(MushafLine(
        lineNumber: ln,
        textQcf: textQcf,
        ayahs: ayahs,
      ));
    }

    return MushafPage(
      pageNumber: pageNumber,
      juzNumber: juzNumber,
      lines: lines,
    );
  }
}

/// Internal helper for parsing.
class _RawWord {
  final String codeV2;
  final int surah;
  final int ayah;
  final int position;

  const _RawWord({
    required this.codeV2,
    required this.surah,
    required this.ayah,
    required this.position,
  });
}
