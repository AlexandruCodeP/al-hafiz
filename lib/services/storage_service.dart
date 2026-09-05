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
  static const _arabicTextSizeKey = 'arabic_text_size';
  static const _translationTextSizeKey = 'translation_text_size';
  static const _themeModeKey = 'theme_mode';
  static const _showArabicKey = 'show_arabic';
  static const _showTranslationKey = 'show_translation';
  static const _showPhoneticKey = 'show_phonetic';
  static const _bookmarksKey = 'bookmarks';
  static const _reciterKey = 'reciter_id';
  static const _recentSurahsKey = 'recent_surahs';
  static const _onboardingCompleteKey = 'onboarding_complete';
  static const _mushafPackKey = 'mushaf_pack_id';

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

  // --- Stats helpers ---
  int get totalMasteredAyahs => getMasteredAyahs().length;

  int get surahsStarted {
    final mastered = getMasteredAyahs();
    final surahIds = <int>{};
    for (final key in mastered) {
      surahIds.add(int.parse(key.split(':')[0]));
    }
    return surahIds.length;
  }

  // --- Recent Surahs ---
  List<int> getRecentSurahs() {
    return _prefs.getStringList(_recentSurahsKey)?.map(int.parse).toList() ?? [];
  }

  Future<void> addRecentSurah(int surahId) async {
    final recent = getRecentSurahs();
    recent.remove(surahId);
    recent.insert(0, surahId);
    final trimmed = recent.take(5).toList();
    await _prefs.setStringList(_recentSurahsKey, trimmed.map((e) => e.toString()).toList());
    notifyListeners();
  }

  // --- Last position ---
  Future<void> saveLastPosition(int surahId, int ayahId) async {
    await _prefs.setInt(_lastSurahKey, surahId);
    await _prefs.setInt(_lastAyahKey, ayahId);
    addRecentSurah(surahId);
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

  double get arabicTextSize => _prefs.getDouble(_arabicTextSizeKey) ?? 1.0;
  Future<void> setArabicTextSize(double value) async {
    await _prefs.setDouble(_arabicTextSizeKey, value);
    notifyListeners();
  }

  double get translationTextSize => _prefs.getDouble(_translationTextSizeKey) ?? 1.0;
  Future<void> setTranslationTextSize(double value) async {
    await _prefs.setDouble(_translationTextSizeKey, value);
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

  // --- Onboarding ---
  bool get onboardingComplete => _prefs.getBool(_onboardingCompleteKey) ?? false;
  Future<void> setOnboardingComplete() async {
    await _prefs.setBool(_onboardingCompleteKey, true);
    notifyListeners();
  }

  // --- Mushaf ---
  /// Edition du Mushaf choisie par l'utilisateur. Null tant qu'aucun pack n'a
  /// ete telecharge.
  String? get mushafPackId => _prefs.getString(_mushafPackKey);
  Future<void> setMushafPackId(String id) async {
    await _prefs.setString(_mushafPackKey, id);
    notifyListeners();
  }

  // --- Reciter ---
  String get reciterId => _prefs.getString(_reciterKey) ?? 'alafasy';
  Future<void> setReciterId(String id) async {
    await _prefs.setString(_reciterKey, id);
    notifyListeners();
  }

  // --- Export / Import / Reset ---
  String exportToJson() {
    final data = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'favorites': getFavorites().map((f) => f.toJson()).toList(),
      'mastered': getMasteredAyahs().toList(),
      'notes': getNotes(),
      'bookmarks': getBookmarks(),
      'lastSurah': _prefs.getInt(_lastSurahKey),
      'lastAyah': _prefs.getInt(_lastAyahKey),
      'recentSurahs': getRecentSurahs(),
      'settings': {
        'textSize': textSizeMultiplier,
        'arabicTextSize': arabicTextSize,
        'translationTextSize': translationTextSize,
        'themeMode': themeMode.name,
        'showArabic': showArabic,
        'showTranslation': showTranslation,
        'showPhonetic': showPhonetic,
        'reciterId': reciterId,
      },
    };
    return json.encode(data);
  }

  Future<void> importFromJson(String jsonString) async {
    final data = json.decode(jsonString) as Map<String, dynamic>;

    // Favorites
    if (data['favorites'] != null) {
      final favs = (data['favorites'] as List)
          .map((e) => FavoriteItem.fromJson(e as Map<String, dynamic>))
          .toList();
      await saveFavorites(favs);
    }

    // Mastered
    if (data['mastered'] != null) {
      final mastered = (data['mastered'] as List).cast<String>().toSet();
      _masteredCache = mastered;
      await _prefs.setStringList(_masteredKey, mastered.toList());
    }

    // Notes
    if (data['notes'] != null) {
      final notes = Map<String, String>.from(data['notes'] as Map);
      _notesCache = notes;
      await _prefs.setString(_notesKey, json.encode(notes));
    }

    // Bookmarks
    if (data['bookmarks'] != null) {
      final bookmarks = (data['bookmarks'] as List).cast<String>();
      _bookmarksCache = bookmarks;
      await _prefs.setStringList(_bookmarksKey, bookmarks);
    }

    // Last position
    if (data['lastSurah'] != null) {
      await _prefs.setInt(_lastSurahKey, data['lastSurah'] as int);
    }
    if (data['lastAyah'] != null) {
      await _prefs.setInt(_lastAyahKey, data['lastAyah'] as int);
    }

    // Recent surahs
    if (data['recentSurahs'] != null) {
      final recent = (data['recentSurahs'] as List).cast<int>();
      await _prefs.setStringList(_recentSurahsKey, recent.map((e) => e.toString()).toList());
    }

    // Settings
    if (data['settings'] != null) {
      final s = data['settings'] as Map<String, dynamic>;
      if (s['textSize'] != null) await setTextSizeMultiplier((s['textSize'] as num).toDouble());
      if (s['arabicTextSize'] != null) await setArabicTextSize((s['arabicTextSize'] as num).toDouble());
      if (s['translationTextSize'] != null) await setTranslationTextSize((s['translationTextSize'] as num).toDouble());
      if (s['themeMode'] != null) {
        final mode = ThemeMode.values.firstWhere(
          (m) => m.name == s['themeMode'],
          orElse: () => ThemeMode.system,
        );
        await setThemeMode(mode);
      }
      if (s['showArabic'] != null) await setShowArabic(s['showArabic'] as bool);
      if (s['showTranslation'] != null) await setShowTranslation(s['showTranslation'] as bool);
      if (s['showPhonetic'] != null) await setShowPhonetic(s['showPhonetic'] as bool);
      if (s['reciterId'] != null) await setReciterId(s['reciterId'] as String);
    }

    notifyListeners();
  }

  Future<void> resetAllData() async {
    await _prefs.remove(_favoritesKey);
    await _prefs.remove(_notesKey);
    await _prefs.remove(_masteredKey);
    await _prefs.remove(_bookmarksKey);
    await _prefs.remove(_lastSurahKey);
    await _prefs.remove(_lastAyahKey);
    await _prefs.remove(_recentSurahsKey);

    _favoritesCache = null;
    _masteredCache = null;
    _bookmarksCache = null;
    _notesCache = null;

    notifyListeners();
  }
}
