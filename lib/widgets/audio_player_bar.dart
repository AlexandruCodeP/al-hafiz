import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../services/audio_service.dart';
import '../services/hifz_engine.dart';
import '../theme/app_theme.dart';

class AudioPlayerBar extends StatelessWidget {
  final String? surahName;
  final int? ayahNumber;
  final int totalVerses;
  final int? displayedSurahId;
  final VoidCallback? onExpandHifz;

  const AudioPlayerBar({
    super.key,
    this.surahName,
    this.ayahNumber,
    required this.totalVerses,
    this.displayedSurahId,
    this.onExpandHifz,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AudioService, HifzEngine>(
      builder: (context, audio, hifz, _) {
        if (audio.currentSurahId == null) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : AppColors.surfaceLightT,
            border: Border(
              top: BorderSide(
                color: (isDark ? AppColors.divider : AppColors.dividerLight).withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: audio.abRepeatActive
                        ? AppColors.accent
                        : AppColors.primary,
                    inactiveTrackColor: isDark ? AppColors.surfaceLight : AppColors.dividerLight,
                    thumbColor: audio.abRepeatActive
                        ? AppColors.accent
                        : AppColors.primaryLight,
                  ),
                  child: Slider(
                    value: audio.duration.inMilliseconds > 0
                        ? audio.position.inMilliseconds
                            .clamp(0, audio.duration.inMilliseconds)
                            .toDouble()
                        : 0,
                    max: audio.duration.inMilliseconds > 0
                        ? audio.duration.inMilliseconds.toDouble()
                        : 1,
                    onChanged: (value) {
                      audio.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
                // Time labels
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(audio.position),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (hifz.isActive)
                        _HifzBadge(hifz: hifz),
                      Text(
                        _formatDuration(audio.duration),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Hifz controls toggle
                      IconButton(
                        icon: Icon(
                          Icons.repeat_rounded,
                          color: hifz.isActive
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          size: 22,
                        ),
                        onPressed: onExpandHifz,
                        tooltip: 'Hifz Controls',
                      ),
                      // A-B repeat
                      IconButton(
                        icon: Icon(
                          Icons.looks_rounded,
                          color: audio.abRepeatActive
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          size: 22,
                        ),
                        onPressed: audio.toggleAbRepeat,
                        tooltip: 'A-B Repeat',
                      ),
                      const SizedBox(width: 8),
                      // Previous
                      _ControlButton(
                        icon: Icons.skip_previous_rounded,
                        size: 32,
                        onPressed: () {
                          if (audio.currentAyahId != null &&
                              audio.currentAyahId! > 1) {
                            audio.playAyah(
                              audio.currentSurahId!,
                              audio.currentAyahId! - 1,
                              totalVerses,
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      // Play/Pause
                      _PlayPauseButton(
                        isPlaying: audio.isPlaying,
                        isLoading: audio.isLoading,
                        onPressed: () {
                          // If the displayed surah differs from the playing one,
                          // start playing the displayed surah from verse 1
                          if (displayedSurahId != null &&
                              audio.currentSurahId != displayedSurahId &&
                              !audio.isPlaying) {
                            audio.playAyah(displayedSurahId!, 1, totalVerses);
                          } else {
                            audio.togglePlayPause();
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      // Next
                      _ControlButton(
                        icon: Icons.skip_next_rounded,
                        size: 32,
                        onPressed: () {
                          if (audio.currentAyahId != null &&
                              audio.currentAyahId! < totalVerses) {
                            audio.playAyah(
                              audio.currentSurahId!,
                              audio.currentAyahId! + 1,
                              totalVerses,
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      // Loop mode
                      IconButton(
                        icon: const Icon(
                          Icons.loop_rounded,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                        onPressed: () {
                          // Toggle single loop
                          audio.setLoopMode(
                            audio.player.loopMode == LoopMode.one
                                ? LoopMode.off
                                : LoopMode.one,
                          );
                        },
                        tooltip: 'Loop',
                      ),
                      // Stop (if hifz active)
                      if (hifz.isActive)
                        IconButton(
                          icon: const Icon(
                            Icons.stop_rounded,
                            color: AppColors.error,
                            size: 22,
                          ),
                          onPressed: hifz.stopSession,
                          tooltip: 'Stop Session',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPressed;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      key: ValueKey(isPlaying),
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.size,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: size),
      color: AppColors.textPrimary,
      onPressed: onPressed,
    );
  }
}

class _HifzBadge extends StatelessWidget {
  final HifzEngine hifz;

  const _HifzBadge({required this.hifz});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        'Rep ${hifz.currentRep}/${hifz.repetitionsPerAyah} · Ayah ${hifz.currentAyah}',
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
