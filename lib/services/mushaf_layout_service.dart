import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/mushaf_pack.dart';

/// Lit `layout.db`, la base SQLite embarquee dans un pack Mushaf.
///
/// Deux tables suffisent a reproduire une planche imprimee :
///
/// ```sql
/// pages(page_number, line_number, line_type, is_centered,
///       first_word_id, last_word_id, surah_number)
/// words(word_id, surah, ayah, position, text, glyph,
///       page_number, line_number, is_ayah_marker)
/// ```
///
/// La table `pages` decrit une ligne imprimee par enregistrement : c'est elle
/// qui porte `is_centered`, sans quoi la justification etire des lignes qui ne
/// devraient pas l'etre (fin de sourate, bandeau de titre).
class MushafLayoutService {
  static final MushafLayoutService instance = MushafLayoutService._();
  MushafLayoutService._();

  static const _pageCacheSize = 12;

  Database? _db;
  String? _openedPackId;

  /// Cache LRU des pages deja construites : le PageView revient sans arret
  /// sur les memes pages voisines.
  final Map<int, MushafPage> _pageCache = {};
  final List<int> _pageOrder = [];

  /// Deduplique les chargements concurrents d'une meme page.
  final Map<int, Future<MushafPage?>> _pending = {};

  String? get openedPackId => _openedPackId;
  bool get isOpen => _db != null;

  /// Ouvre la base du pack [packId] situee a [dbPath]. Idempotent : rouvrir le
  /// pack deja ouvert ne fait rien.
  Future<void> open({required String packId, required String dbPath}) async {
    if (_openedPackId == packId && _db != null) return;
    await close();
    _db = await openReadOnlyDatabase(dbPath);
    _openedPackId = packId;
  }

  Future<void> close() async {
    _pageCache.clear();
    _pageOrder.clear();
    _pending.clear();
    final db = _db;
    _db = null;
    _openedPackId = null;
    if (db != null) {
      try {
        await db.close();
      } catch (e) {
        debugPrint('MushafLayoutService: fermeture impossible : $e');
      }
    }
  }

  /// Construit la page [pageNumber] (1-604). Renvoie null si aucun pack n'est
  /// ouvert ou si la page est absente de la base.
  Future<MushafPage?> getPage(int pageNumber) {
    final cached = _pageCache[pageNumber];
    if (cached != null) {
      _touch(pageNumber);
      return Future.value(cached);
    }
    return _pending.putIfAbsent(pageNumber, () => _loadPage(pageNumber));
  }

  Future<MushafPage?> _loadPage(int pageNumber) async {
    final db = _db;
    if (db == null) return null;
    try {
      final lineRows = await db.query(
        'pages',
        where: 'page_number = ?',
        whereArgs: [pageNumber],
        orderBy: 'line_number ASC',
      );
      if (lineRows.isEmpty) return null;

      final wordRows = await db.query(
        'words',
        where: 'page_number = ?',
        whereArgs: [pageNumber],
        orderBy: 'word_id ASC',
      );

      final page = buildMushafPage(
        pageNumber: pageNumber,
        lineRows: lineRows,
        words: wordRows.map(MushafWord.fromRow).toList(),
      );
      _remember(pageNumber, page);
      return page;
    } catch (e) {
      debugPrint('MushafLayoutService: page $pageNumber illisible : $e');
      return null;
    } finally {
      _pending.remove(pageNumber);
    }
  }

  /// Numero de page contenant le verset demande, ou null.
  Future<int?> pageOfAyah(int surah, int ayah) async {
    final db = _db;
    if (db == null) return null;
    try {
      final rows = await db.query(
        'words',
        columns: ['page_number'],
        where: 'surah = ? AND ayah = ?',
        whereArgs: [surah, ayah],
        orderBy: 'word_id ASC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return (rows.first['page_number'] as num).toInt();
    } catch (e) {
      debugPrint('MushafLayoutService: page de $surah:$ayah introuvable : $e');
      return null;
    }
  }

  /// Precharge les pages voisines sans bloquer l'appelant.
  void prefetch(Iterable<int> pages) {
    for (final p in pages) {
      if (p < 1) continue;
      if (_pageCache.containsKey(p) || _pending.containsKey(p)) continue;
      getPage(p);
    }
  }

  void _remember(int pageNumber, MushafPage page) {
    _pageCache[pageNumber] = page;
    _touch(pageNumber);
    while (_pageOrder.length > _pageCacheSize) {
      final evicted = _pageOrder.removeAt(0);
      _pageCache.remove(evicted);
    }
  }

  void _touch(int pageNumber) {
    _pageOrder.remove(pageNumber);
    _pageOrder.add(pageNumber);
  }
}
