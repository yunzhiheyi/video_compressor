import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void foregroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(CompressionTaskHandler());
}

class CompressionTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[ForegroundService] Task started');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Keep alive - just maintain the foreground service
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('[ForegroundService] Task destroyed, isTimeout: $isTimeout');
  }

  @override
  void onReceiveData(Object data) {
    debugPrint('[ForegroundService] Received data: $data');
    if (data is Map<String, dynamic>) {
      final progress = data['progress'];
      final taskName = data['taskName'];
      if (progress != null && taskName != null) {
        final percentage = ((progress as num) * 100).toStringAsFixed(0);
        FlutterForegroundTask.updateService(
          notificationText: 'Compressing: $taskName ($percentage%)',
        );
      }
    }
  }
}

class ForegroundService {
  static final ForegroundService _instance = ForegroundService._internal();
  factory ForegroundService() => _instance;
  ForegroundService._internal();

  bool _isRunning = false;
  int _taskCount = 0;

  bool get isRunning => _isRunning;

  static void initCommunicationPort() {
    FlutterForegroundTask.initCommunicationPort();
  }

  Future<void> init() async {
    if (!Platform.isAndroid) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'video_compression',
        channelName: 'Video Compression',
        channelDescription: 'Video compression in progress',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
      ),
    );
  }

  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;

    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    return true;
  }

  Future<void> startCompression(String taskName) async {
    if (!Platform.isAndroid) return;

    _taskCount++;

    if (!_isRunning) {
      _isRunning = true;

      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.restartService();
      } else {
        await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: 'Video Compressor',
          notificationText: 'Compressing: $taskName',
          callback: foregroundTaskCallback,
        );
      }

      debugPrint(
          '[ForegroundService] Started foreground service for: $taskName');
    } else {
      await updateProgress(taskName, 0);
    }
  }

  Future<void> updateProgress(String taskName, double progress) async {
    if (!Platform.isAndroid || !_isRunning) return;

    final percentage = (progress * 100).toStringAsFixed(0);
    await FlutterForegroundTask.updateService(
      notificationText: 'Compressing: $taskName ($percentage%)',
    );

    FlutterForegroundTask.sendDataToTask({
      'progress': progress,
      'taskName': taskName,
    });
  }

  Future<void> completeTask() async {
    if (!Platform.isAndroid) return;

    _taskCount--;

    if (_taskCount <= 0) {
      _taskCount = 0;
      await stopCompression();
    }
  }

  Future<void> stopCompression() async {
    if (!Platform.isAndroid || !_isRunning) return;

    _isRunning = false;
    _taskCount = 0;

    await FlutterForegroundTask.stopService();
    debugPrint('[ForegroundService] Stopped foreground service');
  }
}
