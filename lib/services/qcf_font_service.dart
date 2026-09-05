import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Enregistre a la demande les polices d'un pack Mushaf installe.
///
/// Chaque page du Mushaf a sa propre police : un glyphe par mot, dessine pour
/// la position exacte qu'il occupe sur cette page. C'est ce qui donne un rendu
/// identique au livre imprime, et c'est aussi ce qui rend un pack volumineux.
///
/// Limite du moteur Flutter, a connaitre avant de toucher a ce fichier : une
/// famille enregistree via [FontLoader] ne peut plus etre liberee. Il n'existe
/// pas d'API de dechargement. On ne peut donc pas evincer les polices d'un
/// cache LRU ; on peut seulement limiter le nombre de familles qu'on decide
/// d'enregistrer. D'ou la strategie ci-dessous :
///
///   * la page affichee est toujours chargee, quoi qu'il arrive ;
///   * les pages voisines ne sont prechargees que tant que le budget memoire
///     [_prefetchBudgetBytes] n'est pas atteint.
///
/// En lecture normale (quelques dizaines de pages par session) l'empreinte
/// reste modeste. Un parcours complet des 604 pages en une seule session reste
/// couteux : c'est une contrainte du moteur, pas un oubli.
class QcfFontService {
  static final QcfFontService instance = QcfFontService._();
  QcfFontService._();

  /// Au-dela, on cesse de precharger les pages voisines.
  static const _prefetchBudgetBytes = 48 * 1024 * 1024;

  final Set<String> _loaded = {};
  final Map<String, Future<bool>> _pending = {};
  int _loadedBytes = 0;

  /// Octets de police actuellement enregistres dans le moteur.
  int get loadedBytes => _loadedBytes;

  /// Nom de famille unique pour une page d'un pack donne.
  ///
  /// L'identifiant du pack fait partie du nom : deux packs contiennent tous les
  /// deux un `p1.ttf`, avec des glyphes differents, et comme rien ne peut etre
  /// decharge les deux doivent pouvoir coexister.
  String familyFor(String packId, int page) =>
      'QCF_${_sanitize(packId)}_P$page';

  bool isLoaded(String packId, int page) =>
      _loaded.contains(familyFor(packId, page));

  /// Enregistre la police de [page]. Renvoie false si le fichier manque ou est
  /// illisible — l'appelant affiche alors le texte Unicode en repli.
  Future<bool> ensureFont({
    required String packId,
    required String fontsDir,
    required int page,
  }) {
    final family = familyFor(packId, page);
    if (_loaded.contains(family)) return Future.value(true);
    return _pending.putIfAbsent(
      family,
      () => _load(family: family, fontsDir: fontsDir, page: page),
    );
  }

  Future<bool> _load({
    required String family,
    required String fontsDir,
    required int page,
  }) async {
    try {
      final file = File('$fontsDir/p$page.ttf');
      if (!await file.exists()) {
        debugPrint('QcfFontService: police manquante pour la page $page');
        return false;
      }
      final bytes = await file.readAsBytes();
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      _loaded.add(family);
      _loadedBytes += bytes.lengthInBytes;
      return true;
    } catch (e) {
      debugPrint('QcfFontService: chargement de la page $page impossible : $e');
      return false;
    } finally {
      _pending.remove(family);
    }
  }

  /// Enregistre une police annexe du pack (fins de verset, noms de sourate).
  /// [fileName] est relatif au dossier `fonts/` du pack.
  Future<bool> ensureNamedFont({
    required String packId,
    required String fontsDir,
    required String fileName,
    required String familySuffix,
  }) {
    final family = '${_sanitize(packId)}_$familySuffix';
    if (_loaded.contains(family)) return Future.value(true);
    return _pending.putIfAbsent(family, () async {
      try {
        final file = File('$fontsDir/$fileName');
        if (!await file.exists()) return false;
        final bytes = await file.readAsBytes();
        final loader = FontLoader(family)
          ..addFont(Future.value(ByteData.view(bytes.buffer)));
        await loader.load();
        _loaded.add(family);
        _loadedBytes += bytes.lengthInBytes;
        return true;
      } catch (e) {
        debugPrint('QcfFontService: police $fileName illisible : $e');
        return false;
      } finally {
        _pending.remove(family);
      }
    });
  }

  String namedFamily(String packId, String familySuffix) =>
      '${_sanitize(packId)}_$familySuffix';

  /// Precharge les pages voisines, sans depasser le budget memoire.
  void prefetch({
    required String packId,
    required String fontsDir,
    required Iterable<int> pages,
  }) {
    if (_loadedBytes >= _prefetchBudgetBytes) return;
    for (final page in pages) {
      if (page < 1) continue;
      if (isLoaded(packId, page)) continue;
      ensureFont(packId: packId, fontsDir: fontsDir, page: page);
    }
  }

  /// Oublie les familles d'un pack desinstalle. Le moteur garde les glyphes en
  /// memoire jusqu'au prochain lancement, mais plus rien n'y fait reference et
  /// une reinstallation rechargera proprement.
  void forgetPack(String packId) {
    final prefix = 'QCF_${_sanitize(packId)}_P';
    final named = '${_sanitize(packId)}_';
    _loaded.removeWhere((f) => f.startsWith(prefix) || f.startsWith(named));
  }

  static String _sanitize(String id) =>
      id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
}
