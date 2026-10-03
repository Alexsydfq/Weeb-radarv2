/// Startowa lista artystów, wyciągnięta ze Spotify Awexa (obserwowani,
/// najczęściej słuchani, ostatnio grane i playlista „Vocaloid and cool stuff”).
/// W aplikacji można ją dowolnie edytować na ekranie „Artyści”.
const defaultArtists = <String>[
  // Ze Spotify Awexa i z listy obserwowanych w skanie Weeb Radar.
  'Hatsune Miku', 'Kasane Teto', '重音テト', 'DECO*27', 'PinocchioP', 'r-906',
  '花譜', 'KAF', 'V.W.P', 'KAMITSUBAKI', 'Nanahira', 'Kikuo', 'Mili', 'Aiobahn',
  'ZAQ', 'HANABIE.', 'BABYMETAL', 'Camellia', 't+pazolite', 'kors k',
  'HARDCORE TANO*C', 'cosMo@Bousou-P', 'Kairiki Bear', 'sasakure.UK', 'MARETU',
  'Sana Natori', 'マサラダ', 'Masarada', '柊マグネタイト', 'Hiiragi Magnetite',
  'wotaku', 'hya', 'Jamie Paige', 'Sasuke Haraguchi', 'Machico', 'TRUE', 'LiSA',
  'LOVEBITES', 'Cho Tokimeki Sendenbu', 'Densetsu.EXE', 'hololive', 'Suisei',
  'Koyori', '博衣こより', '姫森ルーナ', 'ラプラス・ダークネス', 'Momone Chinoi',
  "Something's off with my Vocaloid", 'NOMELON NOLEMON', 'Yoshida Yasei',
  'Hige Driver', 'jon-YAKITORY', 'Yuuyu', 'Chinozo', 'DELUTAYA', '9Lana', 'FARUCO',
  'hiroki.', 'Parang', 'Wotoha', 'Mitsukiyo', 'nekozume', 'FLAVOR FOLEY', 'Azari',
  'Tokyo Manaka', 'Nanahoshi Orchestra', 'REDALiCE', 'DJ Myosuke', 'beatMARIO',
  'COOL&CREATE', 'IOSYS', 'somunia', 'Patra Suou', 'Gakuen iDOLM@STER',
  'MORE MORE JUMP!', 'Project SEKAI', 'HaKoniwalily', 'MILGRAM', 'KOTOKO',
  'HoneyWorks', 'NANAOAKARI', 'DAZBEE', 'Ado', 'YOASOBI', 'frederic', 'toe',
  'ALT BLK ERA', '32ki', 'えいぷ', 'BilliumMoto', 'choko', 'Atena', 'Lapis Aoki',
  'Merli', 'Vocafest',
  // Z Twoich statystyk Spotify (top 6 miesięcy, zrzuty z 3.10.2026).
  '重音テト', '初音ミク',
  'Kairikibear', '雨衣', 'TUYU', 'Daft Punk', 'ラプラス・ダークネス', '音街ウナ', 'さくらみこ',
  'NAKANO-DENNOU', '煮ル果実', '電音部', '博衣こより', 'Eipu', 'Yoko Takahashi', 'いよわ', 'SAWTOWNE',
  'ナユタン星人', 'INUKAI ULU', 'INUKAI LULU', 'SUISEI LUNA', 'さたぱんP', '夏色まつり', '赤見かるび',
  'MARUMOCHI from HoneyWorks', '星街すいせい', 'Hoshimachi Suisei', 'youまん', 'youman',
  'Bootie Brown', '藤田ことね', 'Kanaria', 'Aoris', 'TRAP CHICK', 'EMIRI', '名取さな', '稲葉曇',
  'Queens of the Stone Age', 'munina', 'LiliPi', '愛上あむ', '白上フブキ', 'HoYoFair', 'ツミキ',
  'Tomare Udagawa', 'Capital Cities', '南ノ南', 'Pinky Pop Hepburn', 'Cassie Wei',
  'Takafumi Sato', 'Tubasa Handa', 'Ramune Yamada', 'P丸様。', 'D.watt', '理芽', 'Rei Adachi',
  'いのうつはSA', '姫森ルーナ', 'rissyuu', 'Harumakigohan', 'Rosa Walton', 'Hallie Coggins',
  'nora2r', 'きくお', '黒皇帝', 'ミ瑞', '藤原ハガネ', '吉田夜世', 'Otonashi AF', 'IA AI', '佐藤ちなみに',
  '鳴花ミコト', 'Pochi Korone', 'KoronePochi', 'るるどらいおん', '花海佑芽', 'IDONO KAWAZU',
  'Fubuki Shirakami', 'Ninomae Ina\'nis', 'すりぃ', 'TENKO SHIBUKI', 'きくおはな', 'Sobrem',
  'vally.exe', '夢ノ結唱', 'ポリスピカデリー', 'MonochroMenace', 'Toby Fox', 'rumaki', '柏木カレキ',
  'Shogo Nomura', '秦谷美鈴', 'Qtie', '勇魚', '篠澤広', 'Del The Funky Homosapien',
  'pale fortress', 'LonePi', '小澤亜李', 'MendoZID', '可不', 'MOB CHOIR', 'yoshimoto ojisan',
  'HIDEYA KOJIMA', 'Debidebi Debiru', 'Lulu Suzuhara', 'LindaAI-CUE', 'Neko Hacker',
  'Abaraya', 'Yunosuke', '洛天依', 'はろける', 'Toccoyaki', 'kono_ken', 'Guitarheropianozero',
  '足立レイ', '十王星南', 'AnythingBecomeMoe', '早川博隆', '広島拓弥', '宇宙ネコ子', 'ついなちゃん', '烏屋茶房',
  'Mitchie M', 'ファル公', 'NAKISO', 'Iyowa', 'Aku P', 'VocaloKAT', 'RiraN', 'しぐれうい',
  'Shinra-Bansho', 'ずんだもん', 'miComet', '25時、ナイトコードで。', 'Kagamine Rin', 'nyankobrq',
  'gaburyu', 'YACA IN DA HOUSE', '暁Records', 'MAMEKAKAO', 'ODDEEO', 'Vane Lily',
  'Riproducer', 'THØRNS', 'WitcheswithGlitches', 'Staircatte', 'Monochrome Media',
  'electrovoid', 'KAFKA', 'Mage-P', '11vein', '4M-P', 'Pizza-P!', '佐藤貴文',
  // Podane przez Awexa: widziani na Pohodzie i Primaverze.
  'Gorillaz', 'LCD Soundsystem',
];

/// Festiwale, na które Awex jeździ. Daty z musicfestivalwizard.com (3.10.2026),
/// line-upy jeszcze nieogłoszone, więc trafiają do radaru jako pewniaki.
const curatedFestivals = <Map<String, dynamic>>[
  {
    'id': 'fest-primavera-2027',
    'artist': 'Primavera Sound 2027',
    'title': 'Barcelona',
    'kind': 'festiwal',
    'tier': 3,
    'dateStart': '2027-06-03',
    'dateEnd': '2027-06-05',
    'note': 'Jeden z Twoich festiwali. Line-up 2027 jeszcze nieogłoszony, sprawdzaj stronę festiwalu.',
    'stops': [
      {'cc': 'ES', 'city': 'Barcelona', 'date': '2027-06-03', 'venue': 'Parc del Fòrum'},
    ],
    'url': 'https://www.primaverasound.com/',
  },
  {
    'id': 'fest-pohoda-2027',
    'artist': 'Pohoda 2027',
    'title': 'Trenčín',
    'kind': 'festiwal',
    'tier': 3,
    'dateStart': '2027-07-08',
    'dateEnd': '2027-07-10',
    'note': 'Jeden z Twoich festiwali. Line-up 2027 jeszcze nieogłoszony.',
    'stops': [
      {'cc': 'SK', 'city': 'Trenčín', 'date': '2027-07-08', 'venue': 'Letisko Trenčín'},
    ],
    'url': 'https://www.pohodafestival.sk/',
  },
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
    'Primavera Sound',
    'https://www.primaverasound.com/',
    'Barcelona, początek czerwca. Line-up zwykle ogłaszany zimą.',
  ),
  WatchSource(
    'Pohoda',
    'https://www.pohodafestival.sk/',
    'Trenčín, początek lipca.',
  ),
  WatchSource(
    'Konwenty w Polsce',
    'https://konwenty-poludniowe.pl/',
    'Kalendarz polskich konwentów: Pyrkon, Remcon, Hikari i reszta.',
  ),
  WatchSource(
    'AnimeCon (NL)',
    'https://animecon.nl/en/',
    'Holenderski konwent, na którym gra m.in. Vocafest UK.',
  ),
  WatchSource(
    'DoKomi',
    'https://www.dokomi.de/en/',
    'Düsseldorf, największy konwent w Niemczech, J-Rave i koncerty.',
  ),
  WatchSource(
    'Japan Expo Paris',
    'https://www.japan-expo-paris.com/',
    'Lipiec, mnóstwo japońskich gości muzycznych.',
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
  'EU': 'Cała Europa',
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
  'festiwal': 'Festiwal',
  'inne': 'Inne',
};
