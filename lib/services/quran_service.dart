import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/surah.dart';

class QuranService {
  static QuranService? _instance;
  List<Surah>? _surahs;
  
  final Map<int, List<String>> _translationCache = {};
  final Map<int, List<String>> _phoneticCache = {};

  QuranService._();

  static QuranService get instance {
    _instance ??= QuranService._();
    return _instance!;
  }

  Future<List<Surah>> getAllSurahs() async {
    if (_surahs != null) return _surahs!;

    try {
      final String jsonStr = await rootBundle.loadString('assets/quran.json');
      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      _surahs = jsonList
          .map((s) => Surah.fromJson(s as Map<String, dynamic>))
          .toList();
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
        );
      }).toList(),
    );
  }

  Future<void> _fetchExtraData(int surahId) async {
    try {
      final transResponse = await http.get(Uri.parse(
          'https://api.quran.com/api/v4/quran/translations/136?chapter_number=$surahId'));
      
      final phoneticResponse = await http.get(Uri.parse(
          'https://api.quran.com/api/v4/quran/transliteration?chapter_number=$surahId'));

      if (transResponse.statusCode == 200) {
        final data = json.decode(transResponse.body);
        _translationCache[surahId] = (data['translations'] as List)
            .map((e) => _cleanHtml(e['text'] as String))
            .toList();
      }

      if (phoneticResponse.statusCode == 200) {
        final data = json.decode(phoneticResponse.body);
        _phoneticCache[surahId] = (data['transliterations'] as List)
            .map((e) => e['text'] as String)
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
}
