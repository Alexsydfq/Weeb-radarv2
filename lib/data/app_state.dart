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
import 'sync_service.dart';

/// Formaty tła, które Flutter dekoduje na Androidzie i Windowsie.
/// GIF i animowany WebP są odtwarzane w pętli.
const backgroundExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'];

enum BackgroundFit { cover, contain, tile }

/// Cały stan aplikacji: ustawienia, Twoi artyści, ulubione i eventy.
class AppState extends ChangeNotifier {
  AppState(this._prefs, {FeedService? feed, SyncService? sync})
      : _feed = feed ?? FeedService(),
        _sync = sync ?? SyncService();

  final SharedPreferences _prefs;
  final FeedService _feed;
  final SyncService _sync;

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
  /// Decyzje per event (Idę / Może / Nie idę, ulubione, ukryte) z czasem zmiany.
  /// To jest to, co jedzie przez synchronizację.
  Map<String, PlanEntry> entries = {};
  Set<String> get favourites => {for (final e in entries.entries) if (e.value.fav) e.key};
  Set<String> get hidden => {for (final e in entries.entries) if (e.value.hidden) e.key};
  Plan? planOf(String id) => entries[id]?.plan;
  bool hideNotGoing = false;

  // ---------- synchronizacja ----------
  String? syncToken;
  String? syncGistId;
  bool syncing = false;
  String? syncError;
  DateTime? lastSync;
  bool get syncEnabled => syncToken != null && syncToken!.isNotEmpty;
  Timer? _syncDebounce;
  /// Kod kraju albo 'EU' (cała Europa, domyślnie).
  String homeCountry = 'EU';

  /// Konwenty i festiwale zawsze w „Dla mnie”, bo tam często gra coś fajnego.
  bool conventionsAlwaysForYou = true;

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

  static final _festivals = curatedFestivals
      .map((j) => RadarEvent.fromJson(j, origin: EventOrigin.curated))
      .toList();

  List<RadarEvent> get events {
    final all = <String, RadarEvent>{};
    for (final e in [..._festivals, ..._remoteEvents, ...manualEvents]) {
      all[e.id] = e;
    }
    final h = hidden;
    return all.values.where((e) => !h.contains(e.id)).toList();
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
    // Po powrocie do apki (np. zmieniłeś coś na komputerze) dociągamy plany.
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(syncNow()));
  }

  AppLifecycleListener? _lifecycle;

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
    entries = decodeEntries(p.getString('plans.entries'));
    if (!p.containsKey('plans.entries')) {
      // Przenosimy stare ulubione/ukryte z wersji bez synchronizacji.
      for (final id in p.getStringList('taste.favourites') ?? const <String>[]) {
        entries[id] = PlanEntry(fav: true, at: 1);
      }
      for (final id in p.getStringList('taste.hidden') ?? const <String>[]) {
        entries[id] = (entries[id] ?? const PlanEntry(at: 1)).copyWith(hidden: true, at: 1);
      }
    }
    hideNotGoing = p.getBool('plans.hideNotGoing') ?? hideNotGoing;
    syncToken = p.getString('sync.token');
    syncGistId = p.getString('sync.gist');
    final ls = p.getString('sync.last');
    lastSync = ls == null ? null : DateTime.tryParse(ls);
    homeCountry = p.getString('taste.home') ?? homeCountry;
    conventionsAlwaysForYou = p.getBool('taste.conventions') ?? conventionsAlwaysForYou;

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
    unawaited(syncNow());
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

  bool isHome(String cc) =>
      homeCountry == 'EU' ? europeCodes.contains(cc.toUpperCase()) : cc.toUpperCase() == homeCountry;

  final Map<String, RegExp> _patterns = {};

  /// Czy nazwa występuje w tekście jako osobne słowo (żeby „TRUE” czy „toe”
  /// nie łapały się w środku innych słów). Japońskie nazwy szukamy wprost.
  bool mentions(String text, String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return false;
    final re = _patterns.putIfAbsent(
      n,
      () => RegExp('(?<![a-z0-9])${RegExp.escape(n)}(?![a-z0-9])'),
    );
    return re.hasMatch(text);
  }

  List<String> matchedArtists(RadarEvent e) {
    final text = e.searchable;
    return artists.where((a) => mentions(text, a)).toList();
  }

  List<String> matchedKeywords(RadarEvent e) {
    final text = '${e.searchable} ${e.kind}';
    return keywords.where((k) => mentions(text, k)).toList();
  }

  /// Wynik „dla Ciebie”: poziom z feedu, Twoi artyści, słowa kluczowe i bliskość.
  int score(RadarEvent e) {
    var s = e.tier * 10;
    s += matchedArtists(e).length * 25;
    s += matchedKeywords(e).length * 6;
    if (e.countries.any(isHome)) s += 12;
    final entry = entries[e.id];
    if (entry?.fav == true) s += 5;
    if (entry?.plan == Plan.going) s += 30;
    if (entry?.plan == Plan.maybe) s += 10;
    if (entry?.plan == Plan.notGoing) s -= 40;
    return s;
  }

  bool isForYou(RadarEvent e) {
    final plan = planOf(e.id);
    if (plan == Plan.going || plan == Plan.maybe) return true;
    if (plan == Plan.notGoing && hideNotGoing) return false;
    return _matchesTaste(e);
  }

  bool _matchesTaste(RadarEvent e) =>
      matchedArtists(e).isNotEmpty ||
      matchedKeywords(e).isNotEmpty ||
      e.tier >= 3 ||
      (conventionsAlwaysForYou && (e.kind == 'konwent' || e.kind == 'festiwal'));

  bool isNew(RadarEvent e) {
    final f = e.foundAt;
    if (f == null) return false;
    return todayDate().difference(f).inDays <= 7;
  }

  // ======================================================================
  // Mutacje
  // ======================================================================

  int _now() => DateTime.now().millisecondsSinceEpoch;

  void _edit(String id, PlanEntry Function(PlanEntry e) change) {
    final current = entries[id] ?? const PlanEntry(at: 0);
    var at = _now();
    // Zegary telefonu i komputera mogą się rozjeżdżać: zmiana zawsze jest nowsza od poprzedniej.
    if (at <= current.at) at = current.at + 1;
    entries[id] = change(current).copyWith(at: at);
    _saveEntries();
    notifyListeners();
    _scheduleSync();
  }

  void _saveEntries() => _prefs.setString('plans.entries', encodeEntries(entries));

  void toggleFavourite(String id) => _edit(id, (e) => e.copyWith(fav: !e.fav, at: e.at));

  /// Ustawia plan; ten sam plan drugi raz go zdejmuje.
  void setPlan(String id, Plan? plan) =>
      _edit(id, (e) => e.copyWith(plan: () => e.plan == plan ? null : plan, at: e.at));

  void hide(String id) => _edit(id, (e) => e.copyWith(hidden: true, at: e.at));

  void unhideAll() {
    for (final id in hidden) {
      _edit(id, (e) => e.copyWith(hidden: false, at: e.at));
    }
  }

  void setHideNotGoing(bool v) {
    hideNotGoing = v;
    _prefs.setBool('plans.hideNotGoing', v);
    notifyListeners();
  }

  // ======================================================================
  // Synchronizacja (prywatny GitHub Gist)
  // ======================================================================

  void _scheduleSync() {
    if (!syncEnabled) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 3), () => unawaited(syncNow()));
  }

  Future<void> setSyncToken(String? token) async {
    final t = token?.trim();
    syncToken = (t == null || t.isEmpty) ? null : t;
    syncGistId = null;
    syncError = null;
    if (syncToken == null) {
      await _prefs.remove('sync.token');
    } else {
      await _prefs.setString('sync.token', syncToken!);
    }
    await _prefs.remove('sync.gist');
    notifyListeners();
    await syncNow();
  }

  Future<void>? _syncRun;
  bool _syncAgain = false;

  /// Synchronizuje teraz. Jeśli runda już trwa, dokłada jeszcze jedną po niej,
  /// żeby świeże zmiany nie czekały na następny raz.
  Future<void> syncNow() {
    if (!syncEnabled) return Future.value();
    if (_syncRun != null) {
      _syncAgain = true;
      return _syncRun!;
    }
    return _syncRun = _syncLoop().whenComplete(() => _syncRun = null);
  }

  Future<void> _syncLoop() async {
    do {
      _syncAgain = false;
      await _syncOnce();
    } while (_syncAgain && syncEnabled && syncError == null);
  }

  Future<void> _syncOnce() async {
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      final r = await _sync.sync(syncToken!, syncGistId, entries);
      // W trakcie mogły dojść lokalne zmiany: łączymy jeszcze raz.
      entries = mergeEntries(entries, r.entries);
      syncGistId = r.gistId;
      lastSync = DateTime.now();
      _saveEntries();
      await _prefs.setString('sync.gist', r.gistId);
      await _prefs.setString('sync.last', lastSync!.toIso8601String());
    } catch (e) {
      syncError = e is SyncException ? e.message : 'Synchronizacja nie wyszła: $e';
    } finally {
      syncing = false;
      if (!_disposed) notifyListeners();
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _syncDebounce?.cancel();
    _lifecycle?.dispose();
    super.dispose();
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

  void setConventionsAlwaysForYou(bool v) {
    conventionsAlwaysForYou = v;
    _prefs.setBool('taste.conventions', v);
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
