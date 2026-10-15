import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weeb_radar/data/app_state.dart';
import 'package:weeb_radar/data/sync_service.dart';
import 'package:weeb_radar/models/attended.dart';
import 'package:weeb_radar/models/event.dart';

Future<AppState> fresh() async {
  SharedPreferences.setMockInitialValues({});
  return AppState(await SharedPreferences.getInstance())..loadSettings();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('kopia zapasowa przenosi plany, „Byłem”, własne eventy i artystów na nowy telefon', () async {
    final old = await fresh();
    old.setPlan('pohoda-2026', Plan.going);
    old.saveAttended(
      Attended(id: 'own-1', artist: 'Animatsuri 2026', date: DateTime(2026, 7, 17), seen: ['VocaFest UK'], at: 0),
    );
    old.saveManualEvent(
      RadarEvent.fromJson({
        'id': 'moj-vocafest',
        'artist': 'Vocafest',
        'dateStart': '2027-03-01',
        'stops': [
          {'date': '2027-03-01', 'city': 'Londyn', 'cc': 'UK'},
        ],
      }, origin: EventOrigin.manual),
    );
    old.artists = [...old.artists, 'Jakiś Nowy Artysta'];
    final file = old.exportBackup();

    final phone = await fresh();
    final msg = phone.importBackup(file);
    expect(msg, contains('1 nowych planów'));
    expect(phone.entries['pohoda-2026']!.plan, Plan.going);
    expect(phone.attended.single.seen, ['VocaFest UK']);
    expect(phone.manualEvents.single.id, 'moj-vocafest');
    expect(phone.artists, contains('Jakiś Nowy Artysta'));

    // Drugie wczytanie niczego nie dubluje.
    expect(phone.importBackup(file), contains('0 nowych planów, 0 nowych wpisów'));
    expect(phone.manualEvents, hasLength(1));
    expect(() => phone.importBackup('{"app": "coś innego"}'), throwsFormatException);
    expect(() => phone.importBackup('śmieci'), throwsFormatException);
  });
}
