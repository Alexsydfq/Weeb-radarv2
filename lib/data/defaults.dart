/// Startowa lista artystów, wyciągnięta ze Spotify Awexa (obserwowani,
/// najczęściej słuchani, ostatnio grane i playlista „Vocaloid and cool stuff”).
/// W aplikacji można ją dowolnie edytować na ekranie „Artyści”.
const defaultArtists = <String>[
  'Hatsune Miku',
  'DECO*27',
  'r-906',
  'マサラダ',
  '柊マグネタイト',
  '花譜',
  '重音テト',
  '32ki',
  'えいぷ',
  'MORE MORE JUMP!',
  'IOSYS',
  'BilliumMoto',
  'Cho Tokimeki Sendenbu',
  'choko',
  'wotaku',
  'Atena',
  'Lapis Aoki',
  'Merli',
  '博衣こより',
  '姫森ルーナ',
  'ラプラス・ダークネス',
  'LCD Soundsystem',
];

/// Słowa, które same w sobie podbijają event (vocaloidy, vtuberzy, j-core).
const defaultKeywords = <String>[
  'vocaloid',
  'miku',
  'vocafest',
  'teto',
  'project sekai',
  'hololive',
  'vtuber',
  'j-core',
  'denpa',
  'anison',
];

/// Wspólny feed z repo weeb-radar, nadpisywany automatycznym skanem.
const defaultFeedUrl =
    'https://raw.githubusercontent.com/Alexsydfq/weeb-radar/main/events.json';

/// Publiczne API VocaDB z eventami vocaloidowymi (koncerty fanowskie, M3, Vocafest...).
const vocaDbEventsUrl = 'https://vocadb.net/api/releaseEvents';

/// Mniejsze eventy, które nie mają API: aplikacja pokazuje je jako skróty.
class WatchSource {
  final String name;
  final String url;
  final String description;
  const WatchSource(this.name, this.url, this.description);

  Map<String, String> toJson() =>
      {'name': name, 'url': url, 'description': description};
  factory WatchSource.fromJson(Map<String, dynamic> j) => WatchSource(
        (j['name'] ?? '').toString(),
        (j['url'] ?? '').toString(),
        (j['description'] ?? '').toString(),
      );
}

const defaultWatchSources = <WatchSource>[
  WatchSource(
    'Vocafest UK & Ireland',
    'https://vocafest.co.uk',
    'Fanowskie koncerty MMD z vocaloidami w UK i Irlandii.',
  ),
  WatchSource(
    'Vocafest: bilety',
    'https://tickets.vocafest.co.uk/vocafest/',
    'Kalendarz i bilety Vocafest (pretix).',
  ),
  WatchSource(
    'VocaDB: eventy',
    'https://vocadb.net/Event',
    'Baza eventów vocaloidowych z całego świata.',
  ),
  WatchSource(
    'MIKU EXPO',
    'https://mikuexpo.com/',
    'Oficjalne trasy Hatsune Miku.',
  ),
  WatchSource(
    'JaME: koncerty w Europie',
    'https://www.jame-world.com/en/concerts.html',
    'Japońskie zespoły w Europie, aktualizowane na bieżąco.',
  ),
  WatchSource(
    'Tokyo Noizu: trasy',
    'https://tokyonoizu.com/japanese-band-tours',
    'Lista tras japońskich zespołów.',
  ),
];

const countryNames = <String, String>{
  'PL': 'Polska',
  'DE': 'Niemcy',
  'UK': 'Wielka Brytania',
  'GB': 'Wielka Brytania',
  'IE': 'Irlandia',
  'FR': 'Francja',
  'NL': 'Holandia',
  'BE': 'Belgia',
  'LU': 'Luksemburg',
  'CZ': 'Czechy',
  'SK': 'Słowacja',
  'AT': 'Austria',
  'CH': 'Szwajcaria',
  'IT': 'Włochy',
  'ES': 'Hiszpania',
  'PT': 'Portugalia',
  'HU': 'Węgry',
  'RO': 'Rumunia',
  'DK': 'Dania',
  'SE': 'Szwecja',
  'NO': 'Norwegia',
  'FI': 'Finlandia',
  'LT': 'Litwa',
  'LV': 'Łotwa',
  'EE': 'Estonia',
  'JP': 'Japonia',
  'US': 'USA',
};

/// Kraje traktowane jako „Europa” przy filtrowaniu VocaDB.
const europeCodes = <String>{
  'PL', 'DE', 'UK', 'GB', 'IE', 'FR', 'NL', 'BE', 'LU', 'CZ', 'SK', 'AT',
  'CH', 'IT', 'ES', 'PT', 'HU', 'RO', 'DK', 'SE', 'NO', 'FI', 'LT', 'LV',
  'EE', 'SI', 'HR', 'BG', 'GR', 'RS', 'UA',
};

/// Emoji flagi z kodu kraju (UK traktujemy jak GB).
String flagOf(String cc) {
  var code = cc.toUpperCase();
  if (code == 'UK') code = 'GB';
  if (code.length != 2) return '🏳️';
  final a = code.codeUnitAt(0), b = code.codeUnitAt(1);
  if (a < 65 || a > 90 || b < 65 || b > 90) return '🏳️';
  return String.fromCharCodes([0x1F1E6 + a - 65, 0x1F1E6 + b - 65]);
}

const kindLabels = <String, String>{
  'trasa': 'Trasa',
  'koncert': 'Koncert',
  'konwent': 'Konwent',
  'rave': 'Rave',
  'vocaloid': 'Vocaloid',
  'inne': 'Inne',
};
