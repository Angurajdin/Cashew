import 'dart:async';

class CloudSyncLock {
  static Future<dynamic> _lastOp = Future.value();
  static bool isApplyingCloudChanges = false;
  static bool isSyncRunning = false;

  /// Runs [action] exclusively. Concurrent calls wait in a FIFO chain.
  static Future<T> synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _lastOp = _lastOp.then((_) async {
      isSyncRunning = true;
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, stack) {
        completer.completeError(e, stack);
      } finally {
        isSyncRunning = false;
      }
    });
    return completer.future;
  }
}
