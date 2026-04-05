import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/surah.dart';
import '../services/audio_service.dart';
import '../services/quran_service.dart';
import '../services/storage_service.dart';
import '../models/juz_data.dart';
import '../theme/app_theme.dart';
import 'reader_screen.dart';
import 'search_screen.dart';

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen>
    with SingleTickerProviderStateMixin {
  List<Surah> _surahs = [];
  List<Surah> _filtered = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  late AnimationController _animController;
  Ayah? _dailyVerse;
  Surah? _dailySurah;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadSurahs();
  }

  Future<void> _loadSurahs() async {
    final surahs = await QuranService.instance.getAllSurahs();

    // Pick a deterministic "daily verse" based on the day
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    final rng = Random(dayOfYear);
    final randomSurahIdx = rng.nextInt(surahs.length);
    final dailySurah = await QuranService.instance.getSurah(surahs[randomSurahIdx].id);
    final randomAyahIdx = rng.nextInt(dailySurah.verses.length);

    setState(() {
      _surahs = surahs;
      _filtered = surahs;
      _isLoading = false;
      _dailySurah = dailySurah;
      _dailyVerse = dailySurah.verses[randomAyahIdx];
    });
    _animController.forward();
  }

  void _filterSurahs(String query) {
    if (query.isEmpty) {
      setState(() => _filtered = _surahs);
    } else {
      setState(() {
        _filtered = QuranService.instance.searchSurahs(query);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  List<Object> _buildSurahListItems() {
    final isSearching = _searchController.text.isNotEmpty;
    final items = <Object>[];
    int lastJuz = 0;

    for (int i = 0; i < _filtered.length; i++) {
      final surah = _filtered[i];
      // Only show juz headers when not searching
      if (!isSearching) {
        final juz = JuzData.getJuzForSurah(surah.id);
        if (juz != lastJuz) {
          items.add(_JuzHeaderItem(juz: juz, page: JuzData.getJuzStartPage(juz)));
          lastJuz = juz;
        }
      }
      items.add(_SurahItem(surah: surah, originalIndex: i));
    }
    return items;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Bonne nuit';
    if (hour < 12) return 'Sabah Al-Khayr';
    if (hour < 18) return 'Masaa Al-Khayr';
    return 'Bonne soiree';
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final audio = context.watch<AudioService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (lastSurahId, lastAyahId) = storage.getLastPosition();
    final playerSurahId = audio.currentSurahId ?? lastSurahId;
    final playerAyahId = audio.currentAyahId ?? lastAyahId ?? 1;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header with greeting + daily verse ──
          SliverToBoxAdapter(
            child: _HeaderSection(
              greeting: _getGreeting(),
              dailyVerse: _dailyVerse,
              dailySurah: _dailySurah,
              isDark: isDark,
              onDailyVerseTap: _dailySurah == null
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReaderScreen(
                            surah: _dailySurah!,
                            initialAyahId: _dailyVerse?.id,
                          ),
                        ),
                      );
                    },
            ),
          ),

          // ── Stats section ──
          if (!_isLoading)
            SliverToBoxAdapter(
              child: _StatsSection(
                totalMastered: storage.totalMasteredAyahs,
                surahsStarted: storage.surahsStarted,
                totalFavorites: storage.getFavorites().length,
                isDark: isDark,
              ),
            ),

          // ── Continue reading (pinned) ──
          if (!_isLoading && playerSurahId != null)
            SliverPersistentHeader(
              pinned: true,
              delegate: _ContinueReadingHeaderDelegate(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: _ContinueReadingCard(
                    surahId: playerSurahId,
                    ayahId: playerAyahId,
                    isPlaying: audio.isPlaying && audio.currentSurahId == playerSurahId,
                    isDark: isDark,
                    onTap: () async {
                      final surah = await QuranService.instance.getSurah(playerSurahId);
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReaderScreen(surah: surah, initialAyahId: playerAyahId),
                          ),
                        );
                      }
                    },
                    onPlayPause: () {
                      if (audio.currentSurahId != null) {
                        audio.togglePlayPause();
                      } else {
                        audio.playAyah(playerSurahId, playerAyahId);
                      }
                    },
                  ),
                ),
              ),
            ),

          // ── Recent surahs ──
          if (!_isLoading)
            SliverToBoxAdapter(
              child: _RecentSurahsSection(
                recentIds: storage.getRecentSurahs(),
                isDark: isDark,
                onTap: (surahId) async {
                  final surah = await QuranService.instance.getSurah(surahId);
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ReaderScreen(surah: surah)),
                    );
                  }
                },
              ),
            ),

          // ── Search bar ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: _SearchBar(
                controller: _searchController,
                onChanged: _filterSurahs,
                isDark: isDark,
              ),
            ),
          ),

          // ── Loading ──
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),
              ),
            ),

          // ── Surah list with Juz separators ──
          if (!_isLoading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // Build a flat list with juz headers interleaved
                    final items = _buildSurahListItems();
                    if (index >= items.length) return const SizedBox.shrink();
                    final item = items[index];

                    if (item is _JuzHeaderItem) {
                      return _JuzHeader(
                        juz: item.juz,
                        page: item.page,
                        isDark: isDark,
                      );
                    }

                    final surahItem = item as _SurahItem;
                    final progress = storage.getSurahProgress(
                        surahItem.surah.id, surahItem.surah.totalVerses);

                    return _SurahTile(
                      surah: surahItem.surah,
                      index: surahItem.originalIndex,
                      progress: progress,
                      animation: _animController,
                      isDark: isDark,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReaderScreen(surah: surahItem.surah),
                          ),
                        );
                      },
                    );
                  },
                  childCount: _buildSurahListItems().length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Header Section
// ─────────────────────────────────────────────
class _HeaderSection extends StatelessWidget {
  final String greeting;
  final Ayah? dailyVerse;
  final Surah? dailySurah;
  final bool isDark;
  final VoidCallback? onDailyVerseTap;

  const _HeaderSection({
    required this.greeting,
    required this.dailyVerse,
    required this.dailySurah,
    required this.isDark,
    this.onDailyVerseTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.primary.withValues(alpha: 0.25),
                  AppColors.background,
                ]
              : [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.backgroundLight,
                ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
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
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                      ),
                    ),
                    Text(
                      'Al-Hafiz',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Daily verse card
          if (dailyVerse != null && dailySurah != null) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onDailyVerseTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF1A2A20), const Color(0xFF0F1F18)]
                        : [const Color(0xFF1B5E4B), const Color(0xFF0D3B2E)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          color: AppColors.accent.withValues(alpha: 0.8),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'VERSET DU JOUR',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${dailySurah!.transliteration} ${dailyVerse!.id}',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      dailyVerse!.text,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: 'Scheherazade',
                        fontSize: 22,
                        height: 1.8,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dailyVerse!.translation != null) ...[
                      Divider(
                        color: Colors.white.withValues(alpha: 0.1),
                        height: 24,
                      ),
                      Text(
                        dailyVerse!.translation!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Stats Section
// ─────────────────────────────────────────────
class _StatsSection extends StatelessWidget {
  final int totalMastered;
  final int surahsStarted;
  final int totalFavorites;
  final bool isDark;

  const _StatsSection({
    required this.totalMastered,
    required this.surahsStarted,
    required this.totalFavorites,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.check_circle_outline_rounded,
            value: '$totalMastered',
            label: 'Versets',
            color: AppColors.primary,
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.menu_book_outlined,
            value: '$surahsStarted',
            label: 'Sourates',
            color: AppColors.accent,
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.bookmark_outline_rounded,
            value: '$totalFavorites',
            label: 'Favoris',
            color: AppColors.medinan,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.05 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Continue Reading Card
// ─────────────────────────────────────────────
class _ContinueReadingCard extends StatelessWidget {
  final int surahId;
  final int ayahId;
  final bool isPlaying;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  const _ContinueReadingCard({
    required this.surahId,
    required this.ayahId,
    required this.isPlaying,
    required this.isDark,
    required this.onTap,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onPlayPause,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPlaying ? 'En cours de lecture' : 'Continuer la lecture',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FutureBuilder<Surah>(
                        future: QuranService.instance.getSurah(surahId),
                        builder: (context, snapshot) {
                          final name = snapshot.data?.transliteration ?? '...';
                          return Text(
                            '$name, Verset $ayahId',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Continue Reading Pinned Header Delegate
// ─────────────────────────────────────────────
class _ContinueReadingHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _ContinueReadingHeaderDelegate({required this.child});

  @override
  double get minExtent => 96;
  @override
  double get maxExtent => 96;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _ContinueReadingHeaderDelegate oldDelegate) => true;
}

// ─────────────────────────────────────────────
// Recent Surahs Section
// ─────────────────────────────────────────────
class _RecentSurahsSection extends StatelessWidget {
  final List<int> recentIds;
  final bool isDark;
  final void Function(int surahId) onTap;

  const _RecentSurahsSection({
    required this.recentIds,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (recentIds.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Lectures recentes',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: recentIds.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final surahId = recentIds[index];
                return FutureBuilder<Surah>(
                  future: QuranService.instance.getSurah(surahId),
                  builder: (context, snapshot) {
                    final surah = snapshot.data;
                    if (surah == null) return const SizedBox(width: 120);

                    return GestureDetector(
                      onTap: () => onTap(surahId),
                      child: Container(
                        width: 130,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surface : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (isDark ? AppColors.divider : AppColors.dividerLight)
                                .withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              surah.name,
                              style: const TextStyle(
                                fontFamily: 'Scheherazade',
                                fontSize: 16,
                                color: AppColors.accent,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              surah.transliteration,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${surah.totalVerses} versets',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Search Bar
// ─────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool isDark;

  const _SearchBar({required this.controller, required this.onChanged, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? AppColors.divider : AppColors.dividerLight).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.poppins(
          color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Rechercher une sourate...',
          hintStyle: GoogleFonts.poppins(
            color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
            size: 20,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                    size: 18,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : IconButton(
                  icon: Icon(
                    Icons.manage_search_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  tooltip: 'Rechercher dans le texte',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Surah Tile
// ─────────────────────────────────────────────
class _SurahTile extends StatelessWidget {
  final Surah surah;
  final int index;
  final double progress;
  final AnimationController animation;
  final bool isDark;
  final VoidCallback onTap;

  const _SurahTile({
    required this.surah,
    required this.index,
    required this.progress,
    required this.animation,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final delay = (index / 114).clamp(0.0, 1.0);
    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Interval(delay * 0.5, (delay * 0.5 + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    ));

    final fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(delay * 0.5, (delay * 0.5 + 0.5).clamp(0.0, 1.0),
            curve: Curves.easeOut),
      ),
    );

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: progress > 0
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : (isDark ? AppColors.divider : AppColors.dividerLight).withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Surah number
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: progress > 0
                            ? LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.15),
                                  AppColors.primaryLight.withValues(alpha: 0.08),
                                ],
                              )
                            : null,
                        color: progress <= 0
                            ? (isDark ? AppColors.surfaceLight : Colors.grey[50])
                            : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${surah.id}',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: progress > 0
                                ? AppColors.primaryLight
                                : (isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            surah.transliteration,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              _TypeBadge(isMeccan: surah.isMeccan),
                              const SizedBox(width: 8),
                              Text(
                                '${surah.totalVerses} versets',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                                ),
                              ),
                              if (progress > 0) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '${(progress * 100).round()}%',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (progress > 0) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: (isDark ? AppColors.divider : AppColors.dividerLight)
                                    .withValues(alpha: 0.3),
                                color: AppColors.primary,
                                minHeight: 3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Arabic name
                    Text(
                      surah.name,
                      style: TextStyle(
                        fontSize: 22,
                        color: isDark ? AppColors.textArabic : Colors.black87,
                        fontFamily: 'Scheherazade',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final bool isMeccan;

  const _TypeBadge({required this.isMeccan});

  @override
  Widget build(BuildContext context) {
    final color = isMeccan ? AppColors.meccan : AppColors.medinan;
    final label = isMeccan ? 'Mecquoise' : 'Medinoise';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Juz list items
// ─────────────────────────────────────────────
class _JuzHeaderItem {
  final int juz;
  final int page;
  const _JuzHeaderItem({required this.juz, required this.page});
}

class _SurahItem {
  final Surah surah;
  final int originalIndex;
  const _SurahItem({required this.surah, required this.originalIndex});
}

class _JuzHeader extends StatelessWidget {
  final int juz;
  final int page;
  final bool isDark;

  const _JuzHeader({required this.juz, required this.page, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Juz' $juz",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'Page $page',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
