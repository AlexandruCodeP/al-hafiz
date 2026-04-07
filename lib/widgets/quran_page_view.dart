import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/surah.dart';
import '../services/mushaf_data_service.dart';
import '../services/word_timing_service.dart';
import '../theme/app_theme.dart';

/// Displays a surah in authentic Mushaf page layout.
///
/// Each page is fetched from the Quran.com API, rendering word-by-word
/// in 15-line pages with justified text, decorative borders, and
/// real-time word-level audio highlighting.
class QuranPageView extends StatefulWidget {
  final Surah surah;
  final int? currentPlayingAyahId;
  final int? currentWordIndex;
  final int? initialPage;
  final Map<int, VerseTimings>? wordTimings;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onAyahTap;

  const QuranPageView({
    super.key,
    required this.surah,
    this.currentPlayingAyahId,
    this.currentWordIndex,
    this.initialPage,
    this.wordTimings,
    this.onPageChanged,
    this.onAyahTap,
  });

  @override
  State<QuranPageView> createState() => _QuranPageViewState();
}

class _QuranPageViewState extends State<QuranPageView> {
  late PageController _pageController;
  List<int> _surahPages = [];
  int _currentPageIndex = 0;
  final ScrollController _scrollBarController = ScrollController();

  @override
  void initState() {
    super.initState();
    _buildPageList();
    // Prefetch a few pages ahead
    MushafDataService.instance.prefetch(_surahPages.take(5).toList());
  }

  void _buildPageList() {
    final pages = <int>{};
    for (final a in widget.surah.verses) {
      if (a.pageNumber != null) pages.add(a.pageNumber!);
    }
    _surahPages = pages.toList()..sort();

    int initialIndex = 0;
    if (widget.initialPage != null) {
      initialIndex = _surahPages.indexOf(widget.initialPage!);
      if (initialIndex < 0) initialIndex = 0;
    } else if (widget.currentPlayingAyahId != null) {
      for (int i = 0; i < _surahPages.length; i++) {
        final p = _surahPages[i];
        if (widget.surah.verses
            .any((a) => a.pageNumber == p && a.id == widget.currentPlayingAyahId)) {
          initialIndex = i;
          break;
        }
      }
    }

    _currentPageIndex = initialIndex;
    _pageController = PageController(initialPage: initialIndex);
  }

  @override
  void didUpdateWidget(QuranPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPlayingAyahId != null &&
        widget.currentPlayingAyahId != oldWidget.currentPlayingAyahId) {
      for (int i = 0; i < _surahPages.length; i++) {
        if (widget.surah.verses.any((a) =>
            a.pageNumber == _surahPages[i] &&
            a.id == widget.currentPlayingAyahId)) {
          if (i != _currentPageIndex) {
            _pageController.animateToPage(i,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut);
          }
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollBarController.dispose();
    super.dispose();
  }

  void _scrollToChip() {
    const w = 54.0;
    final offset = (_currentPageIndex * w) - 120;
    if (_scrollBarController.hasClients) {
      _scrollBarController.animateTo(
        offset.clamp(0.0, _scrollBarController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_surahPages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // ── Page area ──
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _surahPages.length,
            onPageChanged: (i) {
              setState(() => _currentPageIndex = i);
              widget.onPageChanged?.call(_surahPages[i]);
              // Prefetch next pages
              final next = _surahPages.skip(i + 1).take(3).toList();
              MushafDataService.instance.prefetch(next);
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToChip());
            },
            itemBuilder: (_, i) {
              return _MushafPage(
                pageNumber: _surahPages[i],
                surah: widget.surah,
                isFirstPage: i == 0,
                currentPlayingAyahId: widget.currentPlayingAyahId,
                currentWordIndex: widget.currentWordIndex,
                isDark: isDark,
                onAyahTap: widget.onAyahTap,
              );
            },
          ),
        ),

        // ── Page number bar ──
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : Colors.grey[50],
            border: Border(
              top: BorderSide(
                color: (isDark ? AppColors.divider : AppColors.dividerLight)
                    .withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          child: ListView.builder(
            controller: _scrollBarController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            itemCount: _surahPages.length,
            itemBuilder: (_, i) {
              final num = _surahPages[i];
              final sel = i == _currentPageIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () => _pageController.animateToPage(i,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.primary
                          : isDark
                              ? AppColors.surfaceLight
                              : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel
                            ? AppColors.primary
                            : isDark
                                ? AppColors.divider
                                : AppColors.dividerLight,
                        width: sel ? 1.5 : 0.5,
                      ),
                    ),
                    child: Text(
                      '$num',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel
                            ? Colors.white
                            : isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MushafPage — a single Mushaf page with line-based layout
// ─────────────────────────────────────────────────────────────────────────────

class _MushafPage extends StatefulWidget {
  final int pageNumber;
  final Surah surah;
  final bool isFirstPage;
  final int? currentPlayingAyahId;
  final int? currentWordIndex;
  final bool isDark;
  final ValueChanged<int>? onAyahTap;

  const _MushafPage({
    required this.pageNumber,
    required this.surah,
    required this.isFirstPage,
    this.currentPlayingAyahId,
    this.currentWordIndex,
    required this.isDark,
    this.onAyahTap,
  });

  @override
  State<_MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<_MushafPage>
    with AutomaticKeepAliveClientMixin {
  MushafPageData? _data;
  bool _loading = true;
  bool _error = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await MushafDataService.instance.getPage(widget.pageNumber);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
      _error = data == null;
    });
  }

  // ── Highlight colours ──
  static const _verseHL = Color(0x183B82F6); // 10 % blue
  static const _wordHL = Color(0x403B82F6); // 25 % blue
  static const _wordHLDark = Color(0x503B82F6); // 31 % blue (dark mode)

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_error || _data == null) {
      return _fallbackPage();
    }

    return _buildMushafPage();
  }

  /// Fallback: simple text rendering if API fails.
  Widget _fallbackPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          widget.surah.verses
              .where((a) => a.pageNumber == widget.pageNumber)
              .map((a) => a.text)
              .join(' '),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontFamily: 'Scheherazade',
            fontSize: 24,
            height: 2.0,
          ),
        ),
      ),
    );
  }

  Widget _buildMushafPage() {
    final lines = _data!.lines;
    final allLineNums = lines.keys.toList()..sort();
    final maxLine = allLineNums.isEmpty ? 1 : allLineNums.last;
    // Detect surah header lines (lines before first content line)
    final firstLine = allLineNums.isEmpty ? 1 : allLineNums.first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark
              ? AppColors.surface
              : const Color(0xFFFFFBF5), // warm cream
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isDark
                ? AppColors.divider.withValues(alpha: 0.3)
                : const Color(0xFFD5C4A1).withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDark ? 0.12 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Inner decorative border ──
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: widget.isDark
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : const Color(0xFFD4A574).withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final lineHeight = constraints.maxHeight / maxLine;

                    return Column(
                      children: [
                        // Surah header (if content starts after line 1)
                        if (widget.isFirstPage || firstLine > 1)
                          _surahHeader(lineHeight, firstLine - 1),

                        // ── Content lines ──
                        for (int ln = firstLine; ln <= maxLine; ln++)
                          SizedBox(
                            height: lineHeight,
                            child: _buildLine(lines[ln] ?? []),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // ── Page number ──
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${widget.pageNumber}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: widget.isDark
                      ? AppColors.textSecondary
                      : const Color(0xFF8C7A5E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Decorative surah header (name + bismillah).
  Widget _surahHeader(double lineHeight, int headerLines) {
    if (headerLines <= 0) headerLines = 1;
    final surah = widget.surah;
    final showBismillah = surah.id != 9; // no bismillah for At-Tawbah

    return SizedBox(
      height: lineHeight * headerLines,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isDark
                  ? [
                      AppColors.accent.withValues(alpha: 0.08),
                      AppColors.accent.withValues(alpha: 0.02),
                    ]
                  : [
                      const Color(0xFFF5ECD7),
                      const Color(0xFFFFF8EE),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isDark
                  ? AppColors.accent.withValues(alpha: 0.2)
                  : const Color(0xFFD4A574).withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'سُورَةُ ${surah.name.replaceAll('سُورَةُ ', '').replaceAll('سورة ', '')}',
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark
                      ? AppColors.accent
                      : const Color(0xFF6B4F2E),
                ),
              ),
              if (showBismillah && headerLines >= 2) ...[
                const SizedBox(height: 2),
                Text(
                  'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                  style: TextStyle(
                    fontFamily: 'Scheherazade',
                    fontSize: 16,
                    color: widget.isDark
                        ? AppColors.textArabic
                        : const Color(0xFF3D2B14),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build a single line of Mushaf text (one Row of word widgets, RTL).
  Widget _buildLine(List<MushafWord> words) {
    if (words.isEmpty) return const SizedBox.expand();

    // Short lines (≤3 items) are centered; full lines are justified
    final isPartial = words.length <= 3;

    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment:
          isPartial ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
      children: words.map((w) => _buildWord(w)).toList(),
    );
  }

  Widget _buildWord(MushafWord word) {
    final isPlayingVerse =
        word.verseNumber == widget.currentPlayingAyahId &&
            word.surahNumber == widget.surah.id;
    final isActiveWord = isPlayingVerse &&
        !word.isEnd &&
        word.wordIndex == widget.currentWordIndex;

    Color? bg;
    if (isActiveWord) {
      bg = widget.isDark ? _wordHLDark : _wordHL;
    } else if (isPlayingVerse) {
      bg = _verseHL;
    }

    // Verse-end marker (number ornament)
    if (word.isEnd) {
      return GestureDetector(
        onTap: () => widget.onAyahTap?.call(word.verseNumber),
        child: Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isPlayingVerse
                ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                : AppColors.primary.withValues(alpha: 0.08),
            border: Border.all(
              color: isPlayingVerse
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
                  : AppColors.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              _toArabicNumeral(word.verseNumber),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isPlayingVerse
                    ? const Color(0xFF3B82F6)
                    : AppColors.primary,
              ),
            ),
          ),
        ),
      );
    }

    // Regular word
    return Flexible(
      child: GestureDetector(
        onTap: () => widget.onAyahTap?.call(word.verseNumber),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            word.text,
            textDirection: TextDirection.rtl,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontFamily: 'Scheherazade',
              fontSize: 22,
              height: 1.6,
              color: isActiveWord
                  ? (widget.isDark
                      ? Colors.white
                      : const Color(0xFF1A3A5C))
                  : (widget.isDark
                      ? AppColors.textArabic
                      : const Color(0xFF2C1F0E)),
            ),
          ),
        ),
      ),
    );
  }

  /// Convert an integer to Eastern Arabic numerals (٠١٢٣٤٥٦٧٨٩).
  static String _toArabicNumeral(int n) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => digits[int.parse(c)]).join();
  }
}
