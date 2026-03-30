import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_service.dart';

enum HifzState { idle, playingAyah, pauseBetweenReps, pauseBetweenAyahs, completed }

class HifzEngine extends ChangeNotifier {
  final AudioService _audioService;

  HifzState _state = HifzState.idle;
  int _surahId = 1;
  int _rangeStart = 1;
  int _rangeEnd = 1;
  int _repetitionsPerAyah = 3;
  int _rangeLoopCount = 1;
  int _pauseDurationSeconds = 2;

  int _currentAyah = 1;
  int _currentRep = 1;
  int _currentRangeLoop = 1;

  Timer? _pauseTimer;
  StreamSubscription? _playerSub;

  HifzEngine(this._audioService);

  // Getters
  HifzState get state => _state;
  int get surahId => _surahId;
  int get rangeStart => _rangeStart;
  int get rangeEnd => _rangeEnd;
  int get repetitionsPerAyah => _repetitionsPerAyah;
  int get rangeLoopCount => _rangeLoopCount;
  int get pauseDurationSeconds => _pauseDurationSeconds;
  int get currentAyah => _currentAyah;
  int get currentRep => _currentRep;
  int get currentRangeLoop => _currentRangeLoop;
  bool get isActive => _state != HifzState.idle && _state != HifzState.completed;

  // Setters
  void setSurahId(int id) { _surahId = id; notifyListeners(); }
  void setRange(int start, int end) {
    _rangeStart = start;
    _rangeEnd = end;
    notifyListeners();
  }
  void setRepetitionsPerAyah(int reps) { _repetitionsPerAyah = reps.clamp(1, 20); notifyListeners(); }
  void setRangeLoopCount(int count) { _rangeLoopCount = count.clamp(1, 10); notifyListeners(); }
  void setPauseDuration(int seconds) { _pauseDurationSeconds = seconds.clamp(0, 10); notifyListeners(); }

  Future<void> startSession() async {
    _currentAyah = _rangeStart;
    _currentRep = 1;
    _currentRangeLoop = 1;

    _listenToCompletion();
    _state = HifzState.playingAyah;
    notifyListeners();

    await _audioService.playAyah(_surahId, _currentAyah);
  }

  void _listenToCompletion() {
    _playerSub?.cancel();
    _playerSub = _audioService.player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed &&
          _state == HifzState.playingAyah) {
        _onAyahComplete();
      }
    });
  }

  void _onAyahComplete() {
    if (_currentRep < _repetitionsPerAyah) {
      // More reps needed
      _currentRep++;
      _state = HifzState.pauseBetweenReps;
      notifyListeners();
      _schedulePause(() async {
        _state = HifzState.playingAyah;
        notifyListeners();
        await _audioService.playAyah(_surahId, _currentAyah);
      });
    } else if (_currentAyah < _rangeEnd) {
      // Next ayah
      _currentAyah++;
      _currentRep = 1;
      _state = HifzState.pauseBetweenAyahs;
      notifyListeners();
      _schedulePause(() async {
        _state = HifzState.playingAyah;
        notifyListeners();
        await _audioService.playAyah(_surahId, _currentAyah);
      });
    } else if (_currentRangeLoop < _rangeLoopCount) {
      // Restart range
      _currentRangeLoop++;
      _currentAyah = _rangeStart;
      _currentRep = 1;
      _state = HifzState.pauseBetweenAyahs;
      notifyListeners();
      _schedulePause(() async {
        _state = HifzState.playingAyah;
        notifyListeners();
        await _audioService.playAyah(_surahId, _currentAyah);
      });
    } else {
      // All done
      _state = HifzState.completed;
      notifyListeners();
    }
  }

  void _schedulePause(Future<void> Function() onResume) {
    _pauseTimer?.cancel();
    if (_pauseDurationSeconds == 0) {
      onResume();
    } else {
      _pauseTimer = Timer(Duration(seconds: _pauseDurationSeconds), () {
        onResume();
      });
    }
  }

  void stopSession() {
    _pauseTimer?.cancel();
    _playerSub?.cancel();
    _audioService.stop();
    _state = HifzState.idle;
    _currentAyah = _rangeStart;
    _currentRep = 1;
    _currentRangeLoop = 1;
    notifyListeners();
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    _playerSub?.cancel();
    super.dispose();
  }
}

