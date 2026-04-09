import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mushaf.dart';
import '../services/audio_service.dart';
import '../services/mushaf_service.dart';

/// Minimal mushaf page screen (Étape 2).
///
/// Displays a single mushaf page as a Column of RTL lines,
/// each line being a Row of tappable word widgets.
/// Tapping a word plays the corresponding ayah via AudioService.
/// The active ayah is highlighted during playback.
class MushafPageScreen extends StatefulWidget {
  final int initialPage;

  const MushafPageScreen({super.key, this.initialPage = 1});

  @override
  State<MushafPageScreen> createState() => _MushafPageScreenState();
}

class _MushafPageScreenState extends State<MushafPageScreen> {
  late int _currentPage;
  MushafPage? _pageData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _loadPage();
  }

  Future<void> _loadPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final data = await MushafService.instance.getPage(_currentPage);

    if (!mounted) return;

    setState(() {
      _pageData = data;
      _loading = false;
      _error =
          data == null ? 'Impossible de charger la page $_currentPage' : null;
    });

    // Prefetch neighbours.
    if (_currentPage < 604) {
      MushafService.instance.prefetch([_currentPage + 1]);
    }
    if (_currentPage > 1) {
      MushafService.instance.prefetch([_currentPage - 1]);
    }
  }

  void _goToPage(int page) {
    if (page < 1 || page > 604) return;
    _currentPage = page;
    _loadPage();
  }

  /// Find the total number of verses for a surah that appears on this page.
  /// We need this for AudioService.playAyah's optional totalVerses param.
  int _totalVersesFor(int surah) {
    // Simple heuristic: look at the max ayah number for this surah on this page.
    // This is an approximation — AudioService handles continuation regardless.
    if (_pageData == null) return 0;
    int max = 0;
    for (final line in _pageData!.lines) {
      for (final t in line.tokens) {
        if (t.surah == surah && t.ayah > max) max = t.ayah;
      }
    }
    return max;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Page $_currentPage'),
        actions: [
          // Quran reads RTL: left chevron = next page (higher number)
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                _currentPage < 604 ? () => _goToPage(_currentPage + 1) : null,
            tooltip: 'Page suivante',
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
            tooltip: 'Page précédente',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadPage,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    // Consumer listens to AudioService to rebuild on playback changes.
    return Consumer<AudioService>(
      builder: (context, audio, _) {
        final page = _pageData!;
        final activeSurah = audio.currentSurahId;
        final activeAyah = audio.currentAyahId;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              for (final line in page.lines)
                Expanded(
                  child: _buildLine(line, audio, activeSurah, activeAyah),
                ),

              // Page number.
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${page.pageNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLine(
    MushafLine line,
    AudioService audio,
    int? activeSurah,
    int? activeAyah,
  ) {
    if (line.tokens.isEmpty) return const SizedBox.expand();

    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: line.tokens
          .map((t) => _buildToken(t, audio, activeSurah, activeAyah))
          .toList(),
    );
  }

  Widget _buildToken(
    MushafToken token,
    AudioService audio,
    int? activeSurah,
    int? activeAyah,
  ) {
    final isActive =
        token.surah == activeSurah && token.ayah == activeAyah;

    return GestureDetector(
      onTap: () {
        audio.playAyah(
          token.surah,
          token.ayah,
          _totalVersesFor(token.surah),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
              : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          token.text,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'Scheherazade',
            fontSize: 22,
            height: 1.8,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
      ),
    );
  }
}
