import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/surah.dart';
import '../services/mushaf_data_service.dart';
import '../services/word_timing_service.dart';
import '../theme/app_theme.dart';

/// Displays a surah in authentic Mushaf page layout.
///
/// Hybrid approach: loads Mushaf page images from CDN with an interactive
/// overlay for verse tapping and audio highlighting. Falls back to
/// text-based rendering if the image fails to load.
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
// _MushafPage — hybrid: Mushaf image + interactive overlay
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
  bool _useTextFallback = false;

  // ── Image CDN ──
  static const _imageBaseUrl =
      'https://www.mp3quran.net/api/quran_pages_arabic';

  // ── Layout constants for overlay alignment ──
  // These ratios define where the text content sits within the Mushaf image.
  // Tuned for mp3quran.net Madani Mushaf images.
  static const _linesPerPage = 15;
  static const _contentTopRatio = 0.088;
  static const _contentBottomRatio = 0.925;
  static const _contentLeftRatio = 0.065;
  static const _contentRightRatio = 0.935;

  // Mushaf page aspect ratio (width / height)
  static const _pageAspectRatio = 0.637;

  @override
  bool get wantKeepAlive => true;

  String get _imageUrl {
    final padded = widget.pageNumber.toString().padLeft(3, '0');
    return '$_imageBaseUrl/$padded.png';
  }

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
  static const _lineHL = Color(0x2ABE8C3C); // warm gold, 16%
  static const _lineHLDark = Color(0x30D4AF37); // bright gold, 19%
  static const _verseHL = Color(0x183B82F6);
  static const _wordHL = Color(0x403B82F6);
  static const _wordHLDark = Color(0x503B82F6);

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // If image failed previously, use text-based rendering
    if (_useTextFallback) {
      if (_error || _data == null) return _fallbackPage();
      return _buildTextPage();
    }

    return _buildHybridPage();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HYBRID MODE — Mushaf image + interactive overlay
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHybridPage() {
    final bgColor = widget.isDark
        ? AppColors.surface
        : const Color(0xFFFFFBF5);

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Center(
        child: AspectRatio(
          aspectRatio: _pageAspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Layer 1: Mushaf page image ──
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: widget.isDark
                    ? ColorFiltered(
                        colorFilter: const ColorFilter.matrix(<double>[
                          -0.8, 0, 0, 0, 200, // invert & soften red
                          0, -0.75, 0, 0, 185, // invert & soften green
                          0, 0, -0.7, 0, 170,  // invert & warm blue
                          0, 0, 0, 1, 0,        // keep alpha
                        ]),
                        child: _buildImage(),
                      )
                    : _buildImage(),
              ),

              // ── Layer 2: Interactive overlay ──
              if (_data != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _buildInteractiveOverlay(),
                ),

              // ── Layer 3: Page number pill ──
              Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.black.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.pageNumber}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark
                            ? AppColors.textSecondary
                            : const Color(0xFF8C7A5E),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    return Image.network(
      _imageUrl,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        final progress = loadingProgress.expectedTotalBytes != null
            ? loadingProgress.cumulativeBytesLoaded /
                loadingProgress.expectedTotalBytes!
            : null;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
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
      },
      errorBuilder: (_, __, ___) {
        // Switch to text fallback on image error
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _useTextFallback = true);
        });
        return const SizedBox();
      },
    );
  }

  /// Builds the transparent interactive overlay with line-based tap zones.
  Widget _buildInteractiveOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final contentTop = h * _contentTopRatio;
        final contentHeight = h * (_contentBottomRatio - _contentTopRatio);
        final contentLeft = w * _contentLeftRatio;
        final contentWidth = w * (_contentRightRatio - _contentLeftRatio);
        final lineHeight = contentHeight / _linesPerPage;

        return Stack(
          children: [
            for (int ln = 1; ln <= _linesPerPage; ln++)
              Positioned(
                top: contentTop + (ln - 1) * lineHeight,
                left: contentLeft,
                width: contentWidth,
                height: lineHeight,
                child: _buildLineOverlay(ln),
              ),
          ],
        );
      },
    );
  }

  /// A single line zone: transparent when idle, highlighted when active.
  Widget _buildLineOverlay(int lineNum) {
    final words = _data!.lines[lineNum] ?? [];
    if (words.isEmpty) return const SizedBox.shrink();

    // Check if this line contains the currently playing verse
    final playingWords = words.where((w) =>
        w.verseNumber == widget.currentPlayingAyahId &&
        w.surahNumber == widget.surah.id);
    final isPlayingLine = playingWords.isNotEmpty;

    // Find the first "real" verse on this line for tap target
    final tapVerse = words
        .firstWhere((w) => !w.isEnd,
            orElse: () => words.first)
        .verseNumber;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onAyahTap?.call(tapVerse),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isPlayingLine
              ? (widget.isDark ? _lineHLDark : _lineHL)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: isPlayingLine
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 0.5,
                )
              : null,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TEXT FALLBACK — used when image fails to load
  // ─────────────────────────────────────────────────────────────────────────

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

  /// Text-based Mushaf rendering (fallback when image CDN is unavailable).
  Widget _buildTextPage() {
    final lines = _data!.lines;
    final allLineNums = lines.keys.toList()..sort();
    final maxLine = allLineNums.isEmpty ? 1 : allLineNums.last;
    final firstLine = allLineNums.isEmpty ? 1 : allLineNums.first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark
              ? AppColors.surface
              : const Color(0xFFFFFBF5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isDark
                ? AppColors.divider.withValues(alpha: 0.3)
                : const Color(0xFFD5C4A1).withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: widget.isDark ? 0.12 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
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
                            child: _buildLine(lines[ln] ?? []),
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

  Widget _buildLine(List<MushafWord> words) {
    if (words.isEmpty) return const SizedBox.expand();

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

  static String _toArabicNumeral(int n) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => digits[int.parse(c)]).join();
  }
}
