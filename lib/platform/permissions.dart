import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/log.dart';

Future<bool> _confirm(
  BuildContext context,
  String title,
  String body, {
  String ok = 'Continue',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Explains why [permissions] are needed, requests them, and if the user has
/// permanently denied them, offers to open system settings.
/// Returns true only when every permission is granted.
Future<bool> ensurePermissions(
  BuildContext context, {
  required List<Permission> permissions,
  required String title,
  required String reason,
}) async {
  try {
    final current = {for (final p in permissions) p: await p.status};
    if (current.values.every((s) => s.isGranted)) return true;

    final blocked = current.values.any((s) => s.isPermanentlyDenied);
    if (!context.mounted) return false;
    if (blocked) {
      final open = await _confirm(
        context,
        title,
        '$reason\n\nPermission was denied previously. Open app settings to allow it.',
        ok: 'Open settings',
      );
      if (open) await openAppSettings();
      return false;
    }
    if (!await _confirm(context, title, reason)) return false;

    final result = await permissions.request();
    if (result.values.every((s) => s.isGranted)) return true;
    if (result.values.any((s) => s.isPermanentlyDenied) && context.mounted) {
      final open = await _confirm(
        context,
        title,
        'Permission is blocked. You can enable it in app settings.',
        ok: 'Open settings',
      );
      if (open) await openAppSettings();
    }
    return false;
  } catch (e, st) {
    logError('ensurePermissions', e, st);
    return false;
  }
}

/// "Display over other apps" (SYSTEM_ALERT_WINDOW) can only be granted from a
/// system settings screen, so we explain first, then open it.
Future<bool> ensureOverlayPermission(BuildContext context) async {
  try {
    if (await FlutterOverlayWindow.isPermissionGranted()) return true;
    if (!context.mounted) return false;
    final go = await _confirm(
      context,
      'Allow floating script window',
      'To show the script above other apps, Android needs the "Display over other apps" permission. '
          'You\'ll be taken to a system screen to enable it for this app, then come back.',
      ok: 'Open settings',
    );
    if (!go) return false;
    final granted = await FlutterOverlayWindow.requestPermission();
    return granted ?? await FlutterOverlayWindow.isPermissionGranted();
  } catch (e, st) {
    logError('ensureOverlayPermission', e, st);
    return false;
  }
}

/// Android 13+ requires notification permission for the overlay's foreground
/// service notification. Best-effort: the overlay still works if declined,
/// but the user may not see its status notification.
Future<void> requestNotificationPermissionIfNeeded(BuildContext context) async {
  try {
    if (await Permission.notification.isGranted) return;
    if (!context.mounted) return;
    if (await _confirm(
      context,
      'Show status notification',
      'While the floating script is running Android shows a notification so you can see and stop it.',
    )) {
      await Permission.notification.request();
    }
  } catch (e, st) {
    logError('notificationPermission', e, st);
  }
}
