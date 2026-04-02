import 'package:flutter/material.dart';
import '../models/surah.dart';
import '../theme/app_theme.dart';

class AyahCard extends StatelessWidget {
  final Ayah ayah;
  final bool isPlaying;
  final bool isFavorite;
  final bool isMastered;
  final bool hideText;
  final double textSizeMultiplier;
  final bool showArabic;
  final bool showTranslation;
  final bool showPhonetic;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onMasteredTap;

  const AyahCard({
    super.key,
    required this.ayah,
    this.isPlaying = false,
    this.isFavorite = false,
    this.isMastered = false,
    this.hideText = false,
    this.textSizeMultiplier = 1.0,
    this.showArabic = true,
    this.showTranslation = true,
    this.showPhonetic = true,
    this.onTap,
    this.onLongPress,
    this.onFavoriteTap,
    this.onMasteredTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isPlaying
            ? AppColors.accent.withValues(alpha: 0.08)
            : isMastered 
                ? AppColors.primary.withValues(alpha: 0.03)
                : isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlaying 
              ? AppColors.accent.withValues(alpha: 0.5) 
              : isMastered 
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.divider.withValues(alpha: isDark ? 1.0 : 0.1),
          width: isPlaying ? 1.5 : 0.5,
        ),
        boxShadow: isPlaying
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPlaying
                                ? AppColors.accent.withValues(alpha: 0.2)
                                : isMastered 
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : isDark ? AppColors.surfaceLight : Colors.grey[100],
                            border: Border.all(
                              color: isPlaying 
                                  ? AppColors.accent 
                                  : isMastered 
                                      ? AppColors.primary 
                                      : AppColors.divider.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${ayah.id}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPlaying 
                                    ? AppColors.accent 
                                    : isMastered 
                                        ? AppColors.primaryLight 
                                        : isDark ? AppColors.textSecondary : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                        if (isMastered)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 8),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    if (onMasteredTap != null)
                      IconButton(
                        icon: Icon(
                          isMastered ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: isMastered ? AppColors.primary : AppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: onMasteredTap,
                        visualDensity: VisualDensity.compact,
                      ),
                    if (onFavoriteTap != null)
                      IconButton(
                        icon: Icon(
                          isFavorite ? Icons.bookmark : Icons.bookmark_outline,
                          color: isFavorite ? AppColors.accent : AppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: onFavoriteTap,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                if (showArabic) ...[
                  const SizedBox(height: 12),
                  Text(
                    hideText ? '...' : ayah.text,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: AppTheme.arabicTextStyle(textSizeMultiplier).copyWith(
                      color: isPlaying
                          ? (isDark ? AppColors.accentLight : Colors.black87)
                          : (isDark ? AppColors.textArabic : Colors.black87),
                    ),
                  ),
                ],
                if (!hideText && showPhonetic && ayah.phonetic != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    ayah.phonetic!,
                    style: AppTheme.phoneticTextStyle(textSizeMultiplier),
                  ),
                ],
                if (!hideText && showTranslation && ayah.translation != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    ayah.translation!,
                    style: AppTheme.translationTextStyle(textSizeMultiplier, Theme.of(context).brightness),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
