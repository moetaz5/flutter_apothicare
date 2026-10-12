import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceGuidanceService {
  static final VoiceGuidanceService _instance = VoiceGuidanceService._internal();
  factory VoiceGuidanceService() => _instance;
  VoiceGuidanceService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isEnabled = true;
  String _lastSpokenText = '';
  DateTime? _lastSpokenTime;

  bool get isEnabled => _isEnabled;
  bool get isMuted => !_isEnabled;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      if (Platform.isIOS) {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
        );
      }

      // Default language to French
      await _flutterTts.setLanguage('fr-FR');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _isInitialized = true;
      debugPrint('[VoiceGuidance] TTS initialized successfully');
    } catch (e) {
      debugPrint('[VoiceGuidance] TTS init warning: $e');
    }
  }

  void setMuted(bool muted) {
    _isEnabled = !muted;
    if (muted) {
      stop();
    }
  }

  Future<void> speak(String text, {bool force = false}) async {
    if (!_isEnabled) return;
    if (text.trim().isEmpty) return;

    final cleanText = _cleanInstruction(text);
    if (cleanText.isEmpty) return;

    // Deduplicate speech within 15 seconds unless forced
    final now = DateTime.now();
    if (!force && _lastSpokenText == cleanText && _lastSpokenTime != null) {
      if (now.difference(_lastSpokenTime!).inSeconds < 15) {
        return;
      }
    }

    _lastSpokenText = cleanText;
    _lastSpokenTime = now;

    try {
      await _flutterTts.stop();
      await _flutterTts.speak(cleanText);
      debugPrint('[VoiceGuidance] Speaking: "$cleanText"');
    } catch (e) {
      debugPrint('[VoiceGuidance] Speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  String _cleanInstruction(String input) {
    // Remove HTML tags
    String result = input.replaceAll(RegExp(r'<[^>]*>'), ' ');
    // Remove duplicate whitespace
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Replace arrow symbols with spoken French words
    result = result.replaceAll('➔', 'puis');
    result = result.replaceAll('->', 'puis');
    return result;
  }
}
