import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/surah.dart';
import '../services/quran_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_grain.dart';
import '../widgets/tap_scale.dart';
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

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadSurahs();
  }

  Future<void> _loadSurahs() async {
    final surahs = await QuranService.instance.getAllSurahs();
    setState(() {
      _surahs = surahs;
      _filtered = surahs;
      _isLoading = false;
    });
    _animController.forward();
  }

  void _filterSurahs(String query) {
    if (query.isEmpty) {
      setState(() => _filtered = _surahs);
    } else {
      setState(() => _filtered = QuranService.instance.searchSurahs(query));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _openSurah(Surah surah, {int? ayahId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(surah: surah, initialAyahId: ayahId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (lastSurahId, lastAyahId) = storage.getLastPosition();
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: PaperGrainOverlay(
        child: Column(
        children: [
          // ── Top section (safe area + title + search + quick access) ──
          Container(
            padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 0),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'Al-Hafiz',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 16),

                // Search bar
                _SearchBar(
                  controller: _searchController,
                  onChanged: _filterSurahs,
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                // Quick access cards
                _QuickAccessRow(
                  lastSurahId: lastSurahId,
                  lastAyahId: lastAyahId ?? 1,
                  bookmarks: storage.getBookmarks(),
                  isDark: isDark,
                  onResumeTap: lastSurahId == null
                      ? null
                      : () async {
                          final surah = await QuranService.instance.getSurah(lastSurahId);
                          if (mounted) _openSurah(surah, ayahId: lastAyahId);
                        },
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),

          // ── Surah list ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final surah = _filtered[index];
                      final progress = storage.getSurahProgress(surah.id, surah.totalVerses);

                      return _SurahTile(
                        surah: surah,
                        progress: progress,
                        isDark: isDark,
                        onTap: () => _openSurah(surah),
                      );
                    },
                  ),
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.divider : AppColors.dividerLight,
          width: 0.5,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.poppins(
          color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Rechercher sourate, juz, page...',
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
                  icon: Icon(Icons.close_rounded, size: 18,
                    color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
                  onPressed: () { controller.clear(); onChanged(''); },
                )
              : IconButton(
                  icon: Icon(Icons.manage_search_rounded, color: AppColors.primary, size: 22),
                  tooltip: 'Recherche avancee',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Quick Access Row
// ─────────────────────────────────────────────
class _QuickAccessRow extends StatelessWidget {
  final int? lastSurahId;
  final int lastAyahId;
  final List<String> bookmarks;
  final bool isDark;
  final VoidCallback? onResumeTap;

  const _QuickAccessRow({
    required this.lastSurahId,
    required this.lastAyahId,
    required this.bookmarks,
    required this.isDark,
    this.onResumeTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Resume reading card
          if (lastSurahId != null)
            FutureBuilder<Surah>(
              future: QuranService.instance.getSurah(lastSurahId!),
              builder: (context, snapshot) {
                final name = snapshot.data?.transliteration ?? '...';
                return _QuickCard(
                  icon: Icons.menu_book_rounded,
                  title: 'Reprendre',
                  subtitle: '$name v.$lastAyahId',
                  isDark: isDark,
                  isActive: true,
                  onTap: onResumeTap,
                );
              },
            ),
          if (lastSurahId != null) const SizedBox(width: 10),

          // Bookmark cards (show first 2)
          if (bookmarks.isEmpty) ...[
            _QuickCard(
              icon: Icons.bookmark_outline_rounded,
              title: 'Signet 1',
              subtitle: 'Ajouter depuis le lecteur',
              isDark: isDark,
              isActive: false,
            ),
            const SizedBox(width: 10),
            _QuickCard(
              icon: Icons.bookmark_outline_rounded,
              title: 'Signet 2',
              subtitle: 'Ajouter depuis le lecteur',
              isDark: isDark,
              isActive: false,
            ),
          ] else
            ...bookmarks.take(2).map((bk) {
              final parts = bk.split(':');
              final surahId = int.tryParse(parts[0]) ?? 1;
              final ayahId = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: FutureBuilder<Surah>(
                  future: QuranService.instance.getSurah(surahId),
                  builder: (context, snapshot) {
                    final name = snapshot.data?.transliteration ?? '...';
                    return _QuickCard(
                      icon: Icons.bookmark_rounded,
                      title: name,
                      subtitle: 'v. $ayahId',
                      isDark: isDark,
                      isActive: true,
                      onTap: () async {
                        final surah = await QuranService.instance.getSurah(surahId);
                        if (context.mounted) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ReaderScreen(surah: surah, initialAyahId: ayahId),
                          ));
                        }
                      },
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final bool isActive;
  final VoidCallback? onTap;

  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.divider : AppColors.dividerLight,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 16,
                  color: isActive ? AppColors.primary : (isDark ? AppColors.textSecondary : AppColors.textSecondaryLight)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? (isDark ? AppColors.textPrimary : AppColors.textPrimaryLight)
                          : (isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
  final double progress;
  final bool isDark;
  final VoidCallback onTap;

  const _SurahTile({
    required this.surah,
    required this.progress,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TapScale(
        onTap: onTap,
        scaleDown: 0.97,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.divider.withValues(alpha: 0.4) : AppColors.dividerLight,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                // ── Number circle ──
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: progress > 0
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : isDark ? AppColors.surfaceLight : const Color(0xFFF5F0E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${surah.id}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: progress > 0
                            ? AppColors.primary
                            : isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // ── Name + verse count ──
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
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${surah.totalVerses} versets',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Arabic name ──
                Text(
                  surah.name,
                  style: TextStyle(
                    fontFamily: 'Scheherazade',
                    fontSize: 24,
                    color: isDark ? AppColors.accent : const Color(0xFF5C3D1A),
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }
}
