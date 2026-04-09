import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/mushaf.dart';
import '../services/audio_service.dart';
import '../services/mushaf_service.dart';
import '../services/qcf_font_service.dart';
import '../theme/app_theme.dart';

/// Mushaf page screen — swipable pages with QCF calligraphic rendering.
///
/// Architecture:
/// - Rendering is pure presentation: one [Text] widget per line using
///   the concatenated QCF string. No Row-of-tokens, no FittedBox.
/// - Interaction (tap-to-play, highlight) is a logical overlay based
///   on the line's ayah range, without breaking the typography.
class MushafPageScreen extends StatefulWidget {
  final int initialPage;

  const MushafPageScreen({super.key, this.initialPage = 1});

  @override
  State<MushafPageScreen> createState() => _MushafPageScreenState();
}

class _MushafPageScreenState extends State<MushafPageScreen> {
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: _currentPage - 1);

    final pages = List.generate(5, (i) => _currentPage + i)
        .where((p) => p >= 1 && p <= 604)
        .toList();
    MushafService.instance.prefetch(pages);
    QcfFontService.instance.prefetch(pages);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.background : AppColors.backgroundLight,
      appBar: AppBar(title: Text('Page $_currentPage')),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              reverse: true, // RTL swipe
              itemCount: 604,
              onPageChanged: (i) {
                final page = i + 1;
                setState(() => _currentPage = page);
                final next = List.generate(3, (j) => page + j + 1)
                    .where((p) => p <= 604)
                    .toList();
                MushafService.instance.prefetch(next);
                QcfFontService.instance.prefetch(next);
              },
              itemBuilder: (_, i) => _MushafPageWidget(
                key: ValueKey(i + 1),
                pageNumber: i + 1,
              ),
            ),
          ),
          _PageBar(
            currentPage: _currentPage,
            onPageTap: (p) => _pageController.animateToPage(
              p - 1,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MushafPageWidget — loads data + font, then delegates to _MushafPageContent
// ─────────────────────────────────────────────────────────────────────────────

class _MushafPageWidget extends StatefulWidget {
  final int pageNumber;
  const _MushafPageWidget({super.key, required this.pageNumber});

  @override
  State<_MushafPageWidget> createState() => _MushafPageWidgetState();
}

class _MushafPageWidgetState extends State<_MushafPageWidget>
    with AutomaticKeepAliveClientMixin {
  MushafPage? _data;
  bool _loading = true;
  bool _fontReady = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      MushafService.instance.getPage(widget.pageNumber),
      QcfFontService.instance.loadFont(widget.pageNumber),
    ]);
    if (!mounted) return;
    setState(() {
      _data = results[0] as MushafPage?;
      _fontReady = results[1] as bool;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
      );
    }

    if (_data == null || !_fontReady) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text('Page ${widget.pageNumber} — échec du chargement'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() => _loading = true);
                _loadAll();
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return _MushafPageContent(data: _data!);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MushafPageContent — pure presentation + interaction overlay
// ─────────────────────────────────────────────────────────────────────────────

class _MushafPageContent extends StatelessWidget {
  final MushafPage data;
  const _MushafPageContent({required this.data});

  // ── Page geometry ──
  static const _pageAspect = 3.0 / 4.0; // width / height
  static const _marginH = 0.08; // horizontal margin as fraction of width
  static const _marginTop = 0.06; // top margin as fraction of height
  static const _marginBottom = 0.05; // bottom margin as fraction of height
  static const _linesPerPage = 15;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outerBorder =
        isDark ? const Color(0xFF6B5A3E) : const Color(0xFFB8956A);
    final innerBorder =
        isDark ? const Color(0xFF4A3F2E) : const Color(0xFFD4B896);
    final pageBg = isDark ? const Color(0xFF1E1A14) : const Color(0xFFFFFBF5);

    return Center(
      child: AspectRatio(
        aspectRatio: _pageAspect,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: pageBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: outerBorder, width: 2),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              border:
                  Border.all(color: innerBorder.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _buildPage(context, constraints, isDark);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(
      BuildContext context, BoxConstraints constraints, bool isDark) {
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;
    final padH = w * _marginH;
    final padTop = h * _marginTop;
    final padBottom = h * _marginBottom;
    final contentH = h - padTop - padBottom;
    final lineHeight = contentH / _linesPerPage;

    final fontFamily =
        QcfFontService.instance.fontFamily(data.pageNumber);

    // Calibrated font size: QCF glyphs are designed for ~28px at 15 lines.
    // Scale relative to the available line height.
    final fontSize = lineHeight * 0.95;

    final textColor =
        isDark ? const Color(0xFFE8DFD1) : const Color(0xFF1C1206);

    return Consumer<AudioService>(
      builder: (context, audio, _) {
        final activeSurah = audio.currentSurahId;
        final activeAyah = audio.currentAyahId;

        return Padding(
          padding: EdgeInsets.fromLTRB(padH, padTop, padH, 0),
          child: Column(
            children: [
              // ── Lines ──
              for (int ln = 1; ln <= _linesPerPage; ln++)
                SizedBox(
                  height: lineHeight,
                  child: _buildLineWidget(
                    _lineFor(ln),
                    fontFamily,
                    fontSize,
                    textColor,
                    isDark,
                    audio,
                    activeSurah,
                    activeAyah,
                  ),
                ),

              // ── Page number ──
              Expanded(
                child: Center(
                  child: Text(
                    '${data.pageNumber}',
                    style: GoogleFonts.amiri(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondary
                          : const Color(0xFF8C7A5E),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Find the MushafLine for a given line number, or null.
  MushafLine? _lineFor(int lineNumber) {
    for (final line in data.lines) {
      if (line.lineNumber == lineNumber) return line;
    }
    return null;
  }

  /// Renders a single line: pure QCF text + tap overlay.
  Widget _buildLineWidget(
    MushafLine? line,
    String fontFamily,
    double fontSize,
    Color textColor,
    bool isDark,
    AudioService audio,
    int? activeSurah,
    int? activeAyah,
  ) {
    // Empty line (e.g. blank space above surah header).
    if (line == null || line.isEmpty) return const SizedBox.expand();

    // Is this line currently playing?
    final isActive = activeSurah != null &&
        activeAyah != null &&
        line.containsAyah(activeSurah, activeAyah);

    final highlightColor = isDark
        ? AppColors.accent.withValues(alpha: 0.15)
        : AppColors.primary.withValues(alpha: 0.10);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Play the first ayah on this line.
        if (line.ayahs.isNotEmpty) {
          final first = line.ayahs.first;
          audio.playAyah(first.surah, first.ayah);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isActive ? highlightColor : null,
          borderRadius: BorderRadius.circular(3),
        ),
        alignment: Alignment.center,
        child: Text(
          line.textQcf,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSize,
            height: 1.0,
            color: isActive
                ? (isDark
                    ? AppColors.accentLight
                    : const Color(0xFF6B4F2E))
                : textColor,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PageBar — horizontal scrollable page number strip
// ─────────────────────────────────────────────────────────────────────────────

class _PageBar extends StatefulWidget {
  final int currentPage;
  final ValueChanged<int> onPageTap;
  const _PageBar({required this.currentPage, required this.onPageTap});

  @override
  State<_PageBar> createState() => _PageBarState();
}

class _PageBarState extends State<_PageBar> {
  final ScrollController _sc = ScrollController();

  @override
  void didUpdateWidget(_PageBar old) {
    super.didUpdateWidget(old);
    if (widget.currentPage != old.currentPage) _scrollTo();
  }

  void _scrollTo() {
    const cw = 54.0;
    final off = ((widget.currentPage - 1) * cw) - 120;
    if (_sc.hasClients) {
      _sc.animateTo(off.clamp(0.0, _sc.position.maxScrollExtent),
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
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
        controller: _sc,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: 604,
        itemBuilder: (_, i) {
          final page = i + 1;
          final sel = page == widget.currentPage;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => widget.onPageTap(page),
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
                  '$page',
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
    );
  }
}
