import 'package:flutter/material.dart';

import '../background/background.dart';
import 'app_scope.dart';

/// Odświeża wszystko naraz i pokazuje wynik na dole ekranu.
Future<void> refreshAll(BuildContext context) async {
  final s = AppScope.read(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final msg = await refreshEverything(s);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg),
        action: SnackBarAction(label: 'Co to robi?', onPressed: () => _explain(context)),
      ),
    );
}

void _explain(BuildContext context) {
  if (!context.mounted) return;
  showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Odśwież wszystko'),
      content: const Text(
        'Pobiera od razu najnowsze eventy, Japonię i nową muzykę z feedu, VocaDB i Twoje dodatkowe źródła, '
        'synchronizuje plany z drugim urządzeniem i sprawdza, czy jest o czym powiadomić.\n\n'
        'Samo szukanie nowych koncertów w internecie robi skan w chmurze raz dziennie rano. '
        'Przycisk nie uruchamia go od nowa, tylko ściąga to, co skan już znalazł.',
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Jasne'))],
    ),
  );
}

/// Okrągły przycisk „Odśwież wszystko” do nagłówków zakładek.
class RefreshButton extends StatelessWidget {
  const RefreshButton({super.key, required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) => loading
      ? const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
        )
      : IconButton.filledTonal(
          tooltip: 'Odśwież wszystko',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => refreshAll(context),
        );
}
