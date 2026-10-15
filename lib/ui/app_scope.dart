import 'package:flutter/widgets.dart';

import '../data/app_state.dart';

/// Udostępnia [AppState] całemu drzewu i przebudowuje zależne widżety.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState super.notifier, required super.child});

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Bez nasłuchiwania, do użycia w callbackach.
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
