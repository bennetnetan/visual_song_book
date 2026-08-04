import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/repositories/set_repository.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';
import 'package:visual_song_book/features/history/history_controller.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

Future<bool> waitFor(bool Function() predicate, {Duration timeout = const Duration(seconds: 5)}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (predicate()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return predicate();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SongRepository songRepository;
  late SetRepository setRepository;
  late HistoryController controller;

  setUp(() {
    db = AppDatabase.forTesting();
    songRepository = SongRepository(db);
    setRepository = SetRepository(db);
    controller = HistoryController(songRepository, setRepository);
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  test('set and bible history refresh live and clear via controller', () async {
    await settle();

    final songSet = await setRepository.createSet('Sunday Service');

    await setRepository.recordSetProjection(songSet.id, songSet.name);
    await setRepository.recordBibleProjection('John 3:16', 'For God so loved...');

    final setSeen = await waitFor(() => controller.state.sets.isNotEmpty);
    expect(setSeen, isTrue);
    expect(controller.state.sets.first.setName, 'Sunday Service');

    final bibleSeen = await waitFor(() => controller.state.bible.isNotEmpty);
    expect(bibleSeen, isTrue);
    expect(controller.state.bible.first.reference, 'John 3:16');

    await controller.clearSetHistory();
    final setCleared = await waitFor(() => controller.state.sets.isEmpty);
    expect(setCleared, isTrue);

    await controller.clearBibleHistory();
    final bibleCleared = await waitFor(() => controller.state.bible.isEmpty);
    expect(bibleCleared, isTrue);
  });

  test('new projections appear without manual refresh', () async {
    await settle();

    final songSet = await setRepository.createSet('First Set');
    await setRepository.recordSetProjection(songSet.id, songSet.name);

    final first = await waitFor(() => controller.state.sets.length == 1);
    expect(first, isTrue);

    await Future<void>.delayed(const Duration(seconds: 1));
    final secondSet = await setRepository.createSet('Second Set');
    await setRepository.recordSetProjection(secondSet.id, secondSet.name);

    final second = await waitFor(() => controller.state.sets.length == 2);
    expect(second, isTrue);
    expect(controller.state.sets.first.setName, 'Second Set');
  });
}
