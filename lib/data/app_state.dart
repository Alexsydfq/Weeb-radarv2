import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/event.dart';
import 'defaults.dart';
import 'feed_service.dart';

/// Formaty tła, które Flutter dekoduje na Androidzie i Windowsie.
/// GIF i animowany WebP są odtwarzane w pętli.
const backgroundExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'];

enum BackgroundFit { cover, contain, tile }

/// Cały stan aplikacji: ustawienia, Twoi artyści, ulubione i eventy.
class AppState extends ChangeNotifier {
  AppState(this._prefs, {FeedService? feed}) : _feed = feed ?? FeedService();

  final SharedPreferences _prefs;
  final FeedService _feed;

  // ---------- wygląd ----------
  String? backgroundPath;
  double backgroundBlur = 0;
  double backgroundDim = 0.45;
  BackgroundFit backgroundFit = BackgroundFit.cover;
  Color accent = const Color(0xFF39C5BB); // turkus Miku
  ThemeMode themeMode = ThemeMode.dark;
  double cardOpacity = 0.55;

  // ---------- gust ----------
  List<String> artists = [...defaultArtists];
  List<String> keywords = [...defaultKeywords];
  Set<String> favourites = {};
  Set<String> hidden = {};
  String homeCountry = 'PL';

  // ---------- źródła ----------
  String feedUrl = defaultFeedUrl;
  List<String> extraFeeds = [];
  bool useVocaDb = true;
  bool vocaDbEuropeOnly = true;
  List<WatchSource> watchSources = [...defaultWatchSources];
  List<RadarEvent> manualEvents = [];

  // ---------- dane ----------
  List<RadarEvent> _remoteEvents = [];
  bool loading = false;
  String? lastError;
  DateTime? lastRefresh;
  DateTime? feedUpdated;
  final Map<String, String> sourceStatus = {};

  List<RadarEvent> get events {
    final all = <String, RadarEvent>{};
    for (final e in [..._remoteEvents, ...manualEvents]) {
      all[e.id] = e;
    }
    return all.values.where((e) => !hidden.contains(e.id)).toList();
  }

  List<RadarEvent> get upcoming =>
      events.where((e) => !e.isOver).toList()..sort((a, b) => a.nextDate.compareTo(b.nextDate));

  // ======================================================================
  // Wczytywanie
  // ======================================================================

  Future<void> init() async {
    _loadPrefs();
    await _loadCachedEvents();
    notifyListeners();
    unawaited(refresh());
  }

  void _loadPrefs() {
    final p = _prefs;
    backgroundPath = p.getString('bg.path');
    if (backgroundPath != null && !File(backgroundPath!).existsSync()) {
      backgroundPath = null;
    }
    backgroundBlur = p.getDouble('bg.blur') ?? backgroundBlur;
    backgroundDim = p.getDouble('bg.dim') ?? backgroundDim;
    backgroundFit = BackgroundFit.values.firstWhere(
      (f) => f.name == p.getString('bg.fit'),
      orElse: () => BackgroundFit.cover,
    );
    final a = p.getInt('ui.accent');
    if (a != null) accent = Color(a);
    themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == p.getString('ui.theme'),
      orElse: () => ThemeMode.dark,
    );
    cardOpacity = p.getDouble('ui.cardOpacity') ?? cardOpacity;

    artists = p.getStringList('taste.artists') ?? artists;
    keywords = p.getStringList('taste.keywords') ?? keywords;
    favourites = (p.getStringList('taste.favourites') ?? const []).toSet();
    hidden = (p.getStringList('taste.hidden') ?? const []).toSet();
    homeCountry = p.getString('taste.home') ?? homeCountry;

    feedUrl = p.getString('src.feed') ?? feedUrl;
    extraFeeds = p.getStringList('src.extra') ?? extraFeeds;
    useVocaDb = p.getBool('src.vocadb') ?? useVocaDb;
    vocaDbEuropeOnly = p.getBool('src.vocadbEurope') ?? vocaDbEuropeOnly;
    final ws = p.getString('src.watch');
    if (ws != null) {
      try {
        watchSources = (jsonDecode(ws) as List)
            .map((e) => WatchSource.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      } catch (_) {}
    }
    final me = p.getString('events.manual');
    if (me != null) {
      try {
        manualEvents = (jsonDecode(me) as List)
            .map((e) => RadarEvent.fromJson((e as Map).cast<String, dynamic>(),
                origin: EventOrigin.manual))
            .toList();
      } catch (_) {}
    }
    final lr = p.getString('events.lastRefresh');
    if (lr != null) lastRefresh = DateTime.tryParse(lr);
  }

  Future<void> _loadCachedEvents() async {
    final cached = _prefs.getString('events.cache');
    if (cached != null) {
      try {
        _remoteEvents = _decodeCache(cached);
        return;
      } catch (_) {}
    }
    // Pierwsze uruchomienie bez internetu: dane wbudowane w aplikację.
    try {
      final raw = await rootBundle.loadString('assets/events_fallback.json');
      final parsed = FeedService.parseFeed(raw, EventOrigin.feed);
      _remoteEvents = parsed.events;
      feedUpdated = parsed.updated;
    } catch (_) {}
  }

  List<RadarEvent> _decodeCache(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    feedUpdated = DateTime.tryParse((j['updated'] ?? '').toString());
    return (j['events'] as List).map((e) {
      final m = (e as Map).cast<String, dynamic>();
      final origin = EventOrigin.values.firstWhere(
        (o) => o.name == m['origin'],
        orElse: () => EventOrigin.feed,
      );
      return RadarEvent.fromJson(m, origin: origin);
    }).toList();
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    lastError = null;
    notifyListeners();
    try {
      final result = await _feed.fetchAll(
        feedUrl: feedUrl,
        extraFeeds: extraFeeds,
        useVocaDb: useVocaDb,
        vocaDbEuropeOnly: vocaDbEuropeOnly,
      );
      sourceStatus
        ..clear()
        ..addAll(result.status);
      if (result.events.isNotEmpty) {
        _remoteEvents = result.events;
        feedUpdated = result.feedUpdated ?? feedUpdated;
        lastRefresh = DateTime.now();
        await _prefs.setString(
          'events.cache',
          jsonEncode({
            'updated': feedUpdated?.toIso8601String(),
            'events': _remoteEvents
                .map((e) => {...e.toJson(), 'origin': e.origin.name})
                .toList(),
          }),
        );
        await _prefs.setString('events.lastRefresh', lastRefresh!.toIso8601String());
      }
      if (result.status.values.every((s) => s.startsWith('błąd'))) {
        lastError = 'Nie udało się pobrać żadnego źródła. Pokazuję zapisane dane.';
      }
    } catch (e) {
      lastError = 'Odświeżanie nie wyszło: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ======================================================================
  // Dopasowanie do gustu
  // ======================================================================

  List<String> matchedArtists(RadarEvent e) {
    final text = e.searchable;
    return artists.where((a) => a.trim().isNotEmpty && text.contains(a.toLowerCase())).toList();
  }

  List<String> matchedKeywords(RadarEvent e) {
    final text = '${e.searchable} ${e.kind}';
    return keywords.where((k) => k.trim().isNotEmpty && text.contains(k.toLowerCase())).toList();
  }

  /// Wynik „dla Ciebie”: poziom z feedu, Twoi artyści, słowa kluczowe i bliskość.
  int score(RadarEvent e) {
    var s = e.tier * 10;
    s += matchedArtists(e).length * 25;
    s += matchedKeywords(e).length * 6;
    if (e.countries.contains(homeCountry)) s += 12;
    if (favourites.contains(e.id)) s += 5;
    return s;
  }

  bool isForYou(RadarEvent e) =>
      matchedArtists(e).isNotEmpty || matchedKeywords(e).isNotEmpty || e.tier >= 3;

  bool isNew(RadarEvent e) {
    final f = e.foundAt;
    if (f == null) return false;
    return todayDate().difference(f).inDays <= 7;
  }

  // ======================================================================
  // Mutacje
  // ======================================================================

  void toggleFavourite(String id) {
    favourites.contains(id) ? favourites.remove(id) : favourites.add(id);
    _prefs.setStringList('taste.favourites', favourites.toList());
    notifyListeners();
  }

  void hide(String id) {
    hidden.add(id);
    _prefs.setStringList('taste.hidden', hidden.toList());
    notifyListeners();
  }

  void unhideAll() {
    hidden.clear();
    _prefs.setStringList('taste.hidden', const []);
    notifyListeners();
  }

  void setArtists(List<String> list) {
    artists = list;
    _prefs.setStringList('taste.artists', artists);
    notifyListeners();
  }

  void setKeywords(List<String> list) {
    keywords = list;
    _prefs.setStringList('taste.keywords', keywords);
    notifyListeners();
  }

  void setHomeCountry(String cc) {
    homeCountry = cc;
    _prefs.setString('taste.home', cc);
    notifyListeners();
  }

  void setAccent(Color c) {
    accent = c;
    _prefs.setInt('ui.accent', c.toARGB32());
    notifyListeners();
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _prefs.setString('ui.theme', m.name);
    notifyListeners();
  }

  void setCardOpacity(double v) {
    cardOpacity = v;
    _prefs.setDouble('ui.cardOpacity', v);
    notifyListeners();
  }

  void setBackgroundBlur(double v) {
    backgroundBlur = v;
    _prefs.setDouble('bg.blur', v);
    notifyListeners();
  }

  void setBackgroundDim(double v) {
    backgroundDim = v;
    _prefs.setDouble('bg.dim', v);
    notifyListeners();
  }

  void setBackgroundFit(BackgroundFit f) {
    backgroundFit = f;
    _prefs.setString('bg.fit', f.name);
    notifyListeners();
  }

  /// Otwiera systemowy wybór pliku i kopiuje obrazek do folderu aplikacji,
  /// żeby tło zostało nawet po usunięciu oryginału.
  Future<String?> pickBackground() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Wybierz tło (PNG, JPG, GIF, WebP, BMP)',
      type: FileType.custom,
      allowedExtensions: backgroundExtensions,
    );
    if (picked == null) return null;
    final ext = (picked.extension ?? '').toLowerCase().replaceAll('.', '');
    if (!backgroundExtensions.contains(ext)) {
      return 'Ten format nie jest obsługiwany: .$ext';
    }
    final bytes = await picked.xFile.readAsBytes();
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/backgrounds');
    await dir.create(recursive: true);
    final file = File('${dir.path}/bg_${DateTime.now().millisecondsSinceEpoch}.$ext');
    await file.writeAsBytes(bytes, flush: true);
    await _deleteOldBackground();
    backgroundPath = file.path;
    await _prefs.setString('bg.path', file.path);
    notifyListeners();
    return null;
  }

  Future<void> clearBackground() async {
    await _deleteOldBackground();
    backgroundPath = null;
    await _prefs.remove('bg.path');
    notifyListeners();
  }

  Future<void> _deleteOldBackground() async {
    final old = backgroundPath;
    if (old == null) return;
    try {
      await File(old).delete();
    } catch (_) {}
  }

  void setFeedUrl(String url) {
    feedUrl = url.trim().isEmpty ? defaultFeedUrl : url.trim();
    _prefs.setString('src.feed', feedUrl);
    notifyListeners();
  }

  void setExtraFeeds(List<String> list) {
    extraFeeds = list;
    _prefs.setStringList('src.extra', list);
    notifyListeners();
  }

  void setUseVocaDb(bool v) {
    useVocaDb = v;
    _prefs.setBool('src.vocadb', v);
    notifyListeners();
  }

  void setVocaDbEuropeOnly(bool v) {
    vocaDbEuropeOnly = v;
    _prefs.setBool('src.vocadbEurope', v);
    notifyListeners();
  }

  void setWatchSources(List<WatchSource> list) {
    watchSources = list;
    _prefs.setString('src.watch', jsonEncode(list.map((w) => w.toJson()).toList()));
    notifyListeners();
  }

  void saveManualEvent(RadarEvent e) {
    manualEvents = [...manualEvents.where((m) => m.id != e.id), e];
    _persistManual();
  }

  void deleteManualEvent(String id) {
    manualEvents = manualEvents.where((m) => m.id != id).toList();
    _persistManual();
  }

  void _persistManual() {
    _prefs.setString('events.manual', jsonEncode(manualEvents.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  @visibleForTesting
  void debugSetEvents(List<RadarEvent> list) {
    _remoteEvents = list;
    notifyListeners();
  }
}
