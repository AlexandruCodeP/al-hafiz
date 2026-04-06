import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/quran_service.dart';
import '../services/storage_service.dart';
import '../models/surah.dart';
import '../theme/app_theme.dart';
import 'reader_screen.dart';

class FavoritesScreen extends StatefulWidget {
  final StorageService storageService;

  const FavoritesScreen({super.key, required this.storageService});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FavoriteItem> _favorites = [];
  final Map<int, Surah> _surahCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    _favorites = widget.storageService.getFavorites();
    // Cache surahs for display
    for (final fav in _favorites) {
      if (!_surahCache.containsKey(fav.surahId)) {
        _surahCache[fav.surahId] =
            await QuranService.instance.getSurah(fav.surahId);
      }
    }
    setState(() => _isLoading = false);
  }

  // Group favorites by surah
  Map<int, List<FavoriteItem>> get _grouped {
    final map = <int, List<FavoriteItem>>{};
    for (final fav in _favorites) {
      map.putIfAbsent(fav.surahId, () => []).add(fav);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mes Révisions',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _favorites.isEmpty
              ? _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _grouped.length,
                  itemBuilder: (context, index) {
                    final surahId = _grouped.keys.elementAt(index);
                    final favs = _grouped[surahId]!;
                    final surah = _surahCache[surahId]!;

                    return _SurahFavoriteGroup(
                      surah: surah,
                      favorites: favs,
                      storageService: widget.storageService,
                      onRemove: (fav) async {
                        await widget.storageService.toggleFavorite(
                          fav.surahId,
                          fav.ayahId,
                        );
                        setState(() {
                          _favorites.remove(fav);
                        });
                      },
                      onTap: (fav) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReaderScreen(surah: surah),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bookmark_outline_rounded,
              color: AppColors.textSecondary,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No favorites yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bookmark ayahs while reading\nto find them here',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurahFavoriteGroup extends StatelessWidget {
  final Surah surah;
  final List<FavoriteItem> favorites;
  final StorageService storageService;
  final ValueChanged<FavoriteItem> onRemove;
  final ValueChanged<FavoriteItem> onTap;

  const _SurahFavoriteGroup({
    required this.surah,
    required this.favorites,
    required this.storageService,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.divider.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${surah.id}',
                      style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  surah.transliteration,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  surah.name,
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.accent,
                    fontFamily: 'Scheherazade',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // Favorite items
          ...favorites.map((fav) {
            final ayah = surah.verses.where((a) => a.id == fav.ayahId).firstOrNull;
            if (ayah == null) return const SizedBox.shrink();
            return Dismissible(
              key: ValueKey('${fav.surahId}:${fav.ayahId}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
              ),
              onDismissed: (_) => onRemove(fav),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withValues(alpha: 0.1),
                  ),
                  child: Center(
                    child: Text(
                      '${ayah.id}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  ayah.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'Scheherazade',
                    color: AppColors.textArabic,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                onTap: () => onTap(fav),
              ),
            );
          }),
        ],
      ),
    );
  }
}
