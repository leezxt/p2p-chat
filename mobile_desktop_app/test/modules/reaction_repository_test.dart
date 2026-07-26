import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/modules/reaction/data/reaction_repository.dart';
import 'package:p2p_chat_app/modules/reaction/domain/reaction_event.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory directory;
  late DatabaseService database;
  late ReactionRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('p2p_reactions_');
    database = DatabaseService(
      databaseFactory: databaseFactoryFfi,
      logger: LoggingService(),
      fileName: 'test.db',
    );
    await database.open(directoryPath: directory.path);
    repository = ReactionRepository(database.db);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('duplicate and older events are idempotent', () async {
    final active = _event(id: 'event-2', active: true, updatedAt: 200);
    expect(await repository.apply(active), isTrue);
    expect(await repository.apply(active), isFalse);
    expect(
      await repository.apply(_event(
        id: 'event-old',
        active: false,
        updatedAt: 199,
      )),
      isFalse,
    );

    final reactions = await repository.listActiveForMessage('message-1');
    expect(reactions, hasLength(1));
    expect(reactions.single.active, isTrue);
  });

  test('newer removal hides the reaction and stale replay cannot restore it',
      () async {
    await repository.apply(_event(id: 'event-1', active: true, updatedAt: 100));
    await repository.apply(_event(
      id: 'event-2',
      active: false,
      updatedAt: 101,
    ));
    await repository.apply(_event(id: 'event-3', active: true, updatedAt: 100));

    expect(await repository.listActiveForMessage('message-1'), isEmpty);
  });

  test('event id deterministically breaks equal-timestamp ties', () async {
    await repository.apply(_event(id: 'event-a', active: true, updatedAt: 100));
    expect(
      await repository.apply(
        _event(id: 'event-b', active: false, updatedAt: 100),
      ),
      isTrue,
    );
    expect(
      await repository.apply(
        _event(id: 'event-aa', active: true, updatedAt: 100),
      ),
      isFalse,
    );
    expect(await repository.listActiveForMessage('message-1'), isEmpty);
  });
}

ReactionEvent _event({
  required String id,
  required bool active,
  required int updatedAt,
}) =>
    ReactionEvent(
      eventId: id,
      targetMessageId: 'message-1',
      reactorUserId: 'alice',
      emoji: '👍',
      active: active,
      updatedAt: updatedAt,
    );
