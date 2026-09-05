import 'package:al_hafiz/models/mushaf_pack.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ligne brute telle que `layout.db` la renvoie.
Map<String, Object?> lineRow({
  required int line,
  String type = 'ayah',
  int centered = 0,
  int? first,
  int? last,
  int? surah,
}) =>
    {
      'page_number': 1,
      'line_number': line,
      'line_type': type,
      'is_centered': centered,
      'first_word_id': first,
      'last_word_id': last,
      'surah_number': surah,
    };

MushafWord word({
  required int id,
  required int line,
  int surah = 1,
  int ayah = 1,
  int position = 1,
}) =>
    MushafWord(
      id: id,
      surah: surah,
      ayah: ayah,
      position: position,
      text: 'kalima',
      glyph: 'g',
      pageNumber: 1,
      lineNumber: line,
      isAyahMarker: false,
    );

void main() {
  group('buildMushafPage', () {
    test('repartit les mots sur leurs lignes et trie les lignes', () {
      final page = buildMushafPage(
        pageNumber: 1,
        lineRows: [
          lineRow(line: 2, first: 3, last: 4),
          lineRow(line: 1, first: 1, last: 2),
        ],
        words: [
          word(id: 3, line: 2),
          word(id: 1, line: 1),
          word(id: 4, line: 2),
          word(id: 2, line: 1),
        ],
      );

      expect(page.lines.map((l) => l.lineNumber), [1, 2]);
      expect(page.lines.first.words.map((w) => w.id), [1, 2]);
      expect(page.lines.last.words.map((w) => w.id), [3, 4]);
    });

    test('les bornes de la table pages font autorite sur line_number', () {
      // Cas reel : deux lignes de `pages` se partagent des mots portant le
      // meme line_number. Sans le filtrage par first/last_word_id, la
      // deuxieme ligne recupererait les mots de la premiere.
      final page = buildMushafPage(
        pageNumber: 1,
        lineRows: [
          lineRow(line: 1, first: 1, last: 2),
          lineRow(line: 1, first: 3, last: 4),
        ],
        words: [
          word(id: 1, line: 1),
          word(id: 2, line: 1),
          word(id: 3, line: 1),
          word(id: 4, line: 1),
        ],
      );

      expect(page.lines.first.words.map((w) => w.id), [1, 2]);
      expect(page.lines.last.words.map((w) => w.id), [3, 4]);
    });

    test('reconnait les lignes centrees et les bandeaux de sourate', () {
      final page = buildMushafPage(
        pageNumber: 1,
        lineRows: [
          lineRow(line: 1, type: 'surah_name', centered: 1, surah: 36),
          lineRow(line: 2, type: 'basmallah', centered: 1),
          lineRow(line: 3, first: 1, last: 1),
        ],
        words: [word(id: 1, line: 3)],
      );

      expect(page.lines[0].type, MushafLineType.surahName);
      expect(page.lines[0].surahNumber, 36);
      expect(page.lines[0].isCentered, isTrue);
      expect(page.lines[1].type, MushafLineType.basmallah);
      expect(page.lines[2].type, MushafLineType.ayah);
      expect(page.lines[2].isCentered, isFalse);
    });

    test('tolere les bornes vides des exports QUL', () {
      // Les exports QUL ecrivent '' plutot que NULL sur les lignes de titre :
      // un cast direct en num ferait planter l'affichage de la page.
      final page = buildMushafPage(
        pageNumber: 1,
        lineRows: [
          {
            'page_number': 1,
            'line_number': '1',
            'line_type': 'surah_name',
            'is_centered': '1',
            'first_word_id': '',
            'last_word_id': '',
            'surah_number': '1',
          },
          {
            'page_number': 1,
            'line_number': 2,
            'line_type': 'ayah',
            'is_centered': 0,
            'first_word_id': '1',
            'last_word_id': '1',
            'surah_number': null,
          },
        ],
        words: [word(id: 1, line: 2)],
      );

      expect(page.lines[0].isCentered, isTrue);
      expect(page.lines[0].surahNumber, 1);
      expect(page.lines[0].words, isEmpty);
      expect(page.lines[1].words.map((w) => w.id), [1]);
    });

    test('firstWord ignore les lignes sans mot', () {
      final page = buildMushafPage(
        pageNumber: 1,
        lineRows: [
          lineRow(line: 1, type: 'surah_name', centered: 1, surah: 2),
          lineRow(line: 2, first: 7, last: 7),
        ],
        words: [word(id: 7, line: 2, surah: 2, ayah: 5)],
      );

      expect(page.firstWord?.id, 7);
      expect(page.firstWord?.ayahKey, '2:5');
      expect(page.surahNumbers, containsAll(<int>[2]));
    });
  });

  group('MushafPack', () {
    test('lit une entree de catalogue et formate la taille', () {
      final pack = MushafPack.fromJson({
        'id': 'madinah-1421-v2',
        'name': 'Medine (1421H)',
        'riwaya': 'hafs',
        'version': 2,
        'bytes': 230686720,
        'sha256': 'ABCDEF',
        'url': 'https://example.org/p.zip',
      });

      expect(pack.riwaya, Riwaya.hafs);
      expect(pack.linesPerPage, 15);
      expect(pack.sha256, 'abcdef');
      expect(pack.isDownloadable, isTrue);
      expect(pack.readableSize, '~220 Mo');
    });

    test('une entree sans url n\'est pas telechargeable', () {
      final pack = MushafPack.fromJson({
        'id': 'x',
        'name': 'X',
        'riwaya': 'inconnu',
        'version': 1,
      });

      expect(pack.riwaya, Riwaya.other);
      expect(pack.isDownloadable, isFalse);
      expect(pack.readableSize, isEmpty);
    });
  });
}
