import 'package:flutter_test/flutter_test.dart';
import 'package:visual_song_book/data/db/songbook_db.dart';
import 'package:visual_song_book/data/repositories/set_repository.dart';
import 'package:visual_song_book/data/repositories/song_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SetRepository repo;
  late SongRepository songRepo;

  setUp(() {
    db = AppDatabase.forTesting();
    repo = SetRepository(db);
    songRepo = SongRepository(db);
  });

  tearDown(() => db.close());

  test('deleteSet removes the set and all of its items', () async {
    final set = await repo.createSet('Worship');
    final songId = await songRepo.addSong(
      SongsCompanion.insert(songNum: 1, title: 'Hymn', body: 'lyrics'),
    );
    await repo.addSongToSet(set.id, songId, 0);
    await repo.addSongToSet(set.id, songId, 1);

    expect(await repo.getSetItems(set.id), hasLength(2));
    expect(await repo.getAllSets(), hasLength(1));

    await repo.deleteSet(set.id);

    // Set row is gone.
    expect(await repo.getAllSets(), isEmpty);

    // All child SongSetItem rows are gone too (no orphaned items).
    expect(await repo.getSetItems(set.id), isEmpty);

    final orphanCount = db
        .select(db.songSetItems)
        ..where((t) => t.setId.equals(set.id));
    expect(await orphanCount.get(), isEmpty);
  });

  test('deleteSet for a missing set id is a safe no-op', () async {
    await repo.deleteSet(12345);
    expect(await repo.getAllSets(), isEmpty);
  });
}
