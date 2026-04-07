import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../models/surah.dart';
import '../services/audio_service.dart';
import '../services/hifz_engine.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ayah_card.dart';
import '../widgets/audio_player_bar.dart';
import '../widgets/hifz_controls.dart';
import '../widgets/note_dialog.dart';
import '../widgets/focus_mode.dart';
import '../widgets/paper_grain.dart';
import '../widgets/mushaf_page_view.dart';
import '../widgets/quran_page_view.dart';
import '../models/reciter.dart';
import '../services/quran_service.dart';

class ReaderScreen extends StatefulWidget {
  final Surah surah;
  final int? initialAyahId;

  const ReaderScreen({super.key, required this.surah, this.initialAyahId});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with SingleTickerProviderStateMixin {
  bool _showHifzControls = false;
  bool _focusModeActive = false;
  bool _hideText = false;
  bool _autoScrollEnabled = true;
  bool _pageMode = true;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _entryAnim;
  AudioService? _audioService;
  late Surah _surah;
  bool _isLoadingExtra = true;
  final Map<int, GlobalKey> _ayahKeys = {};
  int? _lastScrolledToAyah;

  @override
  void initState() {
    super.initState();
    _surah = widget.surah;
    _entryAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _loadEnrichedSurah();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _audioService = context.read<AudioService>();
      final hifz = context.read<HifzEngine>();

      hifz.setSurahId(widget.surah.id);
      hifz.setRange(1, widget.surah.totalVerses);

      _audioService!.onVerseComplete = () {
        // Scroll to the new verse in the UI
        if (_audioService!.currentAyahId != null) {
          _scrollToAyah(_audioService!.currentAyahId! - 1);
        }
      };

      if (widget.initialAyahId != null) {
        _scrollToAyah(widget.initialAyahId! - 1);
        _audioService!.playAyah(widget.surah.id, widget.initialAyahId!, widget.surah.totalVerses);
      }
    });
  }

  Future<void> _loadEnrichedSurah() async {
    final enriched = await QuranService.instance.getSurah(widget.surah.id);
    if (mounted) {
      setState(() {
        _surah = enriched;
        _isLoadingExtra = false;
      });
    }
  }

  @override
  void dispose() {
    _audioService?.onVerseComplete = null;
    _scrollController.dispose();
    _entryAnim.dispose();
    super.dispose();
  }

  /// Detect user-initiated scroll (finger drag) vs programmatic scroll
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      // DragScrollActivity has non-null dragDetails -> user is dragging
      if (notification.dragDetails != null && _autoScrollEnabled) {
        setState(() => _autoScrollEnabled = false);
      }
    }
    return false; // don't absorb the notification
  }

  void _scrollToAyah(int ayahIndex) {
    if (!_scrollController.hasClients || !_autoScrollEnabled) return;

    final ayahId = ayahIndex + 1;
    final key = _ayahKeys[ayahId];
    if (key == null) return;

    final renderObj = key.currentContext?.findRenderObject();
    if (renderObj == null || renderObj is! RenderBox) return;

    // Get card position relative to screen
    final cardScreenOffset = renderObj.localToGlobal(Offset.zero);
    final cardHeight = renderObj.size.height;
    final viewportHeight = _scrollController.position.viewportDimension;

    // Calculate how far off-center the card currently is
    final cardCenter = cardScreenOffset.dy + cardHeight / 2;
    final viewportCenter = viewportHeight / 2;
    final delta = cardCenter - viewportCenter;

    final target = _scrollController.offset + delta;

    _scrollController.animateTo(
      target.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _jumpToCurrentVerse() {
    final audio = _audioService;
    if (audio == null || audio.currentAyahId == null) return;
    if (audio.currentSurahId != widget.surah.id) return;

    setState(() {
      _autoScrollEnabled = true;
      _lastScrolledToAyah = null; // force re-scroll
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _scrollToAyah(audio.currentAyahId! - 1);
    });
  }

  Widget _buildPageMode(AudioService audio) {
    final currentAyah = audio.currentSurahId == widget.surah.id
        ? audio.currentAyahId
        : null;

    return QuranPageView(
      surah: _surah,
      currentPlayingAyahId: currentAyah,
      onAyahTap: (ayahId) {
        audio.playAyah(widget.surah.id, ayahId, widget.surah.totalVerses);
        context.read<StorageService>().saveLastPosition(widget.surah.id, ayahId);
      },
    );
  }

  Widget _buildVerseMode() {
    return Consumer2<AudioService, StorageService>(
      builder: (context, audio, storage, _) {
        return NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: 0, bottom: 80),
            itemCount: _surah.verses.length + 1,
            itemBuilder: (context, index) {
              // ── Surah header card ──
              if (index == 0) {
                return _SurahHeaderCard(surah: widget.surah);
              }
              final ayah = _surah.verses[index - 1];
              final isPlaying = audio.currentSurahId == widget.surah.id &&
                  audio.currentAyahId == ayah.id;
              _ayahKeys.putIfAbsent(ayah.id, () => GlobalKey());

              if (isPlaying &&
                  _autoScrollEnabled &&
                  _lastScrolledToAyah != ayah.id) {
                _lastScrolledToAyah = ayah.id;
                Future.delayed(const Duration(milliseconds: 150), () {
                  if (mounted && _autoScrollEnabled) {
                    _scrollToAyah(index - 1);
                  }
                });
              }

              return FocusModeAyahWrapper(
                key: _ayahKeys[ayah.id],
                focusModeActive: _focusModeActive,
                isPlayingAyah: isPlaying,
                child: AyahCard(
                  ayah: ayah,
                  surahId: widget.surah.id,
                  isPlaying: isPlaying,
                  isFavorite: storage.isFavorite(widget.surah.id, ayah.id),
                  isMastered: storage.isMastered(widget.surah.id, ayah.id),
                  hideText: _hideText && !isPlaying,
                  textSizeMultiplier: storage.textSizeMultiplier,
                  arabicTextSize: storage.arabicTextSize,
                  translationTextSize: storage.translationTextSize,
                  showArabic: storage.showArabic,
                  showTranslation: storage.showTranslation,
                  showPhonetic: storage.showPhonetic,
                  onTap: () {
                    audio.playAyah(widget.surah.id, ayah.id, widget.surah.totalVerses);
                    storage.saveLastPosition(widget.surah.id, ayah.id);
                  },
                  onLongPress: () => _showAyahContextMenu(context, ayah),
                  onFavoriteTap: () =>
                      storage.toggleFavorite(widget.surah.id, ayah.id),
                  onMasteredTap: () =>
                      storage.toggleMastered(widget.surah.id, ayah.id),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioService>();
    final bool showMiniPlayer = audio.currentSurahId != null &&
        audio.currentSurahId != widget.surah.id;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.surah.transliteration, style: const TextStyle(fontSize: 18)),
            Text(widget.surah.name,
              style: const TextStyle(fontSize: 14, fontFamily: 'Scheherazade', color: AppColors.accent),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _pageMode ? Icons.view_agenda_rounded : Icons.auto_stories_rounded,
              size: 20,
            ),
            tooltip: _pageMode ? 'Mode verset' : 'Mode page',
            onPressed: () => setState(() => _pageMode = !_pageMode),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () => _showSettingsSheet(context),
          ),
        ],
      ),
      body: PaperGrainOverlay(
        child: Stack(
        children: [
         Column(
        children: [
          // Mini player bar when viewing a different surah than the one playing
          if (showMiniPlayer)
            _MiniPlayerBar(
              surahId: audio.currentSurahId!,
              ayahId: audio.currentAyahId,
              isPlaying: audio.isPlaying,
              onTap: () async {
                final surah = await QuranService.instance.getSurah(audio.currentSurahId!);
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReaderScreen(
                        surah: surah,
                        initialAyahId: audio.currentAyahId,
                      ),
                    ),
                  );
                }
              },
              onPlayPause: audio.togglePlayPause,
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _showHifzControls
                ? Consumer<HifzEngine>(
                    builder: (context, hifz, _) => HifzControls(
                      hifzEngine: hifz,
                      totalVerses: widget.surah.totalVerses,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: _pageMode
                ? _buildPageMode(audio)
                : _buildVerseMode(),
          ),
          AudioPlayerBar(
            surahName: widget.surah.transliteration,
            ayahNumber: audio.currentAyahId,
            totalVerses: widget.surah.totalVerses,
            displayedSurahId: widget.surah.id,
            onExpandHifz: () => setState(() => _showHifzControls = !_showHifzControls),
          ),
        ],
      ),
          // "Return to current verse" FAB
          if (!_autoScrollEnabled &&
              audio.currentSurahId == widget.surah.id &&
              audio.currentAyahId != null)
            Positioned(
              right: 16,
              bottom: 160,
              child: FloatingActionButton.small(
                onPressed: _jumpToCurrentVerse,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.vertical_align_center_rounded, color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Consumer2<StorageService, AudioService>(
          builder: (context, storage, audio, _) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            expand: false,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Réglages d\'affichage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    const Text('Taille du texte'),
                    Slider(
                      value: storage.textSizeMultiplier,
                      min: 0.8, max: 1.8,
                      onChanged: (v) => storage.setTextSizeMultiplier(v),
                    ),
                    SwitchListTile(
                      title: const Text('Arabe'),
                      value: storage.showArabic,
                      onChanged: (v) => storage.setShowArabic(v),
                    ),
                    SwitchListTile(
                      title: const Text('Phonétique'),
                      value: storage.showPhonetic,
                      onChanged: (v) => storage.setShowPhonetic(v),
                    ),
                    SwitchListTile(
                      title: const Text('Traduction'),
                      value: storage.showTranslation,
                      onChanged: (v) => storage.setShowTranslation(v),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Récitateur', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.record_voice_over_rounded),
                      title: Text(audio.currentReciter.displayName),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.pop(context);
                        _showReciterPicker(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReciterPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            final audio = context.watch<AudioService>();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.record_voice_over_rounded, size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'Choisir un récitateur',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        '${Reciter.all.length} récitateurs',
                        style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: Reciter.all.length,
                    itemBuilder: (context, index) {
                      final reciter = Reciter.all[index];
                      final isSelected = audio.currentReciter.id == reciter.id;
                      return ListTile(
                        leading: Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                          color: isSelected ? Theme.of(context).colorScheme.primary : null,
                          size: 22,
                        ),
                        title: Text(
                          reciter.displayName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          audio.setReciter(reciter);
                          context.read<StorageService>().setReciterId(reciter.id);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTafsir(BuildContext context, Ayah ayah) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _TafsirSheet(
          surahId: widget.surah.id,
          surahName: widget.surah.transliteration,
          ayah: ayah,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showAyahContextMenu(BuildContext context, Ayah ayah) {
    final storage = context.read<StorageService>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(storage.isBookmarked(widget.surah.id, ayah.id) ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded, size: 22),
              title: const Text('Marque-page'),
              onTap: () {
                storage.toggleBookmark(widget.surah.id, ayah.id);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.loop_rounded, size: 22),
              title: const Text('Boucler ce verset'),
              onTap: () {
                context.read<AudioService>().setLoopMode(LoopMode.one);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text('Note de mémorisation'),
              onTap: () async {
                Navigator.pop(ctx);
                final existingNote = storage.getNote(widget.surah.id, ayah.id);
                final result = await NoteDialog.show(
                  context,
                  initialNote: existingNote,
                  ayahLabel: '${widget.surah.transliteration} - Verset ${ayah.id}',
                );
                if (result != null) {
                  storage.saveNote(widget.surah.id, ayah.id, result);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_rounded, size: 22),
              title: const Text('Tafsir (exégèse)'),
              onTap: () {
                Navigator.pop(ctx);
                _showTafsir(context, ayah);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPlayerBar extends StatelessWidget {
  final int surahId;
  final int? ayahId;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  const _MiniPlayerBar({
    required this.surahId,
    required this.ayahId,
    required this.isPlaying,
    required this.onTap,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onPlayPause,
              child: Icon(
                isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FutureBuilder<Surah>(
                future: QuranService.instance.getSurah(surahId),
                builder: (context, snapshot) {
                  final name = snapshot.data?.transliteration ?? '...';
                  return Text(
                    'En cours : $name${ayahId != null ? ', Verset $ayahId' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  );
                },
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
    );
  }
}

class _TafsirSheet extends StatefulWidget {
  final int surahId;
  final String surahName;
  final Ayah ayah;
  final ScrollController scrollController;

  const _TafsirSheet({
    required this.surahId,
    required this.surahName,
    required this.ayah,
    required this.scrollController,
  });

  @override
  State<_TafsirSheet> createState() => _TafsirSheetState();
}

class _TafsirSheetState extends State<_TafsirSheet> {
  String? _tafsirText;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadTafsir();
  }

  Future<void> _loadTafsir() async {
    final text = await QuranService.instance.fetchTafsir(widget.surahId, widget.ayah.id);
    if (mounted) {
      setState(() {
        _tafsirText = text;
        _isLoading = false;
        _hasError = text == null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Tafsir',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.surahName} - Verset ${widget.ayah.id}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.ayah.text,
                  style: const TextStyle(
                    fontFamily: 'Scheherazade',
                    fontSize: 22,
                    height: 1.8,
                    color: AppColors.accent,
                  ),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Tafsir non disponible pour ce verset',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          _tafsirText!,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.7,
                            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Source : Ibn Kathir',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}

class _SurahHeaderCard extends StatelessWidget {
  final Surah surah;

  const _SurahHeaderCard({required this.surah});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.gradientDarkStart, AppColors.gradientDarkEnd]
              : [AppColors.gradientStart, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.accent).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            surah.transliteration,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.accent : const Color(0xFF5C3D1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${surah.type == "Meccan" ? "Mecquoise" : "Medinoise"} · ${surah.totalVerses} versets',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: isDark ? AppColors.textSecondary : const Color(0xFF8C6D4F),
            ),
          ),
          const SizedBox(height: 16),
          // Bismillah (skip for Surah At-Tawbah = 9)
          if (surah.id != 9)
            Text(
              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
              style: TextStyle(
                fontFamily: 'Scheherazade',
                fontSize: 24,
                height: 1.6,
                color: isDark ? AppColors.textArabic : const Color(0xFF3D2B14),
              ),
              textDirection: TextDirection.rtl,
            ),
        ],
      ),
    );
  }
}
