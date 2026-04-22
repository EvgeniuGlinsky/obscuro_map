import 'dart:io';

import 'package:flutter/services.dart';

abstract final class ForegroundService {
  static const _channel = MethodChannel('obscuro_map/foreground_service');

  static Future<void> startService() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('startService');
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print('[ForegroundService] start failed: ${e.message}');
        return true;
      }());
    }
  }

  static Future<void> stopService() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stopService');
    } on PlatformException catch (e) {
      assert(() {
        // ignore: avoid_print
        print('[ForegroundService] stop failed: ${e.message}');
        return true;
      }());
    }
  }
}
