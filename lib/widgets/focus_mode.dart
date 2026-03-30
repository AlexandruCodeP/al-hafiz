import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FocusMode extends StatelessWidget {
  final bool isActive;
  final int? playingAyahId;
  final Widget child;

  const FocusMode({
    super.key,
    required this.isActive,
    required this.playingAyahId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) return child;
    return child;
  }
}

/// Wraps an AyahCard to blur it when focus mode is active and it's not the playing ayah.
class FocusModeAyahWrapper extends StatefulWidget {
  final bool focusModeActive;
  final bool isPlayingAyah;
  final Widget child;

  const FocusModeAyahWrapper({
    super.key,
    required this.focusModeActive,
    required this.isPlayingAyah,
    required this.child,
  });

  @override
  State<FocusModeAyahWrapper> createState() => _FocusModeAyahWrapperState();
}

class _FocusModeAyahWrapperState extends State<FocusModeAyahWrapper> {
  bool _revealed = false;

  @override
  void didUpdateWidget(FocusModeAyahWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset revealed state when focus mode toggles or playing ayah changes
    if (widget.focusModeActive != oldWidget.focusModeActive ||
        widget.isPlayingAyah != oldWidget.isPlayingAyah) {
      _revealed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.focusModeActive || widget.isPlayingAyah) {
      return widget.child;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _revealed = !_revealed;
        });
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _revealed
            ? widget.child
            : ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Blurred content
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: widget.child,
                    ),
                    // Overlay with tap hint
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility_off_rounded,
                                color: AppColors.textSecondary,
                                size: 24,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Tap to reveal',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Toggle button for focus mode in the app bar
class FocusModeToggle extends StatelessWidget {
  final bool isActive;
  final VoidCallback onToggle;

  const FocusModeToggle({
    super.key,
    required this.isActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          key: ValueKey(isActive),
          color: isActive ? AppColors.accent : AppColors.textSecondary,
        ),
      ),
      tooltip: isActive ? 'Disable Focus Mode' : 'Enable Focus Mode',
      onPressed: onToggle,
    );
  }
}
