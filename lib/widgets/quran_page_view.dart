import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/surah.dart';
import '../services/quran_service.dart';
import '../theme/app_theme.dart';

/// Displays a surah in traditional Mushaf page layout.
/// Verses flow as continuous Arabic text, grouped by page.
class QuranPageView extends StatefulWidget {
  final Surah surah;
  final int? currentPlayingAyahId;
  final int? initialPage;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onAyahTap;

  const QuranPageView({
    super.key,
    required this.surah,
    this.currentPlayingAyahId,
    this.initialPage,
    this.onPageChanged,
    this.onAyahTap,
  });

  @override
  State<QuranPageView> createState() => _QuranPageViewState();
}

class _QuranPageViewState extends State<QuranPageView> {
  late PageController _pageController;
  List<int> _surahPages = [];
  Map<int, List<Ayah>> _pageVerses = {};
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _buildPageData();
  }

  void _buildPageData() {
    // Group verses by page number
    final Map<int, List<Ayah>> grouped = {};
    for (final ayah in widget.surah.verses) {
      final page = ayah.pageNumber;
      if (page == null) continue;
      grouped.putIfAbsent(page, () => []).add(ayah);
    }

    _surahPages = grouped.keys.toList()..sort();
    _pageVerses = grouped;

    // Find initial page index
    int initialIndex = 0;
    if (widget.initialPage != null) {
      initialIndex = _surahPages.indexOf(widget.initialPage!);
      if (initialIndex < 0) initialIndex = 0;
    } else if (widget.currentPlayingAyahId != null) {
      // Find the page containing the playing ayah
      for (int i = 0; i < _surahPages.length; i++) {
        final verses = _pageVerses[_surahPages[i]]!;
        if (verses.any((a) => a.id == widget.currentPlayingAyahId)) {
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

    // Auto-navigate to page of currently playing ayah
    if (widget.currentPlayingAyahId != null &&
        widget.currentPlayingAyahId != oldWidget.currentPlayingAyahId) {
      for (int i = 0; i < _surahPages.length; i++) {
        final verses = _pageVerses[_surahPages[i]]!;
        if (verses.any((a) => a.id == widget.currentPlayingAyahId)) {
          if (i != _currentPageIndex) {
            _pageController.animateToPage(
              i,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_surahPages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _surahPages.length,
            onPageChanged: (index) {
              setState(() => _currentPageIndex = index);
              widget.onPageChanged?.call(_surahPages[index]);
            },
            itemBuilder: (context, index) {
              final pageNumber = _surahPages[index];
              final verses = _pageVerses[pageNumber]!;
              final isFirstPage = index == 0;

              return _MushafPage(
                pageNumber: pageNumber,
                verses: verses,
                surah: widget.surah,
                isFirstPage: isFirstPage,
                currentPlayingAyahId: widget.currentPlayingAyahId,
                isDark: isDark,
                onAyahTap: widget.onAyahTap,
              );
            },
          ),
        ),
        // Page indicator
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 28),
                onPressed: _currentPageIndex > 0
                    ? () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        )
                    : null,
                color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Page ${_surahPages[_currentPageIndex]}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 28),
                onPressed: _currentPageIndex < _surahPages.length - 1
                    ? () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        )
                    : null,
                color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single Mushaf page with flowing Arabic text
class _MushafPage extends StatelessWidget {
  final int pageNumber;
  final List<Ayah> verses;
  final Surah surah;
  final bool isFirstPage;
  final int? currentPlayingAyahId;
  final bool isDark;
  final ValueChanged<int>? onAyahTap;

  const _MushafPage({
    required this.pageNumber,
    required this.verses,
    required this.surah,
    required this.isFirstPage,
    this.currentPlayingAyahId,
    required this.isDark,
    this.onAyahTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          // Surah header on first page
          if (isFirstPage) ...[
            _SurahHeader(surah: surah, isDark: isDark),
            const SizedBox(height: 16),
          ],
          // Flowing Arabic text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isDark ? AppColors.divider : AppColors.dividerLight)
                    .withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: RichText(
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              text: TextSpan(
                children: _buildVerseSpans(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _buildVerseSpans(BuildContext context) {
    final spans = <InlineSpan>[];

    for (final ayah in verses) {
      final isPlaying = ayah.id == currentPlayingAyahId;

      // Verse text
      spans.add(
        WidgetSpan(
          child: GestureDetector(
            onTap: () => onAyahTap?.call(ayah.id),
            child: Container(
              padding: isPlaying
                  ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                  : null,
              decoration: isPlaying
                  ? BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              child: Text(
                ayah.text,
                style: TextStyle(
                  fontFamily: 'Scheherazade',
                  fontSize: 24,
                  height: 2.2,
                  color: isPlaying
                      ? (isDark ? AppColors.accentLight : AppColors.primary)
                      : (isDark ? AppColors.textArabic : Colors.black87),
                ),
              ),
            ),
          ),
        ),
      );

      // Verse number marker (end sign)
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () => onAyahTap?.call(ayah.id),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPlaying
                    ? AppColors.accent.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.1),
                border: Border.all(
                  color: isPlaying ? AppColors.accent : AppColors.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  '${ayah.id}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPlaying ? AppColors.accent : AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Space between verses
      spans.add(const TextSpan(text: ' '));
    }

    return spans;
  }
}

class _SurahHeader extends StatelessWidget {
  final Surah surah;
  final bool isDark;

  const _SurahHeader({required this.surah, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            surah.name,
            style: const TextStyle(
              fontFamily: 'Scheherazade',
              fontSize: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            surah.transliteration,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          // Bismillah (except for At-Tawbah)
          if (surah.id != 9)
            Text(
              'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
              style: TextStyle(
                fontFamily: 'Scheherazade',
                fontSize: 20,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
        ],
      ),
    );
  }
}
