/// Standard Madani Mushaf Juz boundaries.
/// Each entry: juz number -> (startSurah, startAyah, startPage)
class JuzData {
  static const List<({int juz, int surahId, int ayahId, int page})> boundaries = [
    (juz: 1,  surahId: 1,  ayahId: 1,   page: 1),
    (juz: 2,  surahId: 2,  ayahId: 142, page: 22),
    (juz: 3,  surahId: 2,  ayahId: 253, page: 42),
    (juz: 4,  surahId: 3,  ayahId: 93,  page: 62),
    (juz: 5,  surahId: 4,  ayahId: 24,  page: 82),
    (juz: 6,  surahId: 4,  ayahId: 148, page: 102),
    (juz: 7,  surahId: 5,  ayahId: 83,  page: 121),
    (juz: 8,  surahId: 6,  ayahId: 111, page: 142),
    (juz: 9,  surahId: 7,  ayahId: 88,  page: 162),
    (juz: 10, surahId: 8,  ayahId: 41,  page: 182),
    (juz: 11, surahId: 9,  ayahId: 93,  page: 201),
    (juz: 12, surahId: 11, ayahId: 6,   page: 222),
    (juz: 13, surahId: 12, ayahId: 53,  page: 242),
    (juz: 14, surahId: 15, ayahId: 1,   page: 262),
    (juz: 15, surahId: 17, ayahId: 1,   page: 282),
    (juz: 16, surahId: 18, ayahId: 75,  page: 302),
    (juz: 17, surahId: 21, ayahId: 1,   page: 322),
    (juz: 18, surahId: 23, ayahId: 1,   page: 342),
    (juz: 19, surahId: 25, ayahId: 21,  page: 362),
    (juz: 20, surahId: 27, ayahId: 56,  page: 382),
    (juz: 21, surahId: 29, ayahId: 46,  page: 402),
    (juz: 22, surahId: 33, ayahId: 31,  page: 422),
    (juz: 23, surahId: 36, ayahId: 28,  page: 442),
    (juz: 24, surahId: 39, ayahId: 32,  page: 462),
    (juz: 25, surahId: 41, ayahId: 47,  page: 482),
    (juz: 26, surahId: 46, ayahId: 1,   page: 502),
    (juz: 27, surahId: 51, ayahId: 31,  page: 522),
    (juz: 28, surahId: 58, ayahId: 1,   page: 542),
    (juz: 29, surahId: 67, ayahId: 1,   page: 562),
    (juz: 30, surahId: 78, ayahId: 1,   page: 582),
  ];

  /// Returns the juz number for a given surah and ayah
  static int getJuz(int surahId, int ayahId) {
    for (int i = boundaries.length - 1; i >= 0; i--) {
      final b = boundaries[i];
      if (surahId > b.surahId || (surahId == b.surahId && ayahId >= b.ayahId)) {
        return b.juz;
      }
    }
    return 1;
  }

  /// Returns the juz number that a surah starts in
  static int getJuzForSurah(int surahId) => getJuz(surahId, 1);

  /// Returns the page number where a juz starts
  static int getJuzStartPage(int juz) {
    return boundaries.firstWhere((b) => b.juz == juz).page;
  }
}
