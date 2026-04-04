import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/surah.dart';

class QuranService {
  static QuranService? _instance;
  List<Surah>? _surahs;
  Map<int, List<int>>? _pageMap; // surahId -> [page for ayah 1, page for ayah 2, ...]

  final Map<int, List<String>> _translationCache = {};
  final Map<int, List<String>> _phoneticCache = {};

  QuranService._();

  static QuranService get instance {
    _instance ??= QuranService._();
    return _instance!;
  }

  Future<Map<int, List<int>>> getPageMap() async {
    if (_pageMap != null) return _pageMap!;
    try {
      final String jsonStr = await rootBundle.loadString('assets/page_map.json');
      final Map<String, dynamic> raw = json.decode(jsonStr) as Map<String, dynamic>;
      _pageMap = raw.map((k, v) => MapEntry(int.parse(k), (v as List).cast<int>()));
      return _pageMap!;
    } catch (e) {
      debugPrint('Error loading page_map.json: $e');
      return {};
    }
  }

  /// Get the page number for a specific ayah
  int? getPageNumber(int surahId, int ayahNumber) {
    if (_pageMap == null) return null;
    final pages = _pageMap![surahId];
    if (pages == null || ayahNumber < 1 || ayahNumber > pages.length) return null;
    return pages[ayahNumber - 1];
  }

  /// Get the range of pages for a surah
  (int, int)? getSurahPageRange(int surahId) {
    if (_pageMap == null) return null;
    final pages = _pageMap![surahId];
    if (pages == null || pages.isEmpty) return null;
    return (pages.first, pages.last);
  }

  /// Get all verses that belong to a specific page (across surahs)
  Future<List<({int surahId, String surahName, Ayah ayah})>> getVersesForPage(int pageNumber) async {
    final surahs = await getAllSurahs();
    final pageMap = await getPageMap();
    final result = <({int surahId, String surahName, Ayah ayah})>[];

    for (final surah in surahs) {
      final pages = pageMap[surah.id];
      if (pages == null) continue;
      for (int i = 0; i < pages.length; i++) {
        if (pages[i] == pageNumber) {
          result.add((surahId: surah.id, surahName: surah.name, ayah: surah.verses[i]));
        }
      }
    }
    return result;
  }

  Future<List<Surah>> getAllSurahs() async {
    if (_surahs != null) return _surahs!;

    try {
      final String jsonStr = await rootBundle.loadString('assets/quran.json');
      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      _surahs = jsonList
          .map((s) => Surah.fromJson(s as Map<String, dynamic>))
          .toList();
      // Pre-load page map
      await getPageMap();
      return _surahs!;
    } catch (e) {
      debugPrint('Error loading quran.json: $e');
      return [];
    }
  }

  Future<Surah> getSurah(int id) async {
    final surahs = await getAllSurahs();
    final surah = surahs.firstWhere((s) => s.id == id);
    
    if (!_translationCache.containsKey(id)) {
      await _fetchExtraData(id);
    }

    return Surah(
      id: surah.id,
      name: surah.name,
      transliteration: surah.transliteration,
      type: surah.type,
      totalVerses: surah.totalVerses,
      verses: surah.verses.map((v) {
        return Ayah(
          id: v.id,
          text: v.text,
          translation: _translationCache[id] != null && _translationCache[id]!.length >= v.id
              ? _translationCache[id]![v.id - 1]
              : null,
          phonetic: _phoneticCache[id] != null && _phoneticCache[id]!.length >= v.id
              ? _phoneticCache[id]![v.id - 1]
              : null,
          pageNumber: getPageNumber(id, v.id),
        );
      }).toList(),
    );
  }

  Future<void> _fetchExtraData(int surahId) async {
    try {
      final transResponse = await http.get(Uri.parse(
          'https://api.quran.com/api/v4/quran/translations/136?chapter_number=$surahId'));
      
      final phoneticResponse = await http.get(Uri.parse(
          'https://api.quran.com/api/v4/quran/translations/57?chapter_number=$surahId'));

      if (transResponse.statusCode == 200) {
        final data = json.decode(transResponse.body);
        _translationCache[surahId] = (data['translations'] as List)
            .map((e) => _cleanHtml(e['text'] as String))
            .toList();
      }

      if (phoneticResponse.statusCode == 200) {
        final data = json.decode(phoneticResponse.body);
        _phoneticCache[surahId] = (data['translations'] as List)
            .map((e) => _cleanHtml(e['text'] as String))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching extra data: $e');
    }
  }

  String _cleanHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  List<Surah> searchSurahs(String query) {
    if (_surahs == null) return [];
    final q = query.toLowerCase();
    return _surahs!.where((s) {
      return s.name.contains(query) ||
          s.transliteration.toLowerCase().contains(q) ||
          s.id.toString() == query;
    }).toList();
  }

  /// Fetch tafsir for a specific ayah (Ibn Kathir in French, ID 816)
  Future<String?> fetchTafsir(int surahId, int ayahId) async {
    try {
      final verseKey = '$surahId:$ayahId';
      final response = await http.get(Uri.parse(
          'https://api.quran.com/api/v4/quran/tafsirs/816?verse_key=$verseKey'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tafsirs = data['tafsirs'] as List;
        if (tafsirs.isNotEmpty) {
          return _cleanHtml(tafsirs.first['text'] as String);
        }
      }
      // Fallback: try Arabic tafsir (Ibn Kathir Arabic, ID 169)
      final fallback = await http.get(Uri.parse(
          'https://api.quran.com/api/v4/quran/tafsirs/169?verse_key=$verseKey'));
      if (fallback.statusCode == 200) {
        final data = json.decode(fallback.body);
        final tafsirs = data['tafsirs'] as List;
        if (tafsirs.isNotEmpty) {
          return _cleanHtml(tafsirs.first['text'] as String);
        }
      }
    } catch (e) {
      debugPrint('Error fetching tafsir: $e');
    }
    return null;
  }

  /// Search within the text of all verses (Arabic)
  List<({int surahId, String surahName, String transliteration, Ayah ayah})> searchVerses(String query) {
    if (_surahs == null || query.trim().isEmpty) return [];
    final q = query.toLowerCase();
    final results = <({int surahId, String surahName, String transliteration, Ayah ayah})>[];

    for (final surah in _surahs!) {
      for (final ayah in surah.verses) {
        if (ayah.text.contains(query) ||
            (ayah.translation != null && ayah.translation!.toLowerCase().contains(q)) ||
            (ayah.phonetic != null && ayah.phonetic!.toLowerCase().contains(q))) {
          results.add((
            surahId: surah.id,
            surahName: surah.name,
            transliteration: surah.transliteration,
            ayah: ayah,
          ));
        }
      }
      if (results.length >= 50) break; // Limit results
    }
    return results;
  }
}
