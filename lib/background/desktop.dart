import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../data/app_state.dart';
import 'background.dart';

/// Windows: ikonka w zasobniku, chowanie okna zamiast zamykania i autostart.
class Desktop with TrayListener, WindowListener {
  Desktop(this.state, this.checks);

  final AppState state;
  final BackgroundChecks checks;

  static const startHiddenFlag = '--hidden';
  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

  Future<void> start({required bool hidden}) async {
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    await windowManager.setPreventClose(state.trayOnClose);
    if (hidden) await windowManager.hide();

    trayManager.addListener(this);
    await trayManager.setIcon(await _iconPath());
    await trayManager.setToolTip('Weeb Radar');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Pokaż Weeb Radar'),
      MenuItem(key: 'check', label: 'Sprawdź nowości teraz'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Zakończ'),
    ]));

    final previous = state.onNotifySettingsChanged;
    state.onNotifySettingsChanged = () {
      previous?.call();
      unawaited(windowManager.setPreventClose(state.trayOnClose));
      unawaited(setAutostart(state.autostart));
    };
  }

  /// Tray potrzebuje prawdziwego pliku .ico, a assety siedzą w paczce.
  static Future<String> _iconPath() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}tray.ico');
    if (!file.existsSync()) {
      final data = await rootBundle.load('assets/tray.ico');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return file.path;
  }

  static Future<void> setAutostart(bool on) async {
    if (on) {
      await Process.run('reg', [
        'add', _runKey, '/v', 'WeebRadar', '/t', 'REG_SZ', '/d',
        '"${Platform.resolvedExecutable}" $startHiddenFlag', '/f',
      ]);
    } else {
      await Process.run('reg', ['delete', _runKey, '/v', 'WeebRadar', '/f']);
    }
  }

  static Future<void> show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onWindowClose() async {
    if (state.trayOnClose) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
    }
  }

  @override
  void onTrayIconMouseDown() => unawaited(show());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await show();
      case 'check':
        await checks.checkNow();
      case 'quit':
        await trayManager.destroy();
        await windowManager.destroy();
    }
  }
}
