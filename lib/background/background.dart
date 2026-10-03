import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../data/app_state.dart';
import '../data/news.dart';
import 'notifications.dart';

const _task = 'weeb-radar-check';

/// Jedno sprawdzenie: pobierz feed, znajdź nowości, pokaż powiadomienie.
/// [state] podajemy, gdy apka działa (Windows); w tle tworzymy własny.
Future<int> runCheck(SharedPreferences prefs, {AppState? state}) async {
  final s = state ?? (AppState(prefs)..loadSettings());
  if (!s.notifyEnabled) return 0;
  // Apka mogła właśnie sama odświeżać (start na Windowsie): czekamy na nią.
  while (s.loading) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  await s.refresh(sync: false);
  // Tło na Androidzie pisze do tych samych ustawień, więc bierzemy świeży stan.
  await prefs.reload();
  final stored = prefs.getStringList('notify.seen');
  if (stored != null) s.notified = {...?s.notified, ...stored};
  if (s.lastRefresh == null || s.lastError != null && s.upcoming.isEmpty) return 0;
  // Najpierw ściągamy z gista, o czym już powiadomił drugi sprzęt.
  await s.syncNow();
  final news = await collectNews(s, s.upcoming);
  await Notifier.show(news);
  return news.length;
}

/// Punkt wejścia WorkManagera na Androidzie (osobny isolate, apka może być zamknięta).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await initializeDateFormatting('pl');
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      await runCheck(prefs);
    } catch (e) {
      debugPrint('Weeb Radar: sprawdzanie w tle nie wyszło: $e');
    }
    return true;
  });
}

/// Ustawia sprawdzanie w tle zgodnie z ustawieniami.
/// Android: WorkManager (działa też przy zamkniętej apce).
/// Windows: timer, dopóki apka działa (także schowana w zasobniku).
class BackgroundChecks {
  BackgroundChecks(this.state, this.prefs);

  final AppState state;
  final SharedPreferences prefs;
  Timer? _timer;
  bool _wmReady = false;

  Future<void> start() async {
    if (kIsWeb) return;
    await Notifier.init();
    await apply();
    state.onNotifySettingsChanged = () => unawaited(apply());
  }

  Future<void> apply() async {
    if (Platform.isAndroid) {
      if (!_wmReady) {
        await Workmanager().initialize(callbackDispatcher);
        _wmReady = true;
      }
      if (state.notifyEnabled) {
        await Notifier.requestPermission();
        await Workmanager().registerPeriodicTask(
          _task,
          _task,
          frequency: Duration(hours: state.notifyHours),
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        );
      } else {
        await Workmanager().cancelByUniqueName(_task);
      }
    } else if (Platform.isWindows) {
      _timer?.cancel();
      _timer = null;
      if (state.notifyEnabled) {
        _timer = Timer.periodic(Duration(hours: state.notifyHours), (_) => unawaited(checkNow()));
      }
    }
  }

  /// Sprawdź teraz (przycisk w ustawieniach, start apki na Windowsie).
  Future<int> checkNow() => runCheck(prefs, state: state);

  void dispose() => _timer?.cancel();
}
