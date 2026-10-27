import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/importers/import_result.dart';
import '../../data/importers/script_importer.dart';

/// Opens the system document picker (which also exposes Google Drive and other
/// cloud providers; no storage permission needed), parses the file in the
/// background and shows the preview screen.
Future<void> startImport(BuildContext context) async {
  final picked = await FilePicker.pickFile(type: FileType.any);
  final path = picked?.path;
  if (path == null || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Reading document…'),
            ],
          ),
        ),
      ),
    ),
  );
  ImportResult? result;
  String? error;
  try {
    result = await importScriptFile(path);
  } on ImportException catch (e) {
    error = e.message;
  } catch (e) {
    error = 'Unexpected problem while importing: $e';
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  if (error != null) {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Can\'t import this file'),
        content: Text(error!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }
  context.push('/import-preview', extra: result);
}
