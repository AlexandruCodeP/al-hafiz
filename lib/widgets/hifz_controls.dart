import 'package:flutter/material.dart';
import '../services/hifz_engine.dart';
import '../theme/app_theme.dart';

class HifzControls extends StatelessWidget {
  final HifzEngine hifzEngine;
  final int totalVerses;

  const HifzControls({
    super.key,
    required this.hifzEngine,
    required this.totalVerses,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: hifzEngine,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : AppColors.surfaceLightT,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.divider : AppColors.dividerLight,
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.primary.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_stories_rounded,
                      color: AppColors.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Hifz Session',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (hifzEngine.isActive)
                      _StatusBadge(state: hifzEngine.state),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Range selection
                    _ControlRow(
                      label: 'Ayah Range',
                      child: Row(
                        children: [
                          _CompactDropdown(
                            value: hifzEngine.rangeStart,
                            items: List.generate(
                              totalVerses,
                              (i) => i + 1,
                            ),
                            onChanged: (v) {
                              if (v != null) {
                                hifzEngine.setRange(
                                  v,
                                  v > hifzEngine.rangeEnd
                                      ? v
                                      : hifzEngine.rangeEnd,
                                );
                              }
                            },
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: AppColors.textSecondary,
                              size: 16,
                            ),
                          ),
                          _CompactDropdown(
                            value: hifzEngine.rangeEnd,
                            items: List.generate(
                              totalVerses - hifzEngine.rangeStart + 1,
                              (i) => hifzEngine.rangeStart + i,
                            ),
                            onChanged: (v) {
                              if (v != null) {
                                hifzEngine.setRange(hifzEngine.rangeStart, v);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Repetitions per ayah
                    _SliderControl(
                      label: 'Repetitions / Ayah',
                      value: hifzEngine.repetitionsPerAyah,
                      min: 1,
                      max: 20,
                      onChanged: (v) => hifzEngine.setRepetitionsPerAyah(v),
                    ),
                    const SizedBox(height: 12),
                    // Range loop count
                    _SliderControl(
                      label: 'Range Loops',
                      value: hifzEngine.rangeLoopCount,
                      min: 1,
                      max: 10,
                      onChanged: (v) => hifzEngine.setRangeLoopCount(v),
                    ),
                    const SizedBox(height: 12),
                    // Pause duration
                    _SliderControl(
                      label: 'Pause (seconds)',
                      value: hifzEngine.pauseDurationSeconds,
                      min: 0,
                      max: 10,
                      onChanged: (v) => hifzEngine.setPauseDuration(v),
                    ),
                    const SizedBox(height: 20),
                    // Start / Stop button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: hifzEngine.isActive
                          ? OutlinedButton.icon(
                              onPressed: hifzEngine.stopSession,
                              icon: const Icon(Icons.stop_rounded),
                              label: const Text('Stop Session'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: hifzEngine.startSession,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Start Hifz Session'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                    ),
                    if (hifzEngine.state == HifzState.completed) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.accent,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Session Complete! MashaAllah',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ControlRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _ControlRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        child,
      ],
    );
  }
}

class _SliderControl extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _SliderControl({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$value',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => onChanged(v.toInt()),
          ),
        ),
      ],
    );
  }
}

class _CompactDropdown extends StatelessWidget {
  final int value;
  final List<int> items;
  final ValueChanged<int?> onChanged;

  const _CompactDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButton<int>(
        value: items.contains(value) ? value : items.first,
        items: items
            .map((i) => DropdownMenuItem(
                  value: i,
                  child: Text(
                    '$i',
                    style: const TextStyle(fontSize: 13),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
        underline: const SizedBox.shrink(),
        isDense: true,
        dropdownColor: AppColors.surface,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final HifzState state;

  const _StatusBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      HifzState.playingAyah => ('Playing', AppColors.primary),
      HifzState.pauseBetweenReps => ('Pause', AppColors.accent),
      HifzState.pauseBetweenAyahs => ('Next Ayah', AppColors.accent),
      HifzState.completed => ('Done', AppColors.accent),
      HifzState.idle => ('Idle', AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
