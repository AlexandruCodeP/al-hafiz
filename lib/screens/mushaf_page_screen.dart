import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/mushaf.dart';
import '../services/audio_service.dart';
import '../services/mushaf_service.dart';
import '../services/qcf_font_service.dart';
import '../theme/app_theme.dart';

/// Mushaf page screen (Étape 3 — design + swipe + QCF).
///
/// Full-screen PageView with swipe navigation, QCF calligraphic fonts,
/// decorative borders, and audio-synchronized ayah highlighting.
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
    // PageView index 0 = page 1. Reversed for RTL swipe.
    _pageController = PageController(initialPage: _currentPage - 1);

    // Prefetch data + fonts for initial pages.
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
      backgroundColor: isDark ? AppColors.background : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Page $_currentPage'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Page area (swipe) ──
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              reverse: true, // RTL: swipe left = next page
              itemCount: 604,
              onPageChanged: (index) {
                final page = index + 1;
                setState(() => _currentPage = page);
                // Prefetch ahead.
                final next = List.generate(3, (i) => page + i + 1)
                    .where((p) => p <= 604)
                    .toList();
                MushafService.instance.prefetch(next);
                QcfFontService.instance.prefetch(next);
              },
              itemBuilder: (_, index) {
                final pageNum = index + 1;
                return _MushafPageWidget(
                  key: ValueKey(pageNum),
                  pageNumber: pageNum,
                );
              },
            ),
          ),

          // ── Page number bar ──
          _PageBar(
            currentPage: _currentPage,
            onPageTap: (page) {
              _pageController.animateToPage(
                page - 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MushafPageWidget — a single mushaf page (loads data + font, renders)
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
  bool _error = false;

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
      _error = _data == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.primary,
        ),
      );
    }

    if (_error || _data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text('Impossible de charger la page ${widget.pageNumber}'),
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

    return _MushafPageContent(
      data: _data!,
      fontReady: _fontReady,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MushafPageContent — renders page lines inside a decorative frame
// ─────────────────────────────────────────────────────────────────────────────

class _MushafPageContent extends StatelessWidget {
  final MushafPage data;
  final bool fontReady;

  const _MushafPageContent({required this.data, required this.fontReady});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outerBorder = isDark ? const Color(0xFF6B5A3E) : const Color(0xFFB8956A);
    final innerBorder = isDark ? const Color(0xFF4A3F2E) : const Color(0xFFD4B896);
    final pageBg = isDark ? const Color(0xFF1E1A14) : const Color(0xFFFFFBF5);

    return Consumer<AudioService>(
      builder: (context, audio, _) {
        final activeSurah = audio.currentSurahId;
        final activeAyah = audio.currentAyahId;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: pageBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: outerBorder, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
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
                  // ── Lines ──
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: _buildLines(
                        context, audio, activeSurah, activeAyah, isDark),
                    ),
                  ),

                  // ── Page number ──
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLines(
    BuildContext context,
    AudioService audio,
    int? activeSurah,
    int? activeAyah,
    bool isDark,
  ) {
    final maxLine =
        data.lines.isEmpty ? 1 : data.lines.last.lineNumber;

    return LayoutBuilder(
      builder: (context, constraints) {
        final lineHeight = constraints.maxHeight / maxLine;
        // QCF font size scales with line height.
        final qcfFontSize = lineHeight * 1.1;
        final fontFamily = fontReady
            ? QcfFontService.instance.fontFamily(data.pageNumber)
            : null;

        return Column(
          children: [
            for (int ln = 1; ln <= maxLine; ln++)
              SizedBox(
                height: lineHeight,
                child: _buildLine(
                  context,
                  _tokensForLine(ln),
                  audio,
                  activeSurah,
                  activeAyah,
                  isDark,
                  fontFamily,
                  qcfFontSize,
                ),
              ),
          ],
        );
      },
    );
  }

  List<MushafToken> _tokensForLine(int lineNumber) {
    for (final line in data.lines) {
      if (line.lineNumber == lineNumber) return line.tokens;
    }
    return const [];
  }

  Widget _buildLine(
    BuildContext context,
    List<MushafToken> tokens,
    AudioService audio,
    int? activeSurah,
    int? activeAyah,
    bool isDark,
    String? fontFamily,
    double qcfFontSize,
  ) {
    if (tokens.isEmpty) return const SizedBox.expand();

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisSize: MainAxisSize.min,
        children: tokens
            .map((t) => _buildToken(
                  context, t, audio, activeSurah, activeAyah,
                  isDark, fontFamily, qcfFontSize))
            .toList(),
      ),
    );
  }

  Widget _buildToken(
    BuildContext context,
    MushafToken token,
    AudioService audio,
    int? activeSurah,
    int? activeAyah,
    bool isDark,
    String? fontFamily,
    double qcfFontSize,
  ) {
    final isActive = token.surah == activeSurah && token.ayah == activeAyah;

    // Use QCF glyph if font is ready, otherwise fallback to Uthmani text.
    final useQcf = fontFamily != null && token.codeV2.isNotEmpty;
    final displayText = useQcf ? token.codeV2 : token.text;
    final textStyle = useQcf
        ? TextStyle(
            fontFamily: fontFamily,
            fontSize: qcfFontSize,
            height: 1.0,
            color: isActive
                ? (isDark ? AppColors.accentLight : const Color(0xFF6B4F2E))
                : (isDark ? const Color(0xFFE8DFD1) : const Color(0xFF1C1206)),
          )
        : TextStyle(
            fontFamily: 'Scheherazade',
            fontSize: 22,
            height: 1.8,
            color: isActive
                ? (isDark ? AppColors.accentLight : const Color(0xFF6B4F2E))
                : (isDark ? AppColors.textArabic : const Color(0xFF2C1F0E)),
          );

    final highlightColor = isDark
        ? AppColors.accent.withValues(alpha: 0.18)
        : AppColors.primary.withValues(alpha: 0.12);

    return GestureDetector(
      onTap: () {
        // Find max ayah for this surah on this page (for continuous reading).
        int maxAyah = 0;
        for (final line in data.lines) {
          for (final t in line.tokens) {
            if (t.surah == token.surah && t.ayah > maxAyah) {
              maxAyah = t.ayah;
            }
          }
        }
        audio.playAyah(token.surah, token.ayah, maxAyah);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: isActive ? highlightColor : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          displayText,
          textDirection: TextDirection.rtl,
          style: textStyle,
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
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(_PageBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPage != oldWidget.currentPage) {
      _scrollToCurrentPage();
    }
  }

  void _scrollToCurrentPage() {
    const chipWidth = 54.0;
    final offset = ((widget.currentPage - 1) * chipWidth) - 120;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: 604,
        itemBuilder: (_, i) {
          final page = i + 1;
          final selected = page == widget.currentPage;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => widget.onPageTap(page),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : isDark
                          ? AppColors.surfaceLight
                          : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : isDark
                            ? AppColors.divider
                            : AppColors.dividerLight,
                    width: selected ? 1.5 : 0.5,
                  ),
                ),
                child: Text(
                  '$page',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
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
