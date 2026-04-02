import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Displays Mushaf pages as images from CDN with swipe navigation.
class MushafPageView extends StatefulWidget {
  final int initialPage;
  final int startPage;
  final int endPage;
  final ValueChanged<int>? onPageChanged;

  const MushafPageView({
    super.key,
    required this.initialPage,
    required this.startPage,
    required this.endPage,
    this.onPageChanged,
  });

  @override
  State<MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends State<MushafPageView> {
  late PageController _pageController;
  late int _currentPage;

  static const _baseUrl = 'https://www.mp3quran.net/api/quran_pages_arabic';

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    final initialIndex = widget.initialPage - widget.startPage;
    _pageController = PageController(initialPage: initialIndex.clamp(0, _totalPages - 1));
  }

  int get _totalPages => widget.endPage - widget.startPage + 1;

  String _imageUrl(int pageNumber) {
    final padded = pageNumber.toString().padLeft(3, '0');
    return '$_baseUrl/$padded.png';
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Page indicator
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          color: isDark ? AppColors.surface : Colors.grey[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_stories_rounded, size: 16,
                  color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
              const SizedBox(width: 6),
              Text(
                'Page $_currentPage / 604',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        // Page view
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            // Quran reads right-to-left, so reverse swipe direction
            reverse: true,
            itemCount: _totalPages,
            onPageChanged: (index) {
              final pageNum = widget.startPage + index;
              setState(() => _currentPage = pageNum);
              widget.onPageChanged?.call(pageNum);
            },
            itemBuilder: (context, index) {
              final pageNum = widget.startPage + index;
              return _MushafPage(
                pageNumber: pageNum,
                imageUrl: _imageUrl(pageNum),
                isDark: isDark,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MushafPage extends StatelessWidget {
  final int pageNumber;
  final String imageUrl;
  final bool isDark;

  const _MushafPage({
    required this.pageNumber,
    required this.imageUrl,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFDF8F0),
      child: InteractiveViewer(
        minScale: 1.0,
        maxScale: 3.0,
        child: Center(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              final progress = loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null;
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Page $pageNumber',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 48,
                        color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
                    const SizedBox(height: 12),
                    Text(
                      'Impossible de charger la page $pageNumber',
                      style: TextStyle(
                        color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Verifiez votre connexion internet',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
