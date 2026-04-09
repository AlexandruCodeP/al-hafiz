import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/surah.dart';
import '../services/mushaf_data_service.dart';
import '../services/qcf_font_service.dart';
import '../services/word_timing_service.dart';
import '../theme/app_theme.dart';

/// Displays a surah in authentic Mushaf page layout using QCF v2 fonts.
///
/// Each page uses a dedicated calligraphic font from the King Fahd Complex,
/// where each Unicode codepoint maps to a hand-crafted glyph for that
/// word's position on the page. Result: pixel-perfect Mushaf rendering
/// with full word-level interactivity.
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
    // Prefetch data + fonts for upcoming pages
    final upcoming = _surahPages.take(5).toList();
    MushafDataService.instance.prefetch(upcoming);
    QcfFontService.instance.prefetch(upcoming);
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
              // Prefetch next pages (data + fonts)
              final next = _surahPages.skip(i + 1).take(3).toList();
              MushafDataService.instance.prefetch(next);
              QcfFontService.instance.prefetch(next);
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
// _MushafPage — renders a single page using QCF v2 calligraphic fonts
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
  bool _fontReady = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // Load API data and font in parallel
    final results = await Future.wait([
      MushafDataService.instance.getPage(widget.pageNumber),
      QcfFontService.instance.loadFont(widget.pageNumber),
    ]);

    if (!mounted) return;

    final data = results[0] as MushafPageData?;
    final fontOk = results[1] as bool;

    setState(() {
      _data = data;
      _fontReady = fontOk;
      _loading = false;
      _error = data == null;
    });
  }

  // ── Highlight colours ──
  static const _verseHL = Color(0x20BE8C3C); // warm gold 12%
  static const _wordHL = Color(0x40BE8C3C); // warm gold 25%
  static const _wordHLDark = Color(0x50D4AF37); // bright gold 31%
  static const _verseHLDark = Color(0x25D4AF37);

  // ── Decorative border colours ──
  static const _borderOuter = Color(0xFFB8956A);
  static const _borderInner = Color(0xFFD4B896);
  static const _borderOuterDark = Color(0xFF6B5A3E);
  static const _borderInnerDark = Color(0xFF4A3F2E);
  static const _pageBg = Color(0xFFFFFBF5);
  static const _pageBgDark = Color(0xFF1E1A14);

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Page ${widget.pageNumber}',
              style: TextStyle(
                fontSize: 13,
                color: widget.isDark
                    ? AppColors.textSecondary
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    if (_error || _data == null) {
      return _fallbackPage();
    }

    // If font failed to load, fall back to text rendering
    if (!_fontReady) {
      return _buildTextFallback();
    }

    return _buildQcfPage();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QCF RENDERING — calligraphic font-based Mushaf page
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildQcfPage() {
    final outerBorder = widget.isDark ? _borderOuterDark : _borderOuter;
    final innerBorder = widget.isDark ? _borderInnerDark : _borderInner;
    final bgColor = widget.isDark ? _pageBgDark : _pageBg;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: outerBorder, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            border: Border.all(
              color: innerBorder.withValues(alpha: 0.6),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(
            children: [
              // ── Content area ──
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return _buildQcfLines(constraints);
                    },
                  ),
                ),
              ),

              // ── Page number ──
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${widget.pageNumber}',
                  style: GoogleFonts.amiri(
                    fontSize: 13,
                    color: widget.isDark
                        ? AppColors.textSecondary
                        : const Color(0xFF8C7A5E),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQcfLines(BoxConstraints constraints) {
    final lines = _data!.lines;
    final maxLine = _data!.maxLine;
    final lineHeight = constraints.maxHeight / maxLine;
    final fontFamily = QcfFontService.instance.fontFamily(widget.pageNumber);

    // Calculate font size relative to line height
    final fontSize = lineHeight * 1.05;

    return Column(
      children: [
        for (int ln = 1; ln <= maxLine; ln++)
          SizedBox(
            height: lineHeight,
            child: _buildQcfLine(
              lines[ln] ?? [],
              fontFamily,
              fontSize,
            ),
          ),
      ],
    );
  }

  Widget _buildQcfLine(
    List<MushafWord> words,
    String fontFamily,
    double fontSize,
  ) {
    if (words.isEmpty) return const SizedBox.expand();

    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: words.map((w) => _buildQcfWord(w, fontFamily, fontSize)).toList(),
    );
  }

  Widget _buildQcfWord(MushafWord word, String fontFamily, double fontSize) {
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
      bg = widget.isDark ? _verseHLDark : _verseHL;
    }

    final textColor = widget.isDark
        ? const Color(0xFFE8DFD1)
        : const Color(0xFF1C1206);

    return GestureDetector(
      onTap: () => widget.onAyahTap?.call(word.verseNumber),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 0),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          word.codeV2,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSize,
            height: 1.0,
            color: textColor,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TEXT FALLBACK — used when QCF font fails to load
  // ─────────────────────────────────────────────────────────────────────────

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

  Widget _buildTextFallback() {
    final lines = _data!.lines;
    final sortedKeys = lines.keys.toList()..sort();
    final maxLine = sortedKeys.isEmpty ? 1 : sortedKeys.last;
    final firstLine = sortedKeys.isEmpty ? 1 : sortedKeys.first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.surface : const Color(0xFFFFFBF5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isDark
                ? AppColors.divider.withValues(alpha: 0.3)
                : const Color(0xFFD5C4A1).withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          children: [
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
                        if (widget.isFirstPage || firstLine > 1)
                          _surahHeader(lineHeight, firstLine - 1),
                        for (int ln = firstLine; ln <= maxLine; ln++)
                          SizedBox(
                            height: lineHeight,
                            child: _buildTextLine(lines[ln] ?? []),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
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

  Widget _surahHeader(double lineHeight, int headerLines) {
    if (headerLines <= 0) headerLines = 1;
    final surah = widget.surah;
    final showBismillah = surah.id != 9;

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

  Widget _buildTextLine(List<MushafWord> words) {
    if (words.isEmpty) return const SizedBox.expand();
    final isPartial = words.length <= 3;
    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment:
          isPartial ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
      children: words.map((w) => _buildTextWord(w)).toList(),
    );
  }

  Widget _buildTextWord(MushafWord word) {
    final isPlayingVerse =
        word.verseNumber == widget.currentPlayingAyahId &&
            word.surahNumber == widget.surah.id;

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

    return Flexible(
      child: GestureDetector(
        onTap: () => widget.onAyahTap?.call(word.verseNumber),
        child: Text(
          word.text,
          textDirection: TextDirection.rtl,
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontFamily: 'Scheherazade',
            fontSize: 22,
            height: 1.6,
            color: widget.isDark
                ? AppColors.textArabic
                : const Color(0xFF2C1F0E),
          ),
        ),
      ),
    );
  }

  static String _toArabicNumeral(int n) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => digits[int.parse(c)]).join();
  }
}
