import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    await _flutterTts.setLanguage('ja-JP');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    await init();
    await _flutterTts.speak(text);
  }

  Future<void> speakDistance(int meters) async {
    if (meters >= 1000) {
      final km = meters / 1000;
      if (km == km.toInt()) {
        await speak('${km.toInt()}キロメートル');
      } else {
        await speak('${km.toStringAsFixed(1)}キロメートル');
      }
    } else {
      await speak('$metersメートル');
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}