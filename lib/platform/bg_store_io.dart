import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Zapisuje obrazek w folderze aplikacji i zwraca jego ścieżkę.
Future<String> saveBackground(Uint8List bytes, String ext) async {
  final dir = Directory('${(await getApplicationSupportDirectory()).path}/backgrounds');
  await dir.create(recursive: true);
  final file = File('${dir.path}/bg_${DateTime.now().millisecondsSinceEpoch}.$ext');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// Czy zapisane tło dalej istnieje.
Future<bool> loadBackground(String path) async => File(path).existsSync();

Future<void> deleteBackground(String path) async {
  try {
    await File(path).delete();
  } catch (_) {}
}

ImageProvider backgroundImage(String path) => FileImage(File(path));
