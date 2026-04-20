import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Thin wrapper around [FirebaseCrashlytics] for use throughout the app.
///
/// Usage:
///   CrashlyticsService.log('user opened map');
///   CrashlyticsService.recordError(e, st);
abstract final class CrashlyticsService {
  static FirebaseCrashlytics get _i => FirebaseCrashlytics.instance;

  /// Appends a message to the Crashlytics log that accompanies the next report.
  static void log(String message) => _i.log(message);

  /// Sets a custom key/value pair visible in every crash report.
  static void setCustomKey(String key, Object value) =>
      _i.setCustomKey(key, value);

  /// Associates a user identifier with crash reports.
  static void setUserId(String id) => _i.setUserIdentifier(id);

  /// Records a non-fatal error. Use [fatal] for errors that should be
  /// highlighted as fatal in the Crashlytics dashboard.
  static Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) =>
      _i.recordError(error, stack, reason: reason, fatal: fatal);
}
