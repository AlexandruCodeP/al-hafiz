/// A reference to a specific ayah (surah + verse number).
class AyahRef {
  final int surah;
  final int ayah;

  const AyahRef({required this.surah, required this.ayah});

  @override
  bool operator ==(Object other) =>
      other is AyahRef && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => surah * 1000 + ayah;
}

/// A single line (1–15) on a mushaf page.
///
/// The rendering uses [textQcf] as a single string drawn with the
/// page-specific QCF font. Interaction is handled via [ayahs] which
/// lists every distinct ayah present on this line.
class MushafLine {
  final int lineNumber;
  final String textQcf; // concatenated code_v2 glyphs for the whole line
  final List<AyahRef> ayahs; // distinct ayahs present on this line, in order

  const MushafLine({
    required this.lineNumber,
    required this.textQcf,
    required this.ayahs,
  });

  /// Whether this line contains any content.
  bool get isEmpty => textQcf.isEmpty;

  /// Whether a specific ayah is present on this line.
  bool containsAyah(int surah, int ayah) =>
      ayahs.any((a) => a.surah == surah && a.ayah == ayah);
}

/// A full mushaf page (1–604) with its lines.
class MushafPage {
  final int pageNumber;
  final int juzNumber;
  final List<MushafLine> lines;

  const MushafPage({
    required this.pageNumber,
    required this.juzNumber,
    required this.lines,
  });

  /// The highest line number on this page.
  int get maxLine =>
      lines.isEmpty ? 15 : lines.last.lineNumber;
}
