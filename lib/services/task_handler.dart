import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';
import 'tts_service.dart';

// Foreground Service が起動された時に呼ばれるエントリーポイント
@pragma('vm:entry-point')
void startCallback() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(RunningTaskHandler());
}

class RunningTaskHandler extends TaskHandler {
  final LocationService _locationService = LocationService();
  final TtsService _ttsService = TtsService();
  
  int _elapsedSeconds = 0;
  double _totalDistance = 0.0;
  Position? _lastPosition;
  int _lastAnnouncedDistance = 0;
  int _interval = 100;

  // サービス起動時に1度だけ呼ばれる
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // UI側から受け取った設定(間隔)を読み込む
    final data = await FlutterForegroundTask.getData<int>(key: 'interval');
    if (data != null) {
      _interval = data;
    }
    
    // 初期位置を取得
    final initialPosition = await _locationService.getCurrentPosition();
    if (initialPosition != null) {
      _lastPosition = initialPosition;
    }
    
    // スタートとアナウンス
    await _ttsService.speak('スタート');
  }

  // 設定された間隔(後述)で繰り返し呼ばれる(今回は1秒ごと)
  @override
  void onRepeatEvent(DateTime timestamp) async {
    _elapsedSeconds++;
    
    final currentPosition = await _locationService.getCurrentPosition();
    if (currentPosition != null && _lastPosition != null) {
      final distance = _locationService.calculateDistance(
        _lastPosition!,
        currentPosition,
      );
      _totalDistance += distance;
      _lastPosition = currentPosition;
      
      // アナウンス判定
      final nextAnnouncement = _lastAnnouncedDistance + _interval;
      if (_totalDistance >= nextAnnouncement) {
        _lastAnnouncedDistance = nextAnnouncement;
        _ttsService.speakDistance(nextAnnouncement);
      }
    }
    
    // UIに状態を送る
    FlutterForegroundTask.sendDataToMain({
      'distance': _totalDistance,
      'seconds': _elapsedSeconds,
    });
    
    // 通知の表示も更新
    final km = (_totalDistance / 1000).toStringAsFixed(2);
    final time = _formatTime(_elapsedSeconds);
    FlutterForegroundTask.updateService(
      notificationTitle: '計測中: $km km',
      notificationText: '経過時間: $time',
    );
  }

  // サービス停止時に呼ばれる
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _ttsService.stop();
  }

  String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    
    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    
    return '$hh:$mm:$ss';
  }
}