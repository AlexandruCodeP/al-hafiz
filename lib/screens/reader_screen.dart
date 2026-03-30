import 'package:flutter/material.dart';
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
  bool _userIsScrolling = false;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _entryAnim;

  @override
  void initState() {
    super.initState();
    _entryAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _scrollController.addListener(() {
      // Detect manual scrolling to avoid fighting with auto-scroll
      if (_scrollController.position.isScrollingNotifier.value) {
        _userIsScrolling = true;
        Future.delayed(const Duration(seconds: 2), () {
          _userIsScrolling = false;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audio = context.read<AudioService>();
      final hifz = context.read<HifzEngine>();

      hifz.setSurahId(widget.surah.id);
      hifz.setRange(1, widget.surah.totalVerses);

      // Connect audio service to the auto-next logic
      audio.onVerseComplete = () {
        if (audio.currentAyahId != null && audio.currentAyahId! < widget.surah.totalVerses) {
          audio.playAyah(widget.surah.id, audio.currentAyahId! + 1);
        }
      };

      if (widget.initialAyahId != null) {
        _scrollToAyah(widget.initialAyahId! - 1);
        audio.playAyah(widget.surah.id, widget.initialAyahId!);
      }
    });
  }

  @override
  void dispose() {
    context.read<AudioService>().onVerseComplete = null;
    _scrollController.dispose();
    _entryAnim.dispose();
    super.dispose();
  }

  void _scrollToAyah(int ayahIndex) {
    if (!_scrollController.hasClients || _userIsScrolling) return;
    final offset = ayahIndex * 160.0;
    _scrollController.animateTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
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
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () => _showSettingsSheet(context),
          ),
          IconButton(
            icon: Icon(_hideText ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
            onPressed: () => setState(() => _hideText = !_hideText),
          ),
          FocusModeToggle(
            isActive: _focusModeActive,
            onToggle: () => setState(() => _focusModeActive = !_focusModeActive),
          ),
        ],
      ),
      body: Column(
        children: [
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
            child: Consumer2<AudioService, StorageService>(
              builder: (context, audio, storage, _) {
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: widget.surah.verses.length,
                  itemBuilder: (context, index) {
                    final ayah = widget.surah.verses[index];
                    final isPlaying = audio.currentSurahId == widget.surah.id && audio.currentAyahId == ayah.id;

                    if (isPlaying && !_userIsScrolling) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToAyah(index));
                    }

                    return FocusModeAyahWrapper(
                      focusModeActive: _focusModeActive,
                      isPlayingAyah: isPlaying,
                      child: AyahCard(
                        ayah: ayah,
                        isPlaying: isPlaying,
                        isFavorite: storage.isFavorite(widget.surah.id, ayah.id),
                        isMastered: storage.isMastered(widget.surah.id, ayah.id),
                        hideText: _hideText && !isPlaying,
                        textSizeMultiplier: storage.textSizeMultiplier,
                        showArabic: storage.showArabic,
                        showTranslation: storage.showTranslation,
                        showPhonetic: storage.showPhonetic,
                        onTap: () {
                          audio.playAyah(widget.surah.id, ayah.id);
                          storage.saveLastPosition(widget.surah.id, ayah.id);
                        },
                        onLongPress: () => _showAyahContextMenu(context, ayah),
                        onFavoriteTap: () => storage.toggleFavorite(widget.surah.id, ayah.id),
                        onMasteredTap: () => storage.toggleMastered(widget.surah.id, ayah.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          AudioPlayerBar(
            surahName: widget.surah.transliteration,
            ayahNumber: context.watch<AudioService>().currentAyahId,
            totalVerses: widget.surah.totalVerses,
            onExpandHifz: () => setState(() => _showHifzControls = !_showHifzControls),
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Consumer<StorageService>(
          builder: (context, storage, _) => Padding(
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Mode Sombre'),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode)),
                        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode)),
                      ],
                      selected: {storage.themeMode},
                      onSelectionChanged: (v) => storage.setThemeMode(v.first),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
              leading: Icon(storage.isBookmarked(widget.surah.id, ayah.id) ? Icons.bookmark : Icons.bookmark_border),
              title: const Text('Marque-page'),
              onTap: () {
                storage.toggleBookmark(widget.surah.id, ayah.id);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.loop),
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
          ],
        ),
      ),
    );
  }
}
