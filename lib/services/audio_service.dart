import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../models/reciter.dart';

class AudioService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  Reciter _currentReciter = Reciter.all.first;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  int? _currentSurahId;
  int? _currentAyahId;
  int _currentSurahTotalVerses = 0;
  bool _isLoading = false;
  bool _continuousReading = true;

  // Playlist for gapless per-ayah playback
  ConcatenatingAudioSource? _playlist;
  int? _playlistSurahId;

  // A-B Repeat
  Duration? _clipStart;
  Duration? _clipEnd;
  bool _abRepeatActive = false;

  // Callback for UI updates (e.g. scroll to verse)
  VoidCallback? onVerseComplete;

  AudioService() {
    _player.positionStream.listen((pos) {
      _position = pos;
      if (_abRepeatActive && _clipEnd != null && pos >= _clipEnd!) {
        _player.seek(_clipStart ?? Duration.zero);
      }
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });

    // Track verse changes in playlist mode
    _player.currentIndexStream.listen((index) {
      if (index != null && _playlist != null && _playlistSurahId != null) {
        final newAyahId = index + 1;
        if (_currentAyahId != null && _currentAyahId != newAyahId) {
          _currentAyahId = newAyahId;
          onVerseComplete?.call();
          notifyListeners();
        } else {
          _currentAyahId = newAyahId;
        }
      }
    });

    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        // For single-source (per-surah) mode, handle next verse manually
        if (_playlist == null && _continuousReading && _currentAyahId != null && _currentAyahId! < _currentSurahTotalVerses) {
          final nextAyah = _currentAyahId! + 1;
          playAyah(_currentSurahId!, nextAyah, _currentSurahTotalVerses);
          onVerseComplete?.call();
          return;
        }
      }
      notifyListeners();
    });
  }

  // Getters
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  int? get currentSurahId => _currentSurahId;
  int? get currentAyahId => _currentAyahId;
  bool get abRepeatActive => _abRepeatActive;
  Duration? get clipStart => _clipStart;
  Duration? get clipEnd => _clipEnd;
  AudioPlayer get player => _player;
  bool get continuousReading => _continuousReading;
  Reciter get currentReciter => _currentReciter;

  set continuousReading(bool value) {
    _continuousReading = value;
    notifyListeners();
  }

  void setReciter(Reciter reciter) {
    _currentReciter = reciter;
    notifyListeners();
  }

  String _buildAudioUrl(int surahId, int ayahId) {
    final surah = surahId.toString().padLeft(3, '0');
    if (_currentReciter.source == ReciterSource.mp3quran) {
      final base = _currentReciter.baseUrl ?? 'https://server10.mp3quran.net';
      return '$base/${_currentReciter.folder}/$surah.mp3';
    }
    final ayah = ayahId.toString().padLeft(3, '0');
    return 'https://www.everyayah.com/data/${_currentReciter.folder}/$surah$ayah.mp3';
  }

  /// Whether the current reciter provides audio per-surah (not per-ayah)
  bool get isPerSurahSource => _currentReciter.source == ReciterSource.mp3quran;

  Future<void> playAyah(int surahId, int ayahId, [int? totalVerses]) async {
    try {
      if (totalVerses != null) _currentSurahTotalVerses = totalVerses;

      // ── Per-surah sources: single file, no playlist needed ──
      if (isPerSurahSource) {
        _playlist = null;
        _playlistSurahId = null;

        if (_currentSurahId == surahId && _isPlaying) {
          _currentAyahId = ayahId;
          notifyListeners();
          return;
        }

        _isLoading = true;
        _currentSurahId = surahId;
        _currentAyahId = ayahId;
        clearClip();
        notifyListeners();

        final url = _buildAudioUrl(surahId, ayahId);
        await _player.setUrl(url);
        _isLoading = false;
        notifyListeners();
        await _player.play();
        return;
      }

      // ── Per-ayah sources: gapless playlist ──
      _currentSurahId = surahId;
      _currentAyahId = ayahId;

      // If same surah already loaded as playlist, just seek to the right track
      if (_playlistSurahId == surahId && _playlist != null) {
        final index = ayahId - 1;
        await _player.seek(Duration.zero, index: index);
        if (!_isPlaying) await _player.play();
        notifyListeners();
        return;
      }

      // Build new playlist with all verses
      _isLoading = true;
      clearClip();
      notifyListeners();

      final sources = <AudioSource>[];
      for (int i = 1; i <= _currentSurahTotalVerses; i++) {
        sources.add(AudioSource.uri(Uri.parse(_buildAudioUrl(surahId, i))));
      }

      _playlist = ConcatenatingAudioSource(children: sources);
      _playlistSurahId = surahId;

      await _player.setAudioSource(_playlist!, initialIndex: ayahId - 1);
      _isLoading = false;
      notifyListeners();
      await _player.play();
    } catch (e) {
      _isLoading = false;
      debugPrint('Error playing ayah: $e');
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero, index: 0);
      }
      await _player.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
    _playlist = null;
    _playlistSurahId = null;
    notifyListeners();
  }

  // A-B Repeat
  void setClip(Duration start, Duration end) {
    _clipStart = start;
    _clipEnd = end;
    _abRepeatActive = true;
    notifyListeners();
  }

  void clearClip() {
    _clipStart = null;
    _clipEnd = null;
    _abRepeatActive = false;
    notifyListeners();
  }

  void toggleAbRepeat() {
    if (_abRepeatActive) {
      clearClip();
    } else if (_duration > Duration.zero) {
      setClip(Duration.zero, _duration);
    }
  }

  /// Play only a segment of words within a verse.
  ///
  /// Estimates word-level timing by proportional character length,
  /// then uses A-B repeat to loop just that portion.
  Future<void> playSegment({
    required int surahId,
    required int ayahId,
    required int startWordIndex,
    required int endWordIndex,
    required List<String> allWords,
    int? totalVerses,
  }) async {
    // First, make sure the ayah is loaded
    await playAyah(surahId, ayahId, totalVerses);

    // Wait for the duration to be available
    Duration? dur = _duration;
    if (dur == Duration.zero) {
      // Listen for the first non-zero duration
      dur = await _player.durationStream
          .where((d) => d != null && d > Duration.zero)
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
    }

    if (dur == null || dur == Duration.zero) return;

    // Estimate word timings proportionally by character count
    // (Arabic diacritics are lightweight, base chars carry the weight)
    final wordLengths = allWords.map((w) => w.runes.length.toDouble()).toList();
    final totalChars = wordLengths.fold(0.0, (a, b) => a + b);
    if (totalChars == 0) return;

    final totalMs = dur.inMilliseconds.toDouble();
    double cumulMs = 0;
    final wordStarts = <double>[];
    final wordEnds = <double>[];

    for (int i = 0; i < wordLengths.length; i++) {
      wordStarts.add(cumulMs);
      cumulMs += (wordLengths[i] / totalChars) * totalMs;
      wordEnds.add(cumulMs);
    }

    // Add a small margin (100ms) before/after for smoother clipping
    final clipStartMs = (wordStarts[startWordIndex] - 100).clamp(0, totalMs);
    final clipEndMs = (wordEnds[endWordIndex] + 100).clamp(0, totalMs);

    final clipStart = Duration(milliseconds: clipStartMs.round());
    final clipEnd = Duration(milliseconds: clipEndMs.round());

    // Seek to clip start and set A-B repeat
    await _player.seek(clipStart);
    setClip(clipStart, clipEnd);
  }

  Future<void> setLoopMode(LoopMode mode) async {
    await _player.setLoopMode(mode);
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
