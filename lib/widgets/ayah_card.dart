import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/surah.dart';
import '../theme/app_theme.dart';
import 'tap_scale.dart';

class AyahCard extends StatelessWidget {
  final Ayah ayah;
  final int surahId;
  final bool isPlaying;
  final bool isFavorite;
  final bool isMastered;
  final bool hideText;
  final double textSizeMultiplier;
  final double arabicTextSize;
  final double translationTextSize;
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
    this.surahId = 0,
    this.isPlaying = false,
    this.isFavorite = false,
    this.isMastered = false,
    this.hideText = false,
    this.textSizeMultiplier = 1.0,
    this.arabicTextSize = 1.0,
    this.translationTextSize = 1.0,
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
            ? (isDark ? AppColors.accent.withValues(alpha: 0.1) : AppColors.gradientStart.withValues(alpha: 0.5))
            : isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlaying
              ? AppColors.accent.withValues(alpha: 0.4)
              : isDark ? AppColors.divider.withValues(alpha: 0.5) : AppColors.dividerLight,
          width: isPlaying ? 1.5 : 0.5,
        ),
        boxShadow: isPlaying
            ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.1), blurRadius: 16, spreadRadius: 1)]
            : [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
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
                // ── Header row: verse badge + action icons ──
                Row(
                  children: [
                    // Verse number badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPlaying
                            ? AppColors.accent.withValues(alpha: 0.2)
                            : isDark ? AppColors.surfaceLight : const Color(0xFFF5F0E8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isPlaying
                              ? AppColors.accent.withValues(alpha: 0.4)
                              : isDark ? AppColors.divider : const Color(0xFFE5DDD2),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        '$surahId:${ayah.id}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isPlaying
                              ? AppColors.accent
                              : isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                    if (isMastered) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check, color: AppColors.primary, size: 12),
                      ),
                    ],
                    const Spacer(),
                    // Action icons with micro-animations
                    AnimatedIconAction(
                      icon: Icons.play_circle_outline_rounded,
                      color: isPlaying ? AppColors.accent : (isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
                      pressedColor: AppColors.accent,
                      size: 20,
                      onTap: onTap,
                    ),
                    const SizedBox(width: 4),
                    AnimatedIconAction(
                      icon: isFavorite ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                      color: isFavorite ? AppColors.accent : (isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
                      pressedColor: AppColors.accentLight,
                      size: 20,
                      onTap: onFavoriteTap,
                    ),
                    const SizedBox(width: 4),
                    AnimatedIconAction(
                      icon: isMastered ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isMastered ? AppColors.primary : (isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
                      pressedColor: AppColors.primaryLight,
                      size: 20,
                      onTap: onMasteredTap,
                    ),
                  ],
                ),

                // ── Arabic text ──
                if (showArabic) ...[
                  const SizedBox(height: 16),
                  Text(
                    hideText ? '...' : ayah.text,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: AppTheme.arabicTextStyle(textSizeMultiplier * arabicTextSize).copyWith(
                      color: isPlaying
                          ? (isDark ? AppColors.accentLight : const Color(0xFF2C1F0E))
                          : (isDark ? AppColors.textArabic : const Color(0xFF2C1F0E)),
                    ),
                  ),
                ],

                // ── Phonetic ──
                if (!hideText && showPhonetic && ayah.phonetic != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    ayah.phonetic!,
                    style: AppTheme.phoneticTextStyle(textSizeMultiplier),
                  ),
                ],

                // ── Translation ──
                if (!hideText && showTranslation && ayah.translation != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    ayah.translation!,
                    style: AppTheme.translationTextStyle(textSizeMultiplier * translationTextSize, Theme.of(context).brightness),
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

