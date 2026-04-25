import 'dart:io';

import 'package:flutter/services.dart';

import '../constants/platform_channels.dart';

abstract final class ForegroundService {
  static const _channel = MethodChannel(kForegroundServiceChannel);

  static Future<void> startService() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('startService');
    } on PlatformException {
      // Swallowed: the service start is best-effort. A future improvement
      // could surface this via a logger / Crashlytics record.
    }
  }

  static Future<void> stopService() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stopService');
    } on PlatformException {
      // See note in startService.
    }
  }
}
