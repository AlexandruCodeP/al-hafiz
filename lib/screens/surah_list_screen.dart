import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/surah.dart';
import '../services/audio_service.dart';
import '../services/quran_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'reader_screen.dart';

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
      duration: const Duration(milliseconds: 800),
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

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final audio = context.watch<AudioService>();
    final (lastSurahId, lastAyahId) = storage.getLastPosition();

    // Prioritize currently playing surah, fallback to last position
    final playerSurahId = audio.currentSurahId ?? lastSurahId;
    final playerAyahId = audio.currentAyahId ?? lastAyahId ?? 1;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.background,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.menu_book_rounded,
                                color: AppColors.accent,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Al-Hafiz',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Quran Memorization',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _SearchBar(
                  controller: _searchController,
                  onChanged: _filterSurahs,
                ),
              ),
            ),
          ),

          if (!_isLoading && playerSurahId != null)
            SliverPersistentHeader(
              pinned: true,
              delegate: _PlayerHeaderDelegate(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _ContinueReadingCard(
                    surahId: playerSurahId,
                    ayahId: playerAyahId,
                    isPlaying: audio.isPlaying && audio.currentSurahId == playerSurahId,
                    onTap: () async {
                      final surah = await QuranService.instance.getSurah(playerSurahId);
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReaderScreen(
                              surah: surah,
                              initialAyahId: playerAyahId,
                            ),
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

          if (_isLoading)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading Quran...',
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!_isLoading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final surah = _filtered[index];
                    final progress = storage.getSurahProgress(surah.id, surah.totalVerses);

                    return _SurahTile(
                      surah: surah,
                      index: index,
                      progress: progress,
                      animation: _animController,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReaderScreen(surah: surah),
                          ),
                        );
                      },
                    );
                  },
                  childCount: _filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlayerHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _PlayerHeaderDelegate({required this.child});

  @override
  double get maxExtent => 108;

  @override
  double get minExtent => 108;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PlayerHeaderDelegate oldDelegate) => true;
}

class _ContinueReadingCard extends StatelessWidget {
  final int surahId;
  final int ayahId;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  const _ContinueReadingCard({
    required this.surahId,
    required this.ayahId,
    required this.isPlaying,
    required this.onTap,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onPlayPause,
                  child: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPlaying ? 'En cours de lecture' : 'Continuer la lecture',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
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
                              fontSize: 18,
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
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.divider.withValues(alpha: 0.5),
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.poppins(
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search surah by name or number...',
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  final Surah surah;
  final int index;
  final double progress;
  final AnimationController animation;
  final VoidCallback onTap;

  const _SurahTile({
    required this.surah,
    required this.index,
    required this.progress,
    required this.animation,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.divider.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '${surah.id}',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                surah.transliteration,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  _TypeBadge(isMeccan: surah.isMeccan),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '${surah.totalVerses} verses',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          surah.name,
                          style: const TextStyle(
                            fontSize: 22,
                            color: AppColors.textArabic,
                            fontFamily: 'Scheherazade',
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                    if (progress > 0) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppColors.divider.withValues(alpha: 0.1),
                          color: AppColors.primary,
                          minHeight: 3,
                        ),
                      ),
                    ],
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
    final label = isMeccan ? 'Meccan' : 'Medinan';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
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
