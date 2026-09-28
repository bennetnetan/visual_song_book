import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/repositories/set_repository.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';
import 'package:visual_song_book/features/sets/sets_controller.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SetRepository setRepo;
  late SongRepository songRepo;
  late SetsController controller;

  setUp(() async {
    db = AppDatabase.forTesting();
    setRepo = SetRepository(db);
    songRepo = SongRepository(db);
    controller = SetsController(setRepo, songRepo);
    await settle();
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  test('plain text export produces clean concise format and can be re-imported', () async {
    // 1. Seed two songs
    final s1Id = await songRepo.addSong(
      SongsCompanion.insert(
        songNum: 101,
        title: 'Amazing Grace',
        body: 'Amazing grace how sweet the sound',
        key: const drift.Value('G'),
      ),
    );
    final s2Id = await songRepo.addSong(
      SongsCompanion.insert(
        songNum: 202,
        title: 'Holy Holy Holy',
        body: 'Holy holy holy Lord God Almighty',
        key: const drift.Value('C'),
      ),
    );
    await settle();

    // 2. Create a set and add songs
    final createdSet = await setRepo.createSet(
      'Sunday Morning Service',
      occasion: 'Youth',
    );
    await setRepo.addSongToSet(createdSet.id, s1Id, 0, key: 'A');
    await setRepo.addSongToSet(createdSet.id, s2Id, 1, key: 'Eb');
    await settle();

    // 3. Export to plain text
    final plainText = await controller.getSetPlainText(createdSet.id);
    expect(plainText, contains('Sunday Morning Service'));
    expect(plainText, contains('Youth'));
    expect(plainText, contains('1. Amazing Grace (#101) [Key: A]'));
    expect(plainText, contains('2. Holy Holy Holy (#202) [Key: Eb]'));
    expect(plainText, isNot(contains('how sweet the sound'))); // No lyrics!

    // 4. Import the copied plain text back
    await controller.importSetFromJson(plainText);
    await settle();

    // Verify imported set was created and selected
    expect(controller.state.selectedSetId, isNotNull);
    final selected = controller.selectedSet;
    expect(selected, isNotNull);
    expect(selected!.name, 'Sunday Morning Service');
    expect(selected.occasion, 'Youth');

    final items = await setRepo.getSetItems(selected.id);
    expect(items.length, 2);
    expect(items[0].songId, s1Id);
    expect(items[0].key, 'A');
    expect(items[1].songId, s2Id);
    expect(items[1].key, 'Eb');
  });

  test('plain text import works with minimal format (just numbered song list)', () async {
    await songRepo.addSong(
      SongsCompanion.insert(
        songNum: 42,
        title: 'Cornerstone',
        body: 'My hope is built on nothing less',
      ),
    );
    await settle();

    const pastedText = '''
Praise Night
18 Oct 2026

1. Cornerstone (#42) [Key: D]
''';

    await controller.importSetFromJson(pastedText);
    await settle();

    final selected = controller.selectedSet;
    expect(selected, isNotNull);
    expect(selected!.name, 'Praise Night');

    final items = await setRepo.getSetItems(selected.id);
    expect(items.length, 1);
    expect(items[0].key, 'D');
  });
}
