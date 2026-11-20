import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class PlaylistRows extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()(); // xtream | m3u
  TextColumn get host => text().nullable()();
  TextColumn get m3uUrl => text().nullable()();
  TextColumn get epgUrl => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ChannelRows extends Table {
  TextColumn get key => text()(); // playlistId:kind:itemId
  TextColumn get playlistId => text()();
  TextColumn get kind => text()(); // live | vod | series
  IntColumn get streamId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get logoUrl => text().nullable()();
  TextColumn get category => text().withDefault(const Constant(''))();
  TextColumn get url => text()();
  TextColumn get containerExt => text().nullable()();
  TextColumn get tvgId => text().nullable()();
  IntColumn get num => integer().nullable()();
  TextColumn get seriesId => text().nullable()();
  TextColumn get seriesName => text().nullable()();
  IntColumn get season => integer().nullable()();
  IntColumn get episode => integer().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

class EpgRows extends Table {
  TextColumn get key => text()(); // playlistId:tvgId:startMillis
  TextColumn get playlistId => text()();
  TextColumn get channelTvgId => text()();
  TextColumn get channelKey => text()();
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get stop => dateTime()();
  TextColumn get title => text()();
  TextColumn get desc => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

class FavoriteRows extends Table {
  TextColumn get key => text()(); // profileId:kind:itemId:state
  TextColumn get profileId => text()();
  TextColumn get playlistId => text().nullable()();
  TextColumn get kind => text()();
  TextColumn get itemId => text()();
  TextColumn get title => text()();
  TextColumn get logoUrl => text().nullable()();
  TextColumn get state => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

class ProgressRows extends Table {
  TextColumn get key => text()(); // profileId:kind:itemId
  TextColumn get profileId => text()();
  TextColumn get playlistId => text().nullable()();
  TextColumn get kind => text()();
  TextColumn get itemId => text()();
  TextColumn get title => text()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

class ViewedRows extends Table {
  TextColumn get key => text()(); // profileId:kind:itemId
  TextColumn get profileId => text()();
  TextColumn get kind => text()();
  TextColumn get itemId => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

class MetaRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    PlaylistRows,
    ChannelRows,
    EpgRows,
    FavoriteRows,
    ProgressRows,
    ViewedRows,
    MetaRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<void> clearChannelsAndEpg(String playlistId) async {
    await (delete(channelRows)..where((r) => r.playlistId.equals(playlistId)))
        .go();
    await (delete(epgRows)..where((r) => r.playlistId.equals(playlistId))).go();
  }

  Future<void> insertAllChannels(List<ChannelRowsCompanion> rows) async {
    await batch((b) {
      b.insertAll(channelRows, rows, mode: InsertMode.insertOrReplace);
    });
  }

  Future<void> insertAllEpg(List<EpgRowsCompanion> rows) async {
    await batch((b) {
      b.insertAll(epgRows, rows, mode: InsertMode.insertOrReplace);
    });
  }

  Future<String?> meta(String key) async {
    final row =
        await (select(metaRows)..where((r) => r.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setMeta(String key, String value) async {
    into(metaRows).insertOnConflictUpdate(MetaRowsCompanion.insert(
      key: key,
      value: value,
    ));
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'openiptv.sqlite3'));
    return NativeDatabase.createInBackground(file);
  });
}
