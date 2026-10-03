import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/app_state.dart';
import 'ui/app_scope.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pl');
  final prefs = await SharedPreferences.getInstance();
  final state = AppState(prefs);
  await state.init();
  runApp(WeebRadarApp(state: state));
}

class WeebRadarApp extends StatelessWidget {
  const WeebRadarApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: 'Weeb Radar',
          debugShowCheckedModeBanner: false,
          themeMode: state.themeMode,
          theme: buildTheme(state.accent, Brightness.light),
          darkTheme: buildTheme(state.accent, Brightness.dark),
          locale: const Locale('pl'),
          supportedLocales: const [Locale('pl'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Shell(),
        ),
      ),
    );
  }
}
