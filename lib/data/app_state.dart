import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../edition.dart';
import '../models/event.dart';
import '../models/song.dart';
import 'defaults.dart';
import 'feed_service.dart';
import 'sync_service.dart';

/// Formaty tła, które Flutter dekoduje na Androidzie i Windowsie.
/// GIF i animowany WebP są odtwarzane w pętli.
const backgroundExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'];

enum BackgroundFit { cover, contain, tile }

/// Startowa lista artystów. U znajomych ta sama, ale alfabetycznie,
/// żeby nie zdradzała kolejności z rankingu Spotify Awexa.
List<String> get starterArtists => friendsEdition
    ? ([...defaultArtists]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())))
    : [...defaultArtists];

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
  Color accent = friendsEdition ? calmAccent : const Color(0xFF39C5BB); // turkus Miku
  ThemeMode themeMode = ThemeMode.dark;
  double cardOpacity = 0.55;

  // ---------- gust ----------
  List<String> artists = starterArtists;
  List<String> keywords = [...defaultKeywords];
  /// Decyzje per event (Idę / Może / Zainteresowany / Nie idę, ulubione, ukryte) z czasem zmiany.
  /// To jest to, co jedzie przez synchronizację.
  Map<String, PlanEntry> entries = {};
  Set<String> get favourites => {for (final e in entries.entries) if (e.value.fav) e.key};
  Set<String> get hidden => {for (final e in entries.entries) if (e.value.hidden) e.key};
  Plan? planOf(String id) => entries[id]?.plan;
  bool hideNotGoing = false;

  // ---------- powiadomienia ----------
  bool notifyEnabled = !friendsEdition;

  /// Tylko Spotify albo cały gust („Dla mnie”).
  bool notifySpotifyOnly = false;

  /// Co ile godzin sprawdzać nowości w tle.
  int notifyHours = 24;
  bool notifyJapan = true;
  bool notifyMusic = true;

  /// Windows: zamknięcie okna chowa apkę do zasobnika, żeby dalej sprawdzała.
  bool trayOnClose = true;

  /// Windows: uruchamiaj (schowaną) razem z systemem.
  bool autostart = false;

  // ---------- synchronizacja ----------
  String? syncToken;
  String? syncGistId;
  bool syncing = false;
  String? syncError;
  DateTime? lastSync;
  bool get syncEnabled => !friendsEdition && syncToken != null && syncToken!.isNotEmpty;
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
    // Wbudowany festiwal chowamy, gdy skan ma już ten sam festiwal (z line-upem itd.).
    final curated = _festivals.where((f) => !_remoteEvents.any((r) => _sameFestival(f, r)));
    for (final e in [...curated, ..._remoteEvents, ...manualEvents]) {
      all[e.id] = e;
    }
    final h = hidden;
    return [
      for (final e in all.values)
        if (!h.contains(e.id)) _withChosenStop(e),
    ];
  }

  RadarEvent _withChosenStop(RadarEvent e) {
    final key = entries[e.id]?.stop;
    if (key == null || e.stops.length < 2) return e;
    final st = e.stops.where((x) => x.key == key).firstOrNull;
    return st == null ? e : e.withChosen(st);
  }

  static bool _sameFestival(RadarEvent curated, RadarEvent other) {
    if (other.kind != 'festiwal') return false;
    final word = curated.artist.toLowerCase().split(' ').first;
    return other.artist.toLowerCase().contains(word) && (other.start.difference(curated.start).inDays).abs() <= 45;
  }

  List<RadarEvent> get upcoming =>
      events.where((e) => !e.isOver).toList()..sort((a, b) => a.nextDate.compareTo(b.nextDate));

  /// Radar i kalendarz: Europa (Japonia ma swoją zakładkę).
  List<RadarEvent> get upcomingEurope => upcoming.where((e) => !e.isJapan).toList();

  /// Zakładka Japonia: do śledzenia, nawet jeśli szybko tam nie pojedziesz.
  List<RadarEvent> get upcomingJapan => upcoming.where((e) => e.isJapan).toList();

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
    // Nowi artyści z aktualizacji apki trafiają na listę, ale tych, których
    // sam usunąłeś, nie wskrzeszamy (pamiętamy, co już było proponowane).
    final known = p.getStringList('taste.knownDefaults')?.toSet();
    final have = {for (final a in artists) a.toLowerCase()};
    final fresh = starterArtists
        .where((a) => !(known?.contains(a) ?? false) && !have.contains(a.toLowerCase()))
        .toList();
    if (fresh.isNotEmpty) {
      artists = [...artists, ...fresh];
      p.setStringList('taste.artists', artists);
    }
    if (known == null || fresh.isNotEmpty || known.length != defaultArtists.length) {
      p.setStringList('taste.knownDefaults', defaultArtists);
    }
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
    notifyEnabled = p.getBool('notify.enabled') ?? notifyEnabled;
    notifySpotifyOnly = p.getBool('notify.spotifyOnly') ?? notifySpotifyOnly;
    notifyHours = p.getInt('notify.hours') ?? notifyHours;
    notifyJapan = p.getBool('notify.japan') ?? notifyJapan;
    notifyMusic = p.getBool('notify.music') ?? notifyMusic;
    notified = p.getStringList('notify.seen')?.toSet();
    trayOnClose = p.getBool('win.tray') ?? trayOnClose;
    autostart = p.getBool('win.autostart') ?? autostart;
    // Wydanie dla znajomych nigdy nie używa tokenu GitHub (tylko czyta publiczny feed).
    syncToken = friendsEdition ? null : p.getString('sync.token');
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
    songs = Song.parseFeed(_prefs.getString('music.cache') ?? '[]');
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

  /// Wczytuje same ustawienia (bez sieci) — dla sprawdzania w tle.
  void loadSettings() => _loadPrefs();

  Future<void> refresh({bool sync = true}) async {
    if (loading) return;
    if (sync) unawaited(syncNow());
    loading = true;
    lastError = null;
    notifyListeners();
    try {
      final result = await _feed.fetchAll(
        feedUrl: feedUrl,
        extraFeeds: extraFeeds,
        useVocaDb: useVocaDb,
        vocaDbEuropeOnly: vocaDbEuropeOnly,
        githubToken: syncToken,
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
      try {
        final music = await _feed.fetchMusic(feedUrl: feedUrl, githubToken: syncToken);
        sourceStatus['Nowa muzyka'] = 'ok (${music.length})';
        if (music.isNotEmpty) {
          songs = music;
          await _prefs.setString('music.cache', jsonEncode({'songs': songs.map((x) => x.toJson()).toList()}));
        }
      } catch (e) {
        sourceStatus['Nowa muzyka'] = 'błąd: $e';
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

  static final _strict = {for (final n in strictArtistNames) n.toLowerCase()};

  List<String> matchedArtists(RadarEvent e) {
    final text = e.searchable;
    final head = e.artist.trim().toLowerCase();
    return artists.where((a) {
      final n = a.trim().toLowerCase();
      // „Queen”, „toe”, „Belle” itp. tylko jako dokładna nazwa artysty eventu.
      if (_strict.contains(n)) return head == n || e.lineup.any((l) => l.trim().toLowerCase() == n);
      return mentions(text, a);
    }).toList();
  }

  static final _spotifyTop = <String, int>{
    for (final (i, n) in spotifyTopArtists.indexed.toList().reversed) n.toLowerCase(): i + 1,
  };

  /// Miejsca w Spotify „Top ogólnie” Awexa; wydanie dla znajomych ich nie zna.
  static Map<String, int> get _spotifyRanks => friendsEdition ? const {} : _spotifyTop;

  /// Najwyższe miejsce w Twoim Spotify „Top ogólnie” spośród artystów eventu
  /// (null, gdy nikogo z tej listy tam nie ma).
  int? spotifyRank(RadarEvent e) {
    int? best;
    for (final a in matchedArtists(e)) {
      final r = _spotifyRanks[a.toLowerCase()];
      if (r != null && (best == null || r < best)) best = r;
    }
    return best;
  }

  /// Twoi artyści schowani w jednej pozycji line-upu (np. „DECO*27 b2b PinocchioP”).
  List<String> artistsIn(String lineupEntry) {
    final t = lineupEntry.trim().toLowerCase();
    return artists.where((a) {
      final n = a.trim().toLowerCase();
      return _strict.contains(n) ? t == n : mentions(t, a);
    }).toList();
  }

  /// Miejsce w Spotify „Top ogólnie” dla pozycji line-upu (null, gdy jej tam nie ma).
  int? rankOfEntry(String lineupEntry) {
    int? best;
    for (final a in artistsIn(lineupEntry)) {
      final r = _spotifyRanks[a.toLowerCase()];
      if (r != null && (best == null || r < best)) best = r;
    }
    return best;
  }

  /// Czy na evencie gra ktoś, kogo słuchasz (lista artystów pochodzi ze Spotify).
  bool isSpotify(RadarEvent e) => matchedArtists(e).isNotEmpty;

  // ======================================================================
  // Nowa muzyka
  // ======================================================================

  /// Nowe kawałki z codziennego skanu, najnowsze na górze.
  List<Song> songs = const [];

  /// Twój artysta z listy (najlepsze miejsce w Spotify albo 0, gdy jest na liście bez miejsca).
  int? songRank(Song x) {
    final head = x.artist.toLowerCase();
    int? best;
    for (final a in artists) {
      final n = a.trim().toLowerCase();
      final hit = _strict.contains(n) ? head == n : mentions(head, a);
      if (!hit) continue;
      final r = _spotifyRanks[n] ?? 9999;
      if (best == null || r < best) best = r;
    }
    return best;
  }

  bool isMySong(Song x) => songRank(x) != null;

  bool isSongFav(Song x) => entries[x.key]?.fav ?? false;

  void toggleSongFav(Song x) => toggleFavourite(x.key);

  List<String> matchedKeywords(RadarEvent e) {
    final text = '${e.searchable} ${e.kind}';
    return keywords.where((k) => mentions(text, k)).toList();
  }

  /// Wynik „dla Ciebie”: poziom z feedu, Twoi artyści, słowa kluczowe i bliskość.
  int score(RadarEvent e) {
    var s = e.tier * 10;
    s += matchedArtists(e).length * 25;
    final rank = spotifyRank(e);
    if (rank != null) s += rank <= 10 ? 40 : rank <= 50 ? 25 : 12;
    s += matchedKeywords(e).length * 6;
    if (e.countries.any(isHome)) s += 12;
    final entry = entries[e.id];
    if (entry?.fav == true) s += 5;
    if (entry?.plan == Plan.going) s += 30;
    if (entry?.plan == Plan.maybe) s += 10;
    if (entry?.plan == Plan.interested) s += 6;
    if (entry?.plan == Plan.notGoing) s -= 40;
    return s;
  }

  bool isForYou(RadarEvent e) {
    final plan = planOf(e.id);
    if (plan == Plan.going || plan == Plan.maybe || plan == Plan.interested) return true;
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

  /// Wybór miasta na trasie; drugie kliknięcie w to samo miasto zdejmuje wybór.
  void chooseStop(String id, EventStop stop) =>
      _edit(id, (e) => e.copyWith(stop: () => e.stop == stop.key ? null : stop.key, at: e.at));

  void hide(String id) => _edit(id, (e) => e.copyWith(hidden: true, at: e.at));

  void unhideAll() {
    for (final id in hidden) {
      _edit(id, (e) => e.copyWith(hidden: false, at: e.at));
    }
  }

  /// Ustawiane w main(): pozwala ekranowi ustawień odpalić sprawdzenie od ręki.
  Object? backgroundChecks;

  /// Wołane po zmianie ustawień powiadomień (planowanie w tle, autostart itp.).
  VoidCallback? onNotifySettingsChanged;

  void setNotify({bool? enabled, bool? spotifyOnly, int? hours, bool? tray, bool? startup, bool? japan, bool? music}) {
    if (music != null) _prefs.setBool('notify.music', notifyMusic = music);
    if (enabled != null) _prefs.setBool('notify.enabled', notifyEnabled = enabled);
    if (japan != null) _prefs.setBool('notify.japan', notifyJapan = japan);
    if (spotifyOnly != null) _prefs.setBool('notify.spotifyOnly', notifySpotifyOnly = spotifyOnly);
    if (hours != null) _prefs.setInt('notify.hours', notifyHours = hours);
    if (tray != null) _prefs.setBool('win.tray', trayOnClose = tray);
    if (startup != null) _prefs.setBool('win.autostart', autostart = startup);
    notifyListeners();
    onNotifySettingsChanged?.call();
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
    // Token może też otwierać prywatny feed, więc od razu odświeżamy eventy.
    unawaited(refresh());
    await syncNow();
  }

  /// Id eventów (i zmian), które już były w powiadomieniach na którymś
  /// urządzeniu. null = jeszcze nigdy nie sprawdzaliśmy.
  Set<String>? notified;

  Future<void> markNotified(Iterable<String> ids, {bool sync = true}) async {
    final before = notified?.length;
    notified = {...?notified, ...ids};
    if (before == notified!.length && before != null) return;
    await _prefs.setStringList('notify.seen', notified!.toList());
    if (sync) await syncNow();
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
      final r = await _sync.sync(syncToken!, syncGistId, entries, notified: notified ?? const {});
      // W trakcie mogły dojść lokalne zmiany: łączymy jeszcze raz.
      entries = mergeEntries(entries, r.entries);
      if (r.notified.isNotEmpty) await markNotified(r.notified, sync: false);
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
