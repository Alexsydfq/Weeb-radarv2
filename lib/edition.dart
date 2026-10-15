/// Wydanie apki. Pełne jest dla Awexa; wydanie „dla znajomych” buduje się z
/// `--dart-define=EDITION=friends` (Android: też `--flavor friends`).
///
/// Wersja dla znajomych tylko czyta publiczny feed: bez tokenu GitHub,
/// synchronizacji, zmiany źródeł i bez list oraz miejsc ze Spotify Awexa.
/// Teksty są neutralne, a powiadomienia domyślnie wyłączone.
library;

import 'dart:ui' show Color;

/// Zmienne (a nie const), żeby testy i zrzuty ekranu mogły przełączyć wydanie.
bool friendsEdition = const String.fromEnvironment('EDITION') == 'friends';

String get appName => friendsEdition ? 'Radar koncertów' : 'Weeb Radar';

/// Tekst zależny od wydania: pierwszy dla Awexa, drugi dla znajomych.
String byEdition(String full, String friends) => friendsEdition ? friends : full;

/// Spokojny, stalowy akcent: domyślny w wydaniu dla znajomych.
const calmAccent = Color(0xFF6B8CAE);
