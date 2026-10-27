import 'package:flutter/foundation.dart';

/// Minimal logging seam. Replace the body to forward to a crash reporter.
void logError(String where, Object error, [StackTrace? stack]) {
  debugPrint('[ERROR] $where: $error');
  if (stack != null && kDebugMode) debugPrintStack(stackTrace: stack);
}
