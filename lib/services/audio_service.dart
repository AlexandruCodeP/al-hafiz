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
  bool _isLoading = false;
  bool _continuousReading = true; // Feature: basique play follows next

  // A-B Repeat
  Duration? _clipStart;
  Duration? _clipEnd;
  bool _abRepeatActive = false;

  // Callback for automatic next verse
  VoidCallback? onVerseComplete;

  AudioService() {
    _player.positionStream.listen((pos) {
      _position = pos;
      // A-B repeat logic
      if (_abRepeatActive && _clipEnd != null && pos >= _clipEnd!) {
        _player.seek(_clipStart ?? Duration.zero);
      }
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });

    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        if (_continuousReading && onVerseComplete != null) {
          onVerseComplete!();
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

  Future<void> playAyah(int surahId, int ayahId) async {
    try {
      // For per-surah sources, don't reload if same surah is already loaded
      if (isPerSurahSource && _currentSurahId == surahId && _isPlaying) {
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
        await _player.seek(Duration.zero);
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
