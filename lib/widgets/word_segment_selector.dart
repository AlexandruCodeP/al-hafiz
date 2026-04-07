import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Data class representing a selected word segment.
class WordSegment {
  final int startIndex;
  final int endIndex;
  final String text;
  final List<String> allWords;

  const WordSegment({
    required this.startIndex,
    required this.endIndex,
    required this.text,
    required this.allWords,
  });

  int get wordCount => endIndex - startIndex + 1;
}

/// A widget that displays Arabic text word-by-word and allows the user
/// to tap-and-drag to select a contiguous segment of words.
///
/// Selected words get a blue highlight with golden drag handles at each end.
class WordSegmentSelector extends StatefulWidget {
  final String text;
  final TextStyle style;
  final ValueChanged<WordSegment?>? onSelectionChanged;
  final bool enabled;
  final bool hideUnselected;

  const WordSegmentSelector({
    super.key,
    required this.text,
    required this.style,
    this.onSelectionChanged,
    this.enabled = true,
    this.hideUnselected = false,
  });

  @override
  State<WordSegmentSelector> createState() => _WordSegmentSelectorState();
}

class _WordSegmentSelectorState extends State<WordSegmentSelector> {
  late List<String> _words;

  // Selection state: null means nothing selected
  int? _startWord;
  int? _endWord;

  // Drag state
  bool _isDragging = false;
  _DragHandle? _activeHandle;

  // Keys for each word chip to get their positions
  final Map<int, GlobalKey> _wordKeys = {};

  @override
  void initState() {
    super.initState();
    _words = _splitArabicWords(widget.text);
  }

  @override
  void didUpdateWidget(WordSegmentSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _words = _splitArabicWords(widget.text);
      _startWord = null;
      _endWord = null;
      _wordKeys.clear();
    }
  }

  List<String> _splitArabicWords(String text) {
    // Split on spaces, keeping diacritics attached
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  }

  bool get hasSelection => _startWord != null && _endWord != null;

  int get selStart => _startWord! <= _endWord! ? _startWord! : _endWord!;
  int get selEnd => _startWord! <= _endWord! ? _endWord! : _startWord!;

  void _clearSelection() {
    setState(() {
      _startWord = null;
      _endWord = null;
    });
    widget.onSelectionChanged?.call(null);
  }

  void _notifySelection() {
    if (!hasSelection) {
      widget.onSelectionChanged?.call(null);
      return;
    }
    final s = selStart;
    final e = selEnd;
    final selectedWords = _words.sublist(s, e + 1);
    widget.onSelectionChanged?.call(WordSegment(
      startIndex: s,
      endIndex: e,
      text: selectedWords.join(' '),
      allWords: _words,
    ));
  }

  /// Find which word index is at a global position.
  int? _wordAtPosition(Offset globalPos) {
    for (int i = 0; i < _words.length; i++) {
      final key = _wordKeys[i];
      if (key == null) continue;
      final renderObj = key.currentContext?.findRenderObject();
      if (renderObj == null || renderObj is! RenderBox) continue;
      final box = renderObj;
      final localPos = box.globalToLocal(globalPos);
      if (localPos.dx >= 0 &&
          localPos.dx <= box.size.width &&
          localPos.dy >= 0 &&
          localPos.dy <= box.size.height) {
        return i;
      }
    }
    return null;
  }

  /// Find the closest word to a global position (for drag).
  int _closestWord(Offset globalPos) {
    double minDist = double.infinity;
    int closest = 0;
    for (int i = 0; i < _words.length; i++) {
      final key = _wordKeys[i];
      if (key == null) continue;
      final renderObj = key.currentContext?.findRenderObject();
      if (renderObj == null || renderObj is! RenderBox) continue;
      final box = renderObj;
      final center = box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
      final dist = (center - globalPos).distance;
      if (dist < minDist) {
        minDist = dist;
        closest = i;
      }
    }
    return closest;
  }

  void _onTapWord(int index) {
    if (!widget.enabled) return;
    if (hasSelection) {
      // Tap outside selection clears it
      _clearSelection();
    } else {
      // Start selection with a single word
      setState(() {
        _startWord = index;
        _endWord = index;
      });
      _notifySelection();
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.enabled || !hasSelection) return;

    // Check if we're near a handle
    final startKey = _wordKeys[selStart];
    final endKey = _wordKeys[selEnd];

    if (startKey != null && endKey != null) {
      final startBox = startKey.currentContext?.findRenderObject() as RenderBox?;
      final endBox = endKey.currentContext?.findRenderObject() as RenderBox?;

      if (startBox != null && endBox != null) {
        // RTL: start handle is on the right side of the rightmost word
        final startHandlePos = startBox.localToGlobal(
          Offset(startBox.size.width, startBox.size.height / 2),
        );
        final endHandlePos = endBox.localToGlobal(
          Offset(0, endBox.size.height / 2),
        );

        final distStart = (details.globalPosition - startHandlePos).distance;
        final distEnd = (details.globalPosition - endHandlePos).distance;

        const threshold = 40.0;
        if (distStart < threshold || distEnd < threshold) {
          setState(() => _isDragging = true);
          _activeHandle = distStart < distEnd ? _DragHandle.start : _DragHandle.end;
          return;
        }
      }
    }

    // If not on a handle, start a new selection
    final word = _wordAtPosition(details.globalPosition);
    if (word != null) {
      setState(() {
        _isDragging = true;
        _startWord = word;
        _endWord = word;
      });
      _activeHandle = _DragHandle.end;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final word = _closestWord(details.globalPosition);

    setState(() {
      if (_activeHandle == _DragHandle.start) {
        _startWord = word;
      } else {
        _endWord = word;
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isDragging) {
      setState(() => _isDragging = false);
      _activeHandle = null;
      _notifySelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      behavior: HitTestBehavior.translucent,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Wrap(
          alignment: WrapAlignment.start,
          spacing: 5,
          runSpacing: 8,
          children: List.generate(_words.length, (i) {
            _wordKeys.putIfAbsent(i, () => GlobalKey());
            final isSelected = hasSelection && i >= selStart && i <= selEnd;
            final isStart = hasSelection && i == selStart;
            final isEnd = hasSelection && i == selEnd;
            final shouldHide = widget.hideUnselected && hasSelection && !isSelected;

            return GestureDetector(
              onTap: () => _onTapWord(i),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── Word chip ──
                  Container(
                    key: _wordKeys[i],
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                              ? const Color(0xFF1E3A5F).withValues(alpha: 0.6)
                              : const Color(0xFFD6E9FF))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: isSelected
                          ? Border.all(
                              color: isDark
                                  ? const Color(0xFF4A90D9).withValues(alpha: 0.4)
                                  : const Color(0xFF90BEE8),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Text(
                      shouldHide ? '●●●' : _words[i],
                      style: widget.style.copyWith(
                        color: shouldHide
                            ? (isDark ? AppColors.textSecondary : AppColors.textSecondaryLight)
                            : isSelected
                                ? (isDark ? const Color(0xFF8EC4FF) : const Color(0xFF1A5A9E))
                                : null,
                      ),
                    ),
                  ),

                  // ── Start handle (right side in RTL) ──
                  if (isStart)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: _HandleNub(isDark: isDark),
                    ),

                  // ── End handle (left side in RTL) ──
                  if (isEnd)
                    Positioned(
                      bottom: -6,
                      left: -6,
                      child: _HandleNub(isDark: isDark),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

enum _DragHandle { start, end }

/// The small golden circular handle at each end of the selection.
class _HandleNub extends StatelessWidget {
  final bool isDark;
  const _HandleNub({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? AppColors.surface : Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
