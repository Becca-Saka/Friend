import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart';

@pragma('vm:entry-point')
void _startForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_ForegroundFirstTaskHandler());
}

class _ForegroundFirstTaskHandler extends TaskHandler {
  @override
  void onStart(DateTime timestamp) async {
    print("Starting foreground task");
  }

  Future locationInBackground() async {
    if (await Geolocator.isLocationServiceEnabled()) {
      if (await Geolocator.checkPermission() == LocationPermission.always) {
        var locationData = await Geolocator.getCurrentPosition();
        Object loc = {
          "latitude": locationData.latitude,
          "longitude": locationData.longitude,
          'altitude': locationData.altitude,
          'accuracy': locationData.accuracy,
          'time': locationData.timestamp.toIso8601String(),
        };
        print('Location data: $loc');
        FlutterForegroundTask.sendDataToMain(loc);
      } else {
        print('Location permission is not granted');
        Object loc = {'error': 'Always location permission is not granted'};
        FlutterForegroundTask.sendDataToMain(loc);
      }
    } else {
      print('Location service is not enabled');
      Object loc = {'error': 'Location service is not enabled'};
      FlutterForegroundTask.sendDataToMain(loc);
    }
  }

  @override
  void onReceiveData(Object data) async {
    print('onReceiveData: $data');
    await locationInBackground();
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    print("Foreground repeat event triggered");
  }

  @override
  void onDestroy(DateTime timestamp) async {
    print("Destroying foreground task");
    FlutterForegroundTask.stopService();
  }
}

class ForegroundUtil {
  static Future<void> requestPermissions() async {
    // Android 13+, you need to allow notification permission to display foreground service notification.
    //
    // iOS: If you need notification, ask for permission.
    final NotificationPermission notificationPermissionStatus =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermissionStatus != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (Platform.isAndroid) {
      // if (!await FlutterForegroundTask.canDrawOverlays) {
      //   await FlutterForegroundTask.openSystemAlertWindowSettings();
      // }
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }
  }

  static Future<void> initializeForegroundService() async {
    if (await FlutterForegroundTask.isRunningService) return;
    print('initializeForegroundService');
    // await Location().requestPermission();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Foreground Service Notification',
        channelDescription: 'Transcription service is running in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.HIGH,
        // iconData: const NotificationIconData(
        //   resType: ResourceType.mipmap,
        //   resPrefix: ResourcePrefix.ic,
        //   name: 'launcher',
        // ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<ServiceRequestResult> startForegroundTask() async {
    print('startForegroundTask');
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      print('starting service');
      return await FlutterForegroundTask.startService(
        notificationTitle: 'Your Friend Device is connected.',
        notificationText: 'Transcription service is running in the background.',
        callback: _startForegroundCallback,
      );
    }
  }
}
