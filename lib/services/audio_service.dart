import 'dart:convert';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  /// Load an ayah's audio without starting playback.
  /// Returns true if the audio source is ready.
  Future<bool> _loadAyahSilently(int surahId, int ayahId, [int? totalVerses]) async {
    try {
      if (totalVerses != null) _currentSurahTotalVerses = totalVerses;
      _currentSurahId = surahId;
      _currentAyahId = ayahId;
      clearClip();

      if (isPerSurahSource) {
        _playlist = null;
        _playlistSurahId = null;
        _isLoading = true;
        notifyListeners();

        final url = _buildAudioUrl(surahId, ayahId);
        await _player.setUrl(url);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      // Per-ayah: reuse existing playlist if same surah
      if (_playlistSurahId == surahId && _playlist != null) {
        final index = ayahId - 1;
        // Pause first, then seek to the track start
        if (_isPlaying) await _player.pause();
        await _player.seek(Duration.zero, index: index);
        notifyListeners();
        return true;
      }

      // Build new playlist
      _isLoading = true;
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
      return true;
    } catch (e) {
      _isLoading = false;
      debugPrint('Error loading ayah: $e');
      notifyListeners();
      return false;
    }
  }

  // ── Word-level timing cache: "recitationId:surahId:ayahId" → segments ──
  final Map<String, List<List<int>>> _segmentCache = {};

  /// Fetch word-level timing segments from Quran.com API.
  /// Returns a list of [wordIndex0, wordIndex1, startMs, endMs] per word,
  /// or null if unavailable.
  Future<List<List<int>>?> _fetchSegments(int recitationId, int surahId, int ayahId) async {
    final key = '$recitationId:$surahId:$ayahId';
    if (_segmentCache.containsKey(key)) return _segmentCache[key];

    try {
      final url = 'https://api.quran.com/api/v4/recitations/$recitationId'
          '/by_ayah/$surahId:$ayahId?fields=segments';
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      final files = json['audio_files'] as List?;
      if (files == null || files.isEmpty) return null;

      final rawSegments = files[0]['segments'] as List?;
      if (rawSegments == null || rawSegments.isEmpty) return null;

      final segments = rawSegments
          .map((s) => (s as List).map((e) => (e as num).toInt()).toList())
          .toList();

      _segmentCache[key] = segments;
      return segments;
    } catch (e) {
      debugPrint('AudioService: failed to fetch segments: $e');
      return null;
    }
  }

  /// Play only a segment of words within a verse.
  ///
  /// Tries to use real word-level timestamps from the Quran.com API.
  /// Falls back to proportional estimation if unavailable.
  Future<void> playSegment({
    required int surahId,
    required int ayahId,
    required int startWordIndex,
    required int endWordIndex,
    required List<String> allWords,
    int? totalVerses,
  }) async {
    if (_isPlaying) await _player.pause();

    final loaded = await _loadAyahSilently(surahId, ayahId, totalVerses);
    if (!loaded) return;

    // Wait for the duration to become available
    Duration dur = _duration;
    if (dur == Duration.zero) {
      final d = await _player.durationStream
          .where((d) => d != null && d > Duration.zero)
          .first
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      if (d == null || d == Duration.zero) {
        await _player.play();
        return;
      }
      dur = d;
    }

    final totalMs = dur.inMilliseconds.toDouble();

    // ── Try real timestamps from Quran.com API ──
    final recitationId = _currentReciter.quranComRecitationId;
    List<List<int>>? segments;
    if (recitationId != null) {
      segments = await _fetchSegments(recitationId, surahId, ayahId);
    }

    double clipStartMs;
    double clipEndMs;

    if (segments != null && segments.length >= allWords.length) {
      // API segments format: [word0idx, word1idx, startMs, endMs]
      final si = startWordIndex.clamp(0, segments.length - 1);
      final ei = endWordIndex.clamp(0, segments.length - 1);
      clipStartMs = segments[si][2].toDouble();
      clipEndMs = segments[ei][3].toDouble();
    } else {
      // ── Fallback: proportional estimation ──
      clipStartMs = _estimateWordStart(startWordIndex, allWords, totalMs);
      clipEndMs = _estimateWordEnd(endWordIndex, allWords, totalMs);
    }

    // Tiny margin (30ms) to avoid cutting off the first/last phoneme
    clipStartMs = (clipStartMs - 30).clamp(0.0, totalMs);
    clipEndMs = (clipEndMs + 30).clamp(0.0, totalMs);

    final clipStart = Duration(milliseconds: clipStartMs.round());
    final clipEnd = Duration(milliseconds: clipEndMs.round());

    setClip(clipStart, clipEnd);
    await _player.seek(clipStart);
    await _player.play();
  }

  double _estimateWordStart(int wordIndex, List<String> allWords, double totalMs) {
    final wordLengths = allWords.map((w) => _stripTashkeel(w).runes.length.toDouble()).toList();
    final totalChars = wordLengths.fold(0.0, (a, b) => a + b);
    if (totalChars == 0) return 0;

    double cumul = 0;
    final idx = wordIndex.clamp(0, wordLengths.length - 1);
    for (int i = 0; i < idx; i++) {
      cumul += wordLengths[i];
    }
    return (cumul / totalChars) * totalMs;
  }

  double _estimateWordEnd(int wordIndex, List<String> allWords, double totalMs) {
    final wordLengths = allWords.map((w) => _stripTashkeel(w).runes.length.toDouble()).toList();
    final totalChars = wordLengths.fold(0.0, (a, b) => a + b);
    if (totalChars == 0) return totalMs;

    double cumul = 0;
    final idx = wordIndex.clamp(0, wordLengths.length - 1);
    for (int i = 0; i <= idx; i++) {
      cumul += wordLengths[i];
    }
    return (cumul / totalChars) * totalMs;
  }

  static String _stripTashkeel(String text) {
    return text.replaceAll(RegExp(r'[\u064B-\u065F\u0640\u0670]'), '');
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
