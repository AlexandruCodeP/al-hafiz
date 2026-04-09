import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads, caches, and registers QCF v2 (Quran Complex Fonts) on demand.
///
/// Each Mushaf page (1-604) has its own TTF file where Unicode codepoints
/// starting at U+FC41 map to calligraphic glyphs for each word on that page.
class QcfFontService {
  static final QcfFontService instance = QcfFontService._();
  QcfFontService._();

  static const _baseUrl =
      'https://static.qurancdn.com/fonts/quran/hafs/v2/ttf';

  final Set<int> _loadedPages = {};
  final Map<int, Future<bool>> _pendingLoads = {};

  /// Returns the font family name for a given page number.
  String fontFamily(int page) => 'QCF2_P$page';

  /// Whether the font for [page] is ready to use.
  bool isLoaded(int page) => _loadedPages.contains(page);

  /// Loads the QCF font for [page] (1-604).
  ///
  /// Returns true if the font was loaded successfully.
  /// Uses disk cache to avoid re-downloading.
  Future<bool> loadFont(int page) {
    if (_loadedPages.contains(page)) return Future.value(true);

    // Deduplicate concurrent loads for the same page
    return _pendingLoads.putIfAbsent(page, () => _doLoadFont(page));
  }

  Future<bool> _doLoadFont(int page) async {
    try {
      final dir = await getApplicationCacheDirectory();
      final cacheDir = Directory('${dir.path}/qcf_v2');
      if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);

      final file = File('${cacheDir.path}/p$page.ttf');
      Uint8List bytes;

      if (file.existsSync()) {
        bytes = await file.readAsBytes();
      } else {
        final url = '$_baseUrl/p$page.ttf';
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          debugPrint('QcfFontService: HTTP ${response.statusCode} for page $page');
          return false;
        }
        bytes = response.bodyBytes;
        // Write to cache in background
        file.writeAsBytes(bytes).catchError((_) => file);
      }

      final fontLoader = FontLoader(fontFamily(page));
      fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await fontLoader.load();

      _loadedPages.add(page);
      return true;
    } catch (e) {
      debugPrint('QcfFontService: error loading font for page $page: $e');
      return false;
    } finally {
      _pendingLoads.remove(page);
    }
  }

  /// Pre-fetch fonts for upcoming pages (fire-and-forget).
  void prefetch(List<int> pages) {
    for (final p in pages) {
      if (!_loadedPages.contains(p) && !_pendingLoads.containsKey(p)) {
        loadFont(p);
      }
    }
  }
}
