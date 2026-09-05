import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/mushaf_pack.dart';
import 'mushaf_layout_service.dart';
import 'qcf_font_service.dart';

/// Catalogue, telechargement et installation des packs Mushaf.
///
/// Arborescence sur l'appareil :
///
/// ```
/// <application support>/mushaf/
///   manifest.json          copie du catalogue, pour l'ouverture hors ligne
///   tmp/<id>.zip           telechargement en cours (reprenable)
///   packs/<id>/            pack extrait
///     .installed           marqueur JSON ecrit apres verification
///     meta.json
///     layout.db
///     fonts/p1.ttf ...
/// ```
///
/// Le dossier « application support » est choisi volontairement plutot que le
/// cache : iOS purge le cache sous pression disque, et l'utilisateur perdrait
/// 200 Mo telecharges sans comprendre pourquoi. Le marqueur `.installed` n'est
/// ecrit qu'une fois la somme de controle validee et l'archive extraite : un
/// telechargement interrompu ne peut donc pas passer pour un pack utilisable.
///
/// Reste a faire cote iOS : marquer ce dossier `NSURLIsExcludedFromBackupKey`
/// pour qu'il ne parte pas dans iCloud. Cela demande un canal de plateforme,
/// Dart seul n'y a pas acces.
class MushafRepository extends ChangeNotifier {
  MushafRepository({Dio? dio}) : _dio = dio ?? Dio(_defaultOptions);

  /// Catalogue distant. Surchargeable au build :
  /// `flutter run --dart-define=MUSHAF_MANIFEST_URL=https://...`
  static const manifestUrl = String.fromEnvironment(
    'MUSHAF_MANIFEST_URL',
    defaultValue:
        'https://raw.githubusercontent.com/AlexandruCodeP/al-hafiz/master/packs/manifest.json',
  );

  static BaseOptions get _defaultOptions => BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 60),
    followRedirects: true,
  );

  final Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};

  Directory? _base;
  bool _initialised = false;
  bool _ready = false;
  bool _refreshing = false;
  String? _catalogueError;
  String? _activePackId;

  final Map<String, MushafPackStatus> _statuses = {};

  /// Vrai une fois le disque scanne : avant cela, l'absence de pack actif ne
  /// veut pas dire qu'aucun pack n'est installe.
  bool get isReady => _ready;
  bool get isRefreshing => _refreshing;

  /// Message d'erreur du dernier rafraichissement du catalogue, s'il a echoue.
  String? get catalogueError => _catalogueError;

  String? get activePackId => _activePackId;

  /// Vrai des qu'au moins un pack est utilisable hors ligne.
  bool get hasInstalledPack => _statuses.values.any((s) => s.isUsable);

  MushafPackStatus? statusOf(String packId) => _statuses[packId];

  MushafPackStatus? get activeStatus =>
      _activePackId == null ? null : _statuses[_activePackId];

  /// Packs regroupes par riwaya, dans l'ordre d'affichage de l'ecran de style.
  Map<Riwaya, List<MushafPackStatus>> get grouped {
    final out = <Riwaya, List<MushafPackStatus>>{};
    for (final riwaya in Riwaya.values) {
      final list = _statuses.values.where((s) => s.pack.riwaya == riwaya).toList()
        ..sort((a, b) => a.pack.name.compareTo(b.pack.name));
      if (list.isNotEmpty) out[riwaya] = list;
    }
    return out;
  }

  // ── Cycle de vie ─────────────────────────────────────────────────────────

  /// Scanne le disque, relit le catalogue en cache puis, en tache de fond,
  /// rafraichit le catalogue distant.
  Future<void> init({String? preferredPackId}) async {
    if (_initialised) return;
    _initialised = true;
    try {
      final support = await getApplicationSupportDirectory();
      _base = Directory(p.join(support.path, 'mushaf'));
      await _base!.create(recursive: true);

      await _loadCachedCatalogue();
      await _scanInstalled();

      final candidate = preferredPackId != null &&
              (_statuses[preferredPackId]?.isUsable ?? false)
          ? preferredPackId
          : _firstUsablePackId();
      if (candidate != null) {
        await _openPack(candidate);
      }
    } catch (e) {
      debugPrint('MushafRepository: initialisation impossible : $e');
    }
    _ready = true;
    notifyListeners();
    unawaited(refreshCatalogue());
  }

  /// Recharge le catalogue distant. Ne fait jamais disparaitre un pack installe.
  Future<void> refreshCatalogue() async {
    if (_refreshing) return;
    _refreshing = true;
    _catalogueError = null;
    notifyListeners();
    try {
      final res = await _dio.get<String>(
        manifestUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final body = res.data;
      if (body == null || body.isEmpty) throw const FormatException('vide');
      final packs = _parseManifest(body);
      if (packs.isEmpty) throw const FormatException('catalogue sans pack');
      _mergeCatalogue(packs);
      await _writeCachedCatalogue(body);
    } catch (e) {
      _catalogueError = _humanError(e);
      debugPrint('MushafRepository: catalogue indisponible : $e');
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  // ── Telechargement ───────────────────────────────────────────────────────

  /// Telecharge et installe [packId]. Reprend un telechargement interrompu si
  /// l'archive partielle est encore la et que le serveur accepte les plages.
  Future<void> download(String packId) async {
    final base = _base;
    final status = _statuses[packId];
    if (base == null || status == null) return;
    if (status.isBusy) return;
    if (!status.pack.isDownloadable) {
      _update(packId, (s) => s.copyWith(
            state: MushafInstallState.failed,
            error: 'Ce pack n\'est pas encore disponible au telechargement.',
          ));
      return;
    }

    final pack = status.pack;
    final tmpDir = Directory(p.join(base.path, 'tmp'));
    await tmpDir.create(recursive: true);
    final archive = File(p.join(tmpDir.path, '${pack.id}.zip'));
    final cancelToken = CancelToken();
    _cancelTokens[packId] = cancelToken;

    _update(packId, (s) => s.copyWith(
          state: MushafInstallState.downloading,
          progress: 0,
          clearError: true,
        ));

    try {
      await _fetchArchive(pack, archive, cancelToken);
      if (cancelToken.isCancelled) return;

      _update(packId, (s) => s.copyWith(
            state: MushafInstallState.installing,
            progress: -1,
          ));

      if (pack.sha256.isNotEmpty) {
        final digest = await _sha256OfFile(archive);
        if (digest != pack.sha256) {
          await archive.delete();
          throw const _PackException(
            'Archive corrompue (signature invalide). Reessayez.',
          );
        }
      }

      // Mise a jour d'un pack en cours d'utilisation : fermer la base avant
      // d'effacer l'ancienne installation. Elle sera rouverte plus bas.
      if (_activePackId == pack.id) {
        await MushafLayoutService.instance.close();
        _activePackId = null;
      }

      final dest = Directory(p.join(base.path, 'packs', pack.id));
      if (await dest.exists()) await dest.delete(recursive: true);
      await dest.create(recursive: true);

      final zipPath = archive.path;
      final destPath = dest.path;
      // L'extraction est lourde (604 fichiers) : on la sort de l'isolate UI.
      await Isolate.run(() => extractFileToDisk(zipPath, destPath));

      final root = await _locatePackRoot(dest);
      if (root == null) {
        await dest.delete(recursive: true);
        throw const _PackException('Archive invalide : meta.json introuvable.');
      }
      if (!await File(p.join(root.path, 'layout.db')).exists()) {
        await dest.delete(recursive: true);
        throw const _PackException('Archive invalide : layout.db introuvable.');
      }

      final relativeRoot = p.relative(root.path, from: dest.path);
      await File(p.join(dest.path, '.installed')).writeAsString(json.encode({
        'version': pack.version,
        'root': relativeRoot,
        'installedAt': DateTime.now().toIso8601String(),
      }));
      _installedRoots[pack.id] = relativeRoot;
      await archive.delete();

      QcfFontService.instance.forgetPack(pack.id);
      _update(packId, (s) => s.copyWith(
            state: MushafInstallState.installed,
            progress: 1,
            installedVersion: pack.version,
            clearError: true,
          ));

      if (_activePackId == null) await setActivePack(pack.id);
    } on _PackException catch (e) {
      _fail(packId, e.message);
    } catch (e) {
      if (cancelToken.isCancelled) {
        _update(packId, (s) => s.copyWith(
              state: MushafInstallState.notInstalled,
              progress: 0,
            ));
      } else {
        _fail(packId, _humanError(e));
      }
    } finally {
      _cancelTokens.remove(packId);
    }
  }

  /// Ecrit l'archive sur disque en suivant la progression, en reprenant le
  /// fichier partiel eventuel via un en-tete `Range`.
  Future<void> _fetchArchive(
    MushafPack pack,
    File archive,
    CancelToken cancelToken,
  ) async {
    var received = (await archive.exists()) ? await archive.length() : 0;
    // Un fichier partiel plus gros que la taille annoncee est forcement le
    // reliquat d'une version precedente : on repart de zero.
    if (pack.bytes > 0 && received >= pack.bytes) {
      received = 0;
      if (await archive.exists()) await archive.delete();
    }

    final response = await _dio.get<ResponseBody>(
      pack.url,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: received > 0 ? {'range': 'bytes=$received-'} : null,
        // 416 = la plage demandee n'a plus de sens cote serveur ; on veut
        // pouvoir le traiter nous-memes plutot que de lever.
        validateStatus: (code) =>
            code != null && (code == 200 || code == 206 || code == 416),
      ),
    );

    if (response.statusCode == 416) {
      if (await archive.exists()) await archive.delete();
      return _fetchArchive(pack, archive, cancelToken);
    }

    final resumed = response.statusCode == 206 && received > 0;
    if (!resumed) received = 0;

    final declared =
        int.tryParse(response.headers.value('content-length') ?? '') ?? 0;
    final total = resumed
        ? received + declared
        : (declared > 0 ? declared : pack.bytes);

    final sink = archive.openWrite(
      mode: resumed ? FileMode.append : FileMode.write,
    );
    var lastNotified = 0;
    try {
      await for (final chunk in response.data!.stream) {
        if (cancelToken.isCancelled) break;
        sink.add(chunk);
        received += chunk.length;
        // Une notification par tranche de 512 Ko : suffisant pour une barre
        // fluide, sans reconstruire l'ecran a chaque paquet TCP.
        if (received - lastNotified >= 512 * 1024) {
          lastNotified = received;
          _update(
            pack.id,
            (s) => s.copyWith(
              progress: total > 0 ? (received / total).clamp(0.0, 1.0) : -1,
            ),
          );
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  /// Annule un telechargement en cours. L'archive partielle est conservee pour
  /// permettre une reprise.
  void cancel(String packId) {
    _cancelTokens.remove(packId)?.cancel('annule');
  }

  /// Supprime un pack installe et libere l'espace disque.
  Future<void> remove(String packId) async {
    final base = _base;
    if (base == null) return;
    cancel(packId);

    if (_activePackId == packId) {
      _activePackId = null;
      await MushafLayoutService.instance.close();
    }

    final dir = Directory(p.join(base.path, 'packs', packId));
    if (await dir.exists()) await dir.delete(recursive: true);
    final partial = File(p.join(base.path, 'tmp', '$packId.zip'));
    if (await partial.exists()) await partial.delete();

    QcfFontService.instance.forgetPack(packId);
    _installedRoots.remove(packId);
    _update(packId, (s) => s.copyWith(
          state: MushafInstallState.notInstalled,
          progress: 0,
          clearInstalledVersion: true,
          clearError: true,
        ));

    // Bascule sur un autre pack installe s'il en reste un.
    if (_activePackId == null) {
      final next = _firstUsablePackId();
      if (next != null) await setActivePack(next);
    }
    notifyListeners();
  }

  /// Choisit le pack utilise par le lecteur Mushaf.
  Future<void> setActivePack(String packId) async {
    if (!(_statuses[packId]?.isUsable ?? false)) return;
    await _openPack(packId);
    notifyListeners();
  }

  /// Dossier des polices du pack, a passer a [QcfFontService].
  String? fontsDirOf(String packId) {
    final root = _packRoot(packId);
    return root == null ? null : p.join(root, 'fonts');
  }

  // ── Interne ──────────────────────────────────────────────────────────────

  Future<void> _openPack(String packId) async {
    final root = _packRoot(packId);
    if (root == null) return;
    try {
      await MushafLayoutService.instance.open(
        packId: packId,
        dbPath: p.join(root, 'layout.db'),
      );
      _activePackId = packId;
    } catch (e) {
      debugPrint('MushafRepository: ouverture de $packId impossible : $e');
      _fail(packId, 'Pack illisible, une reinstallation est necessaire.');
    }
  }

  String? _packRoot(String packId) {
    final base = _base;
    if (base == null) return null;
    final dir = p.join(base.path, 'packs', packId);
    final relative = _installedRoots[packId];
    if (relative == null || relative.isEmpty || relative == '.') return dir;
    return p.join(dir, relative);
  }

  final Map<String, String> _installedRoots = {};

  /// Reconstitue l'etat des packs presents sur le disque, catalogue ou non :
  /// un pack installe doit rester utilisable meme si le catalogue est
  /// injoignable ou si l'entree en a disparu.
  Future<void> _scanInstalled() async {
    final base = _base;
    if (base == null) return;
    final packsDir = Directory(p.join(base.path, 'packs'));
    if (!await packsDir.exists()) return;

    await for (final entity in packsDir.list()) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      final marker = File(p.join(entity.path, '.installed'));
      if (!await marker.exists()) {
        // Extraction interrompue : on nettoie plutot que de laisser un pack
        // a moitie installe qui planterait a l'ouverture.
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
        continue;
      }

      int installedVersion = 1;
      String root = '';
      try {
        final data = json.decode(await marker.readAsString());
        installedVersion = (data['version'] as num?)?.toInt() ?? 1;
        root = data['root'] as String? ?? '';
      } catch (_) {}
      _installedRoots[id] = root;

      final meta = await _readMeta(p.join(entity.path, root));
      final catalogued = _statuses[id]?.pack;
      final pack = catalogued ?? meta ?? _placeholderPack(id, installedVersion);

      _statuses[id] = MushafPackStatus(
        pack: pack,
        state: pack.version > installedVersion
            ? MushafInstallState.updateAvailable
            : MushafInstallState.installed,
        progress: 1,
        installedVersion: installedVersion,
      );
    }
  }

  Future<MushafPack?> _readMeta(String rootPath) async {
    try {
      final file = File(p.join(rootPath, 'meta.json'));
      if (!await file.exists()) return null;
      final data = json.decode(await file.readAsString()) as Map<String, dynamic>;
      return MushafPack.fromJson(data);
    } catch (e) {
      debugPrint('MushafRepository: meta.json illisible : $e');
      return null;
    }
  }

  MushafPack _placeholderPack(String id, int version) => MushafPack(
        id: id,
        name: id,
        riwaya: Riwaya.other,
        version: version,
        bytes: 0,
      );

  List<MushafPack> _parseManifest(String body) {
    final data = json.decode(body);
    final list = data is Map<String, dynamic> ? data['packs'] : data;
    if (list is! List) return const [];
    final packs = <MushafPack>[];
    for (final entry in list) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        packs.add(MushafPack.fromJson(entry));
      } catch (e) {
        debugPrint('MushafRepository: entree de catalogue ignoree : $e');
      }
    }
    return packs;
  }

  void _mergeCatalogue(List<MushafPack> packs) {
    for (final pack in packs) {
      final existing = _statuses[pack.id];
      if (existing == null) {
        _statuses[pack.id] = MushafPackStatus(
          pack: pack,
          state: MushafInstallState.notInstalled,
        );
        continue;
      }
      if (existing.isBusy) {
        // Ne pas perturber un telechargement en cours.
        continue;
      }
      final installed = existing.installedVersion;
      _statuses[pack.id] = existing.copyWith(
        pack: pack,
        state: installed == null
            ? existing.state
            : (pack.version > installed
                ? MushafInstallState.updateAvailable
                : MushafInstallState.installed),
      );
    }
  }

  Future<void> _loadCachedCatalogue() async {
    final base = _base;
    if (base == null) return;
    try {
      final file = File(p.join(base.path, 'manifest.json'));
      if (!await file.exists()) return;
      _mergeCatalogue(_parseManifest(await file.readAsString()));
    } catch (e) {
      debugPrint('MushafRepository: catalogue en cache illisible : $e');
    }
  }

  Future<void> _writeCachedCatalogue(String body) async {
    final base = _base;
    if (base == null) return;
    try {
      await File(p.join(base.path, 'manifest.json')).writeAsString(body);
    } catch (e) {
      debugPrint('MushafRepository: catalogue non mis en cache : $e');
    }
  }

  /// Localise le dossier contenant `meta.json` : a la racine de l'archive, ou
  /// un niveau plus bas si le zip a ete cree avec un dossier englobant.
  Future<Directory?> _locatePackRoot(Directory dest) async {
    if (await File(p.join(dest.path, 'meta.json')).exists()) return dest;
    await for (final entity in dest.list()) {
      if (entity is Directory &&
          await File(p.join(entity.path, 'meta.json')).exists()) {
        return entity;
      }
    }
    return null;
  }

  Future<String> _sha256OfFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase();
  }

  String? _firstUsablePackId() {
    for (final status in _statuses.values) {
      if (status.isUsable) return status.pack.id;
    }
    return null;
  }

  void _update(
    String packId,
    MushafPackStatus Function(MushafPackStatus) transform,
  ) {
    final current = _statuses[packId];
    if (current == null) return;
    _statuses[packId] = transform(current);
    notifyListeners();
  }

  void _fail(String packId, String message) {
    _update(packId, (s) => s.copyWith(
          state: MushafInstallState.failed,
          progress: 0,
          error: message,
        ));
  }

  String _humanError(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'Connexion trop lente, reessayez.';
        case DioExceptionType.connectionError:
          return 'Pas de connexion internet.';
        case DioExceptionType.badResponse:
          return 'Pack indisponible sur le serveur (${e.response?.statusCode}).';
        default:
          return 'Telechargement interrompu.';
      }
    }
    if (e is FileSystemException) {
      return 'Espace de stockage insuffisant.';
    }
    return 'Une erreur est survenue.';
  }

  @override
  void dispose() {
    for (final token in _cancelTokens.values) {
      token.cancel('dispose');
    }
    _cancelTokens.clear();
    _dio.close(force: true);
    super.dispose();
  }
}

class _PackException implements Exception {
  final String message;
  const _PackException(this.message);
  @override
  String toString() => message;
}
