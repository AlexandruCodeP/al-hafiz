/// Token type on a mushaf line.
enum TokenType { word, end }

/// A single word or verse-end marker on a mushaf page.
class MushafToken {
  final int surah;
  final int ayah;
  final int wordIndex; // 1-based position within the verse
  final String text;   // Uthmani Arabic text
  final String codeV2; // QPC v2 glyph for calligraphic font
  final TokenType type;

  const MushafToken({
    required this.surah,
    required this.ayah,
    required this.wordIndex,
    required this.text,
    required this.codeV2,
    required this.type,
  });
}

/// A single line (1–15) on a mushaf page.
class MushafLine {
  final int lineNumber;
  final List<MushafToken> tokens;

  const MushafLine({
    required this.lineNumber,
    required this.tokens,
  });
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
}
