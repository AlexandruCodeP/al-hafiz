import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/surah.dart';
import '../services/quran_service.dart';
import '../theme/app_theme.dart';
import 'reader_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<({int surahId, String surahName, String transliteration, Ayah ayah})> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(query);
    });
  }

  void _search(String query) {
    setState(() => _isSearching = true);
    final results = QuranService.instance.searchVerses(query);
    setState(() {
      _results = results;
      _isSearching = false;
      _hasSearched = true;
    });
  }

  void _openResult(int surahId, int ayahId) async {
    final surah = await QuranService.instance.getSurah(surahId);
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReaderScreen(surah: surah, initialAyahId: ayahId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onQueryChanged,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
          ),
          decoration: InputDecoration(
            hintText: 'Rechercher un mot ou verset...',
            hintStyle: GoogleFonts.poppins(
              color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
            ),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() {
                  _results = [];
                  _hasSearched = false;
                });
              },
            ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Rechercher dans le Quran',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Texte arabe, traduction ou phonetique',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: (isDark ? AppColors.textSecondary : AppColors.textSecondaryLight).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Aucun resultat',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final r = _results[index];
        return _SearchResultCard(
          surahName: r.surahName,
          transliteration: r.transliteration,
          surahId: r.surahId,
          ayah: r.ayah,
          isDark: isDark,
          query: _controller.text,
          onTap: () => _openResult(r.surahId, r.ayah.id),
        );
      },
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final String surahName;
  final String transliteration;
  final int surahId;
  final Ayah ayah;
  final bool isDark;
  final String query;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.surahName,
    required this.transliteration,
    required this.surahId,
    required this.ayah,
    required this.isDark,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isDark ? AppColors.surfaceLight : AppColors.surfaceLightT,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.divider : AppColors.dividerLight,
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: surah info
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$surahId:${ayah.id}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    transliteration,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    surahName,
                    style: TextStyle(
                      fontFamily: 'Scheherazade',
                      fontSize: 16,
                      color: isDark ? AppColors.textArabic : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Arabic text
              Text(
                ayah.text,
                style: const TextStyle(
                  fontFamily: 'Scheherazade',
                  fontSize: 22,
                  height: 1.8,
                  color: AppColors.accent,
                ),
                textDirection: TextDirection.rtl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Translation if available
              if (ayah.translation != null) ...[
                const SizedBox(height: 6),
                Text(
                  ayah.translation!,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
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
    );
  }
}
