import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/juz_data.dart';
import '../models/mushaf_pack.dart';
import '../models/surah.dart';
import '../services/audio_service.dart';
import '../services/mushaf_layout_service.dart';
import '../services/mushaf_repository.dart';
import '../services/qcf_font_service.dart';
import '../services/quran_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_player_bar.dart';
import '../widgets/mushaf_page_view.dart';
import '../widgets/paper_grain.dart';
import 'mushaf_style_screen.dart';

/// Lecture en mode Mushaf : une planche par ecran, tournee de droite a gauche.
class MushafScreen extends StatefulWidget {
  /// Page d'ouverture (1-604). Ignoree si [initialSurah] est fourni et que le
  /// pack sait localiser le verset.
  final int initialPage;
  final int? initialSurah;
  final int? initialAyah;

  const MushafScreen({
    super.key,
    this.initialPage = 1,
    this.initialSurah,
    this.initialAyah,
  });

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  static const _totalPages = 604;

  PageController? _controller;
  Map<int, Surah> _surahs = {};
  Map<int, String> _surahNames = const {};
  int _currentPage = 1;
  bool _ready = false;

  /// Dernier verset pour lequel on a tourne la page automatiquement : evite de
  /// reprendre la main sur l'utilisateur a chaque reconstruction.
  String? _lastAutoTurn;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(1, _totalPages);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final surahs = await QuranService.instance.getAllSurahs();
    var page = _currentPage;

    if (widget.initialSurah != null) {
      final ayah = widget.initialAyah ?? 1;
      // La base du pack fait autorite ; page_map.json sert de repli quand le
      // pack n'est pas encore ouvert.
      page = await MushafLayoutService.instance
              .pageOfAyah(widget.initialSurah!, ayah) ??
          QuranService.instance.getPageNumber(widget.initialSurah!, ayah) ??
          page;
    }

    if (!mounted) return;
    setState(() {
      _surahs = {for (final s in surahs) s.id: s};
      _surahNames = {for (final s in surahs) s.id: s.name};
      _currentPage = page.clamp(1, _totalPages);
      _controller = PageController(initialPage: _currentPage - 1);
      _ready = true;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    final page = index + 1;
    setState(() => _currentPage = page);
    MushafLayoutService.instance.prefetch([page - 1, page + 1, page + 2]);

    final repo = context.read<MushafRepository>();
    final packId = repo.activePackId;
    final fontsDir = packId == null ? null : repo.fontsDirOf(packId);
    if (packId != null && fontsDir != null) {
      QcfFontService.instance.prefetch(
        packId: packId,
        fontsDir: fontsDir,
        pages: [page - 1, page + 1],
      );
    }
  }

  /// Suit la recitation : tourne la page quand l'audio passe sur un verset
  /// situe ailleurs.
  Future<void> _followAudio(int surah, int ayah) async {
    final key = '$surah:$ayah';
    if (_lastAutoTurn == key) return;
    _lastAutoTurn = key;

    final target = await MushafLayoutService.instance.pageOfAyah(surah, ayah);
    if (!mounted || target == null || target == _currentPage) return;
    final controller = _controller;
    if (controller == null || !controller.hasClients) return;
    controller.animateToPage(
      target - 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<MushafRepository>();
    final audio = context.watch<AudioService>();
    final packId = repo.activePackId;
    final fontsDir = packId == null ? null : repo.fontsDirOf(packId);

    if (repo.isReady && (packId == null || fontsDir == null)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mushaf')),
        body: const _NoPackState(),
      );
    }

    if (!repo.isReady ||
        packId == null ||
        fontsDir == null ||
        !_ready ||
        _controller == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mushaf')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final playingSurah = audio.currentSurahId;
    final playingAyah = audio.currentAyahId;
    if (playingSurah != null && playingAyah != null && audio.isPlaying) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _followAudio(playingSurah, playingAyah),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              _titleForPage(_currentPage),
              style: const TextStyle(fontSize: 17),
            ),
            Text(
              'Juz ${_juzForPage(_currentPage)} · Page $_currentPage',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Style d\'affichage',
            icon: const Icon(Icons.style_outlined, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MushafStyleScreen()),
            ),
          ),
        ],
      ),
      body: PaperGrainOverlay(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                // Le Mushaf se feuillette de droite a gauche.
                reverse: true,
                itemCount: _totalPages,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) => _MushafPageHost(
                  pageNumber: index + 1,
                  packId: packId,
                  fontsDir: fontsDir,
                  surahNames: _surahNames,
                  highlightedSurah: playingSurah,
                  highlightedAyah: playingAyah,
                  onAyahTap: _playAyah,
                ),
              ),
            ),
            AudioPlayerBar(
              surahName: audio.currentSurahId == null
                  ? null
                  : _surahs[audio.currentSurahId!]?.transliteration,
              ayahNumber: audio.currentAyahId,
              totalVerses: _surahs[audio.currentSurahId]?.totalVerses ?? 0,
              displayedSurahId: audio.currentSurahId,
            ),
          ],
        ),
      ),
    );
  }

  void _playAyah(int surah, int ayah) {
    final total = _surahs[surah]?.totalVerses;
    context.read<AudioService>().playAyah(surah, ayah, total);
    context.read<StorageService>().saveLastPosition(surah, ayah);
  }

  String _titleForPage(int page) {
    final surahId = _surahOnPage(page);
    return _surahs[surahId]?.transliteration ?? 'Mushaf';
  }

  int _juzForPage(int page) {
    var juz = 1;
    for (final b in JuzData.boundaries) {
      if (page >= b.page) juz = b.juz;
    }
    return juz;
  }

  /// Sourate dominante d'une page, deduite de page_map.json : suffisant pour un
  /// titre, et disponible sans attendre l'ouverture de la base du pack.
  int _surahOnPage(int page) {
    for (final surah in _surahs.values) {
      final range = QuranService.instance.getSurahPageRange(surah.id);
      if (range == null) continue;
      if (page >= range.$1 && page <= range.$2) return surah.id;
    }
    return 1;
  }
}

/// Charge la mise en page et la police d'une planche, puis la rend.
class _MushafPageHost extends StatefulWidget {
  final int pageNumber;
  final String packId;
  final String fontsDir;
  final Map<int, String> surahNames;
  final int? highlightedSurah;
  final int? highlightedAyah;
  final void Function(int surah, int ayah) onAyahTap;

  const _MushafPageHost({
    required this.pageNumber,
    required this.packId,
    required this.fontsDir,
    required this.surahNames,
    required this.onAyahTap,
    this.highlightedSurah,
    this.highlightedAyah,
  });

  @override
  State<_MushafPageHost> createState() => _MushafPageHostState();
}

class _MushafPageHostState extends State<_MushafPageHost> {
  MushafPage? _page;
  bool _fontReady = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _MushafPageHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageNumber != widget.pageNumber ||
        oldWidget.packId != widget.packId) {
      _page = null;
      _fontReady = false;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final requested = widget.pageNumber;
    final pageFuture = MushafLayoutService.instance.getPage(requested);
    final fontFuture = QcfFontService.instance.ensureFont(
      packId: widget.packId,
      fontsDir: widget.fontsDir,
      page: requested,
    );
    final page = await pageFuture;
    final fontReady = await fontFuture;
    // Le PageView recycle ses enfants : ignorer une reponse qui ne concerne
    // plus la page actuellement demandee.
    if (!mounted || widget.pageNumber != requested) return;
    setState(() {
      _page = page;
      _fontReady = fontReady;
      _failed = page == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Cette page est absente du pack installe.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final page = _page;
    if (page == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return MushafPageView(
      page: page,
      packId: widget.packId,
      fontReady: _fontReady,
      surahNames: widget.surahNames,
      highlightedSurah: widget.highlightedSurah,
      highlightedAyah: widget.highlightedAyah,
      onAyahTap: widget.onAyahTap,
    );
  }
}

/// Etat vide : aucun pack installe, on renvoie vers l'ecran de telechargement.
class _NoPackState extends StatelessWidget {
  const _NoPackState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun Mushaf installe',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Telechargez une edition pour lire le Coran exactement comme sur '
              'le livre imprime, hors ligne.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MushafStyleScreen()),
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Choisir un Mushaf'),
            ),
          ],
        ),
      ),
    );
  }
}
