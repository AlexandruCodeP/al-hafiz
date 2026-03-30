import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteItem {
  final int surahId;
  final int ayahId;
  final DateTime timestamp;

  FavoriteItem({
    required this.surahId,
    required this.ayahId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'surahId': surahId,
    'ayahId': ayahId,
    'timestamp': timestamp.toIso8601String(),
  };

  factory FavoriteItem.fromJson(Map<String, dynamic> json) => FavoriteItem(
    surahId: json['surahId'] as int,
    ayahId: json['ayahId'] as int,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

class StorageService extends ChangeNotifier {
  static const _favoritesKey = 'favorites';
  static const _notesKey = 'notes';
  static const _lastSurahKey = 'lastSurah';
  static const _lastAyahKey = 'lastAyah';
  static const _masteredKey = 'mastered_ayahs';

  // Settings keys
  static const _textSizeKey = 'text_size';
  static const _themeModeKey = 'theme_mode';
  static const _showArabicKey = 'show_arabic';
  static const _showTranslationKey = 'show_translation';
  static const _showPhoneticKey = 'show_phonetic';
  static const _bookmarksKey = 'bookmarks';
  static const _reciterKey = 'reciter_id';

  final SharedPreferences _prefs;

  // In-memory caches
  List<FavoriteItem>? _favoritesCache;
  Set<String>? _masteredCache;
  List<String>? _bookmarksCache;
  Map<String, String>? _notesCache;

  StorageService(this._prefs);

  // --- Favorites ---
  List<FavoriteItem> getFavorites() {
    if (_favoritesCache != null) return _favoritesCache!;
    final data = _prefs.getString(_favoritesKey);
    if (data == null) {
      _favoritesCache = [];
    } else {
      final list = json.decode(data) as List;
      _favoritesCache = list.map((e) => FavoriteItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    return _favoritesCache!;
  }

  Future<void> saveFavorites(List<FavoriteItem> favorites) async {
    _favoritesCache = favorites;
    await _prefs.setString(_favoritesKey, json.encode(favorites.map((f) => f.toJson()).toList()));
    notifyListeners();
  }

  Future<void> toggleFavorite(int surahId, int ayahId) async {
    final favorites = getFavorites();
    final idx = favorites.indexWhere((f) => f.surahId == surahId && f.ayahId == ayahId);
    if (idx >= 0) {
      favorites.removeAt(idx);
    } else {
      favorites.add(FavoriteItem(surahId: surahId, ayahId: ayahId));
    }
    await saveFavorites(favorites);
  }

  bool isFavorite(int surahId, int ayahId) {
    return getFavorites().any((f) => f.surahId == surahId && f.ayahId == ayahId);
  }

  // --- Mastered Ayahs ---
  Set<String> getMasteredAyahs() {
    if (_masteredCache != null) return _masteredCache!;
    final list = _prefs.getStringList(_masteredKey) ?? [];
    _masteredCache = list.toSet();
    return _masteredCache!;
  }

  Future<void> toggleMastered(int surahId, int ayahId) async {
    final mastered = getMasteredAyahs();
    final key = '$surahId:$ayahId';
    if (mastered.contains(key)) {
      mastered.remove(key);
    } else {
      mastered.add(key);
    }
    _masteredCache = mastered;
    await _prefs.setStringList(_masteredKey, mastered.toList());
    notifyListeners();
  }

  bool isMastered(int surahId, int ayahId) {
    return getMasteredAyahs().contains('$surahId:$ayahId');
  }

  double getSurahProgress(int surahId, int totalVerses) {
    if (totalVerses == 0) return 0.0;
    final mastered = getMasteredAyahs();
    int count = 0;
    for (int i = 1; i <= totalVerses; i++) {
      if (mastered.contains('$surahId:$i')) count++;
    }
    return count / totalVerses;
  }

  // --- Notes ---
  Map<String, String> getNotes() {
    if (_notesCache != null) return _notesCache!;
    final data = _prefs.getString(_notesKey);
    if (data == null) {
      _notesCache = {};
    } else {
      _notesCache = Map<String, String>.from(json.decode(data) as Map);
    }
    return _notesCache!;
  }

  Future<void> saveNote(int surahId, int ayahId, String note) async {
    final notes = getNotes();
    final key = '$surahId:$ayahId';
    if (note.isEmpty) {
      notes.remove(key);
    } else {
      notes[key] = note;
    }
    _notesCache = notes;
    await _prefs.setString(_notesKey, json.encode(notes));
    notifyListeners();
  }

  String? getNote(int surahId, int ayahId) {
    return getNotes()['$surahId:$ayahId'];
  }

  // --- Last position ---
  Future<void> saveLastPosition(int surahId, int ayahId) async {
    await _prefs.setInt(_lastSurahKey, surahId);
    await _prefs.setInt(_lastAyahKey, ayahId);
    notifyListeners();
  }

  (int?, int?) getLastPosition() {
    final surah = _prefs.getInt(_lastSurahKey);
    final ayah = _prefs.getInt(_lastAyahKey);
    return (surah, ayah);
  }

  // --- Settings ---
  double get textSizeMultiplier => _prefs.getDouble(_textSizeKey) ?? 1.0;
  Future<void> setTextSizeMultiplier(double value) async {
    await _prefs.setDouble(_textSizeKey, value);
    notifyListeners();
  }

  ThemeMode get themeMode {
    final mode = _prefs.getString(_themeModeKey);
    if (mode == 'light') return ThemeMode.light;
    if (mode == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }
  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeModeKey, mode.name);
    notifyListeners();
  }

  bool get showArabic => _prefs.getBool(_showArabicKey) ?? true;
  Future<void> setShowArabic(bool value) async {
    await _prefs.setBool(_showArabicKey, value);
    notifyListeners();
  }

  bool get showTranslation => _prefs.getBool(_showTranslationKey) ?? true;
  Future<void> setShowTranslation(bool value) async {
    await _prefs.setBool(_showTranslationKey, value);
    notifyListeners();
  }

  bool get showPhonetic => _prefs.getBool(_showPhoneticKey) ?? true;
  Future<void> setShowPhonetic(bool value) async {
    await _prefs.setBool(_showPhoneticKey, value);
    notifyListeners();
  }

  // --- Bookmarks ---
  List<String> getBookmarks() {
    if (_bookmarksCache != null) return _bookmarksCache!;
    _bookmarksCache = _prefs.getStringList(_bookmarksKey) ?? [];
    return _bookmarksCache!;
  }

  Future<void> toggleBookmark(int surahId, int ayahId) async {
    final bookmarks = getBookmarks();
    final key = '$surahId:$ayahId';
    if (bookmarks.contains(key)) {
      bookmarks.remove(key);
    } else {
      bookmarks.add(key);
    }
    _bookmarksCache = bookmarks;
    await _prefs.setStringList(_bookmarksKey, bookmarks);
    notifyListeners();
  }

  bool isBookmarked(int surahId, int ayahId) {
    return getBookmarks().contains('$surahId:$ayahId');
  }

  // --- Reciter ---
  String get reciterId => _prefs.getString(_reciterKey) ?? 'alafasy';
  Future<void> setReciterId(String id) async {
    await _prefs.setString(_reciterKey, id);
    notifyListeners();
  }
}
