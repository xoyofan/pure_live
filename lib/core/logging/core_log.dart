import 'package:logger/logger.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/config/log_controller.dart';

/// Host-provided persistence for CoreLog. The Flutter app registers an
/// implementation that forwards to the in-app log store/server; the sidecar
/// build registers nothing and only the in-memory print hook stays active.
abstract interface class CoreLogRuntime {
  bool get persistentLogEnabled;

  void write(Level level, String message, StackTrace? stackTrace);
}

class CoreLog {
  static Function(Level, String)? onPrintLog;

  /// Installed by the app at startup; null in the sidecar process.
  static CoreLogRuntime? runtime;

  static bool get _persistentLogEnabled => runtime?.persistentLogEnabled ?? false;

  static void _persist(Level level, String message, StackTrace? stackTrace) {
    final host = runtime;
    if (host == null || !host.persistentLogEnabled) return;
    host.write(level, message, stackTrace);
  }

  static void d(String message) {
    onPrintLog?.call(Level.debug, message);
    _persist(Level.debug, message, null);
  }

  static void i(String message) {
    onPrintLog?.call(Level.info, message);
    _persist(Level.info, message, null);
  }

  static void e(String message, StackTrace stackTrace) {
    onPrintLog?.call(Level.error, message);
    _persist(Level.error, message, stackTrace);
  }

  static void error(dynamic e) {
    final String msg = e.toString();
    onPrintLog?.call(Level.error, msg);
    if (!_persistentLogEnabled) return;

    final StackTrace trace = (e is Error) ? (e.stackTrace ?? StackTrace.current) : StackTrace.current;
    _persist(Level.error, msg, trace);
  }

  static void w(String message) {
    onPrintLog?.call(Level.warning, message);
    _persist(Level.warning, message, null);
  }

  static void logPrint(dynamic obj) {
    final String content = obj.toString();
    onPrintLog?.call(Level.error, content);
    _persist(Level.error, content, null);
  }
}
