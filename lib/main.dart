import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'services/location_service.dart';
import 'services/task_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Running Supporter for Android',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const MyHomePage(title: 'Running Supporter for Android'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedInterval = 100;
  bool _isRunning = false;
  int _elapsedSeconds = 0;

  final LocationService _locationService = LocationService();
  double _totalDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _initForegroundTask();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    super.dispose();
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'running_supporter',
        channelName: 'ランニング計測',
        channelDescription: 'ランニングの距離計測中の通知',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  void _onReceiveTaskData(Object data) {
    if (data is Map) {
      setState(() {
        _totalDistance = (data['distance'] as num).toDouble();
        _elapsedSeconds = data['seconds'] as int;
      });
    }
  }

  void _selectInterval(int interval) {
    setState(() {
      _selectedInterval = interval;
    });
  }

  Future<void> _startTimer() async {
    setState(() {
      _isRunning = true;
    });

    final hasPermission = await _locationService.checkAndRequestPermission();
    if (!hasPermission) {
      setState(() {
        _isRunning = false;
      });
      return;
    }

    await FlutterForegroundTask.saveData(key: 'interval', value: _selectedInterval);
    
    setState(() {
      _elapsedSeconds = 0;
      _totalDistance = 0.0;
    });

    await FlutterForegroundTask.startService(
      serviceTypes: [
        ForegroundServiceTypes.location,
      ],
      notificationTitle: 'ランニング計測中',
      notificationText: '計測を開始しました',
      callback: startCallback,
    );
  }

  void _stopTimer() async {
    await FlutterForegroundTask.stopService();
    setState(() {
      _isRunning = false;
      _elapsedSeconds = 0;
      _totalDistance = 0.0;
    });
  }

  Future<void> _toggleTimer() async {
    if (_isRunning) {
      _stopTimer();
    } else {
      await _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                const Text(
                  '距離',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black),
                    children: [
                      TextSpan(
                        text: (_totalDistance / 1000).toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const TextSpan(
                        text: ' km',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                const Text(
                  '経過時間',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTime(_elapsedSeconds),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'アナウンス間隔',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildIntervalButton(50)),
                    const SizedBox(width: 6),
                    Expanded(child: _buildIntervalButton(100)),
                    const SizedBox(width: 6),
                    Expanded(child: _buildIntervalButton(200)),
                    const SizedBox(width: 6),
                    Expanded(child: _buildIntervalButton(500)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _toggleTimer,
                icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
                label: Text(
                  _isRunning ? 'ストップ' : 'スタート',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRunning ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalButton(int interval) {
    final isSelected = _selectedInterval == interval;
    
    if (isSelected) {
      return ElevatedButton(
        onPressed: _isRunning ? null : () => _selectInterval(interval),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        child: Text('${interval}m'),
      );
    } else {
      return OutlinedButton(
        onPressed: _isRunning ? null : () => _selectInterval(interval),
        child: Text('${interval}m'),
      );
    }
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