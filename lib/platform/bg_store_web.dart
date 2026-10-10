import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

// localStorage ma tylko ~5 MB, więc obrazek idzie do Cache Storage strony.
const _cacheName = 'weeb-radar-bg';
final _memory = <String, Uint8List>{};

Future<web.Cache> _cache() => web.window.caches.open(_cacheName).toDart;

JSString _url(String key) => 'bg/$key'.toJS;

Future<String> saveBackground(Uint8List bytes, String ext) async {
  final key = 'bg_${DateTime.now().millisecondsSinceEpoch}.$ext';
  await (await _cache()).put(_url(key), web.Response(bytes.toJS)).toDart;
  _memory[key] = bytes;
  return key;
}

/// Wczytuje tło do pamięci; false, gdy przeglądarka je wyczyściła.
Future<bool> loadBackground(String key) async {
  if (_memory.containsKey(key)) return true;
  try {
    final res = await (await _cache()).match(_url(key)).toDart;
    if (res == null) return false;
    final buf = await res.arrayBuffer().toDart;
    _memory[key] = buf.toDart.asUint8List();
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> deleteBackground(String key) async {
  _memory.remove(key);
  try {
    await (await _cache()).delete(_url(key)).toDart;
  } catch (_) {}
}

ImageProvider backgroundImage(String key) => MemoryImage(_memory[key] ?? Uint8List(0));
