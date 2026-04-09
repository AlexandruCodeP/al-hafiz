import 'package:flutter/material.dart';
import '../models/mushaf.dart';
import '../services/mushaf_service.dart';

/// Minimal mushaf page screen.
///
/// Displays a single mushaf page as a Column of RTL lines,
/// each line being a Row of tappable word widgets.
/// No decorations — just the text layout from the API data.
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
      _error = data == null ? 'Impossible de charger la page $_currentPage' : null;
    });

    // Prefetch neighbours.
    if (_currentPage < 604) MushafService.instance.prefetch([_currentPage + 1]);
    if (_currentPage > 1) MushafService.instance.prefetch([_currentPage - 1]);
  }

  void _goToPage(int page) {
    if (page < 1 || page > 604) return;
    _currentPage = page;
    _loadPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Page $_currentPage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage < 604 ? () => _goToPage(_currentPage + 1) : null,
            tooltip: 'Page suivante',
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
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

    final page = _pageData!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Lines fill available space evenly.
          for (final line in page.lines)
            Expanded(child: _buildLine(line)),

          // Page number at the bottom.
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
  }

  Widget _buildLine(MushafLine line) {
    if (line.tokens.isEmpty) return const SizedBox.expand();

    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: line.tokens.map(_buildToken).toList(),
    );
  }

  Widget _buildToken(MushafToken token) {
    return GestureDetector(
      onTap: () {
        debugPrint('Tapped: surah=${token.surah} ayah=${token.ayah} '
            'word=${token.wordIndex} type=${token.type}');
      },
      child: Text(
        token.text,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          fontFamily: 'Scheherazade',
          fontSize: 22,
          height: 1.8,
        ),
      ),
    );
  }
}
