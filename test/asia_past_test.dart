import 'package:flutter_test/flutter_test.dart';
import 'package:weeb_radar/models/asia_past.dart';
import 'package:weeb_radar/ui/asia_history_page.dart';

void main() {
  const raw = '''
{"updated":"2026-10-15","events":[
 {"id":"asia-2024-08-30-magical-mirai-2024","artist":"Magical Mirai 2024","nameOrig":"マジカルミライ 2024","kind":"koncert","region":"JP",
  "dateStart":"2024-08-30","dateEnd":"2024-09-01","stops":[{"date":"2024-08-30","city":"Chiba","cc":"JP","venue":"Makuhari Messe"}],
  "tags":["Miku","Vocaloid"],"search":["魔法未来2024","マジカルミライ 2024"]},
 {"id":"asia-2025-07-20-tetosonic","artist":"TETOSONIC SUMMER","nameOrig":"テトソニック","dateStart":"2025-07-20",
  "tags":["Teto"],"search":["重音テト ライブ"]},
 {"artist":"no id, skipped"}
]}''';

  test('parseList sorts newest first and skips broken rows', () {
    final list = AsiaPast.parseList(raw);
    expect(list.map((e) => e.id), ['asia-2025-07-20-tetosonic', 'asia-2024-08-30-magical-mirai-2024']);
    expect(list.last.end, DateTime(2024, 9, 1));
    expect(list.first.end, list.first.start);
    expect(AsiaPast.parseList('nope'), isEmpty);
  });

  test('original name comes first in phrases, no duplicates', () {
    final mm = AsiaPast.parseList(raw).last;
    expect(mm.search, ['マジカルミライ 2024', '魔法未来2024', 'Magical Mirai 2024']);
  });

  test('search links are encoded', () {
    expect(bilibiliSearch('魔法未来 2024'), startsWith('https://search.bilibili.com/all?keyword='));
    expect(Uri.parse(bilibiliSearch('魔法未来 2024')).queryParameters['keyword'], '魔法未来 2024');
    expect(Uri.parse(youtubeSearch('テト')).queryParameters['search_query'], 'テト');
  });

  test('tags counted and filtered', () {
    final list = AsiaPast.parseList(raw);
    expect(asiaTagCounts(list).first.key, isNotEmpty);
    expect(filterAsia(list, tags: {'Teto'}).single.name, 'TETOSONIC SUMMER');
    expect(filterAsia(list, query: '魔法未来').single.name, 'Magical Mirai 2024');
    expect(filterAsia(list, tags: {'Miku', 'Teto'}), isEmpty);
  });
}
