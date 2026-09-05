/// Modeles du mode Mushaf : catalogue de packs telechargeables et donnees de
/// mise en page d'une planche imprimee.
///
/// Un « pack » est une archive zip auto-suffisante contenant :
///   meta.json    — identite du pack (id, nom, riwaya, version, lignes/page)
///   layout.db    — SQLite : tables `pages` (lignes imprimees) et `words`
///   fonts/       — une police par page (p1.ttf — p604.ttf) + polices annexes
///
/// Une fois installe, le pack se suffit a lui-meme : plus aucun appel reseau
/// n'est necessaire pour afficher une page.
library;

/// Riwaya (lecture) d'un pack. Sert uniquement au regroupement dans l'ecran
/// « Style d'affichage ».
enum Riwaya {
  hafs('hafs', 'Hafs'),
  warsh('warsh', 'Warsh'),
  qalun('qalun', 'Qalun'),
  other('other', 'Autres');

  const Riwaya(this.id, this.label);

  final String id;
  final String label;

  static Riwaya fromId(String? id) {
    for (final r in Riwaya.values) {
      if (r.id == id) return r;
    }
    return Riwaya.other;
  }
}

/// Etat d'installation d'un pack sur l'appareil.
enum MushafInstallState {
  /// Present au catalogue, absent de l'appareil.
  notInstalled,

  /// Telechargement de l'archive en cours.
  downloading,

  /// Archive telechargee, extraction en cours.
  installing,

  /// Utilisable hors ligne.
  installed,

  /// Installe, mais le catalogue annonce une version plus recente.
  updateAvailable,

  /// Le dernier telechargement a echoue (voir [MushafPackStatus.error]).
  failed,
}

/// Une entree du catalogue distant (`manifest.json`).
class MushafPack {
  final String id;
  final String name;
  final Riwaya riwaya;
  final int version;
  final int linesPerPage;
  final int totalPages;

  /// Taille de l'archive en octets. Sert a l'affichage et a la progression
  /// quand le serveur n'envoie pas de `Content-Length`.
  final int bytes;

  /// Somme de controle SHA-256 de l'archive, en minuscules. Vide = non verifie.
  final String sha256;

  /// URL de l'archive zip. Une entree sans URL est affichee comme
  /// « bientot disponible » plutot que d'echouer au telechargement.
  final String url;

  /// Image d'apercu facultative (une page rendue), affichee sur la carte.
  final String? previewUrl;

  const MushafPack({
    required this.id,
    required this.name,
    required this.riwaya,
    required this.version,
    required this.bytes,
    this.linesPerPage = 15,
    this.totalPages = 604,
    this.sha256 = '',
    this.url = '',
    this.previewUrl,
  });

  bool get isDownloadable => url.isNotEmpty;

  /// Taille lisible, dans le format de la maquette (« ~220 Mo »).
  String get readableSize {
    if (bytes <= 0) return '';
    const mb = 1024 * 1024;
    if (bytes >= mb) return '~${(bytes / mb).round()} Mo';
    return '~${(bytes / 1024).round()} Ko';
  }

  factory MushafPack.fromJson(Map<String, dynamic> json) {
    return MushafPack(
      id: json['id'] as String,
      name: json['name'] as String,
      riwaya: Riwaya.fromId(json['riwaya'] as String?),
      version: (json['version'] as num?)?.toInt() ?? 1,
      linesPerPage: (json['lines_per_page'] as num?)?.toInt() ?? 15,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 604,
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      sha256: (json['sha256'] as String? ?? '').toLowerCase(),
      url: json['url'] as String? ?? '',
      previewUrl: json['preview'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'riwaya': riwaya.id,
    'version': version,
    'lines_per_page': linesPerPage,
    'total_pages': totalPages,
    'bytes': bytes,
    'sha256': sha256,
    'url': url,
    if (previewUrl != null) 'preview': previewUrl,
  };
}

/// Etat courant d'un pack, combinant catalogue et disque.
class MushafPackStatus {
  final MushafPack pack;
  final MushafInstallState state;

  /// Progression 0.0 — 1.0 pendant [MushafInstallState.downloading] et
  /// [MushafInstallState.installing]. -1 si indeterminee.
  final double progress;

  /// Version installee sur l'appareil, si le pack est present.
  final int? installedVersion;

  final String? error;

  const MushafPackStatus({
    required this.pack,
    required this.state,
    this.progress = 0,
    this.installedVersion,
    this.error,
  });

  bool get isBusy =>
      state == MushafInstallState.downloading ||
      state == MushafInstallState.installing;

  bool get isUsable =>
      state == MushafInstallState.installed ||
      state == MushafInstallState.updateAvailable;

  MushafPackStatus copyWith({
    MushafPack? pack,
    MushafInstallState? state,
    double? progress,
    int? installedVersion,
    String? error,
    bool clearError = false,
    bool clearInstalledVersion = false,
  }) {
    return MushafPackStatus(
      pack: pack ?? this.pack,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      installedVersion: clearInstalledVersion
          ? null
          : (installedVersion ?? this.installedVersion),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Nature d'une ligne imprimee.
enum MushafLineType {
  /// Texte coranique.
  ayah,

  /// Bandeau de titre de sourate.
  surahName,

  /// Basmala isolee entre deux sourates.
  basmallah,
}

/// Lit un entier venant de SQLite sans supposer son type.
///
/// SQLite est faiblement type et les exports amont utilisent parfois la chaine
/// vide la ou on attend NULL (bornes de mots d'une ligne de titre). Un cast
/// direct `as num?` ferait planter l'affichage de la page.
int? _asInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.toInt();
  }
  return null;
}

MushafLineType _lineTypeFromDb(String? raw) {
  switch (raw) {
    case 'surah_name':
      return MushafLineType.surahName;
    case 'basmallah':
    case 'bismillah':
      return MushafLineType.basmallah;
    default:
      return MushafLineType.ayah;
  }
}

/// Un mot (ou un marqueur de fin de verset) d'une page.
class MushafWord {
  final int id;
  final int surah;
  final int ayah;

  /// Position 1-based dans le verset. Le marqueur de fin de verset porte la
  /// position suivant le dernier mot.
  final int position;

  /// Texte Unicode uthmani, pour la copie et l'accessibilite.
  final String text;

  /// Glyphe(s) a rendre avec la police de la page.
  final String glyph;

  final int pageNumber;
  final int lineNumber;

  /// Vrai pour le rond de fin de verset : il ne doit ni etre surligne comme un
  /// mot, ni compter dans la synchronisation audio mot a mot.
  final bool isAyahMarker;

  const MushafWord({
    required this.id,
    required this.surah,
    required this.ayah,
    required this.position,
    required this.text,
    required this.glyph,
    required this.pageNumber,
    required this.lineNumber,
    required this.isAyahMarker,
  });

  factory MushafWord.fromRow(Map<String, Object?> row) {
    return MushafWord(
      id: _asInt(row['word_id']) ?? 0,
      surah: _asInt(row['surah']) ?? 0,
      ayah: _asInt(row['ayah']) ?? 0,
      position: _asInt(row['position']) ?? 0,
      text: (row['text'] as String?) ?? '',
      glyph: (row['glyph'] as String?) ?? '',
      pageNumber: _asInt(row['page_number']) ?? 0,
      lineNumber: _asInt(row['line_number']) ?? 0,
      isAyahMarker: (_asInt(row['is_ayah_marker']) ?? 0) == 1,
    );
  }

  /// Cle stable d'un verset, alignee sur celles de StorageService.
  String get ayahKey => '$surah:$ayah';
}

/// Une ligne imprimee, prete a etre rendue.
class MushafLine {
  final int lineNumber;
  final MushafLineType type;

  /// Vrai quand la ligne ne doit pas etre justifiee sur toute la largeur
  /// (derniere ligne d'une sourate, bandeau, basmala). C'est la donnee qui
  /// distingue un rendu fidele d'un rendu approximatif.
  final bool isCentered;

  /// Numero de sourate, pour [MushafLineType.surahName].
  final int? surahNumber;

  final List<MushafWord> words;

  const MushafLine({
    required this.lineNumber,
    required this.type,
    required this.isCentered,
    required this.words,
    this.surahNumber,
  });
}

/// Une page complete du Mushaf.
class MushafPage {
  final int pageNumber;
  final List<MushafLine> lines;

  const MushafPage({required this.pageNumber, required this.lines});

  /// Numeros de sourate presents sur la page.
  Set<int> get surahNumbers {
    final ids = <int>{};
    for (final line in lines) {
      if (line.surahNumber != null) ids.add(line.surahNumber!);
      for (final w in line.words) {
        ids.add(w.surah);
      }
    }
    return ids;
  }

  /// Premier verset de la page, pour le titre et la reprise de lecture.
  MushafWord? get firstWord {
    for (final line in lines) {
      if (line.words.isNotEmpty) return line.words.first;
    }
    return null;
  }
}

/// Construit une page a partir des lignes brutes de `pages` et des mots de
/// `words`, tous deux issus de layout.db.
MushafPage buildMushafPage({
  required int pageNumber,
  required List<Map<String, Object?>> lineRows,
  required List<MushafWord> words,
}) {
  final byLine = <int, List<MushafWord>>{};
  for (final w in words) {
    byLine.putIfAbsent(w.lineNumber, () => <MushafWord>[]).add(w);
  }
  for (final list in byLine.values) {
    list.sort((a, b) => a.id.compareTo(b.id));
  }

  final lines = <MushafLine>[];
  for (final row in lineRows) {
    final lineNumber = _asInt(row['line_number']) ?? 0;
    final type = _lineTypeFromDb(row['line_type'] as String?);
    final first = _asInt(row['first_word_id']);
    final last = _asInt(row['last_word_id']);

    var lineWords = byLine[lineNumber] ?? const <MushafWord>[];
    // Les bornes de la table `pages` font autorite : elles decoupent les
    // lignes meme quand plusieurs partagent un numero apres une correction.
    if (first != null && last != null) {
      lineWords = lineWords.where((w) => w.id >= first && w.id <= last).toList();
    }

    lines.add(MushafLine(
      lineNumber: lineNumber,
      type: type,
      isCentered: (_asInt(row['is_centered']) ?? 0) == 1,
      surahNumber: _asInt(row['surah_number']),
      words: lineWords,
    ));
  }

  lines.sort((a, b) => a.lineNumber.compareTo(b.lineNumber));
  return MushafPage(pageNumber: pageNumber, lines: lines);
}
