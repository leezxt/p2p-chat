import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/config/config_service.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/core/resource_policy/resource_policy_service.dart';
import 'package:p2p_chat_app/l10n/app_localizations.dart';
import 'package:p2p_chat_app/modules/low_power/data/sqlite_low_power_preference_store.dart';
import 'package:p2p_chat_app/modules/low_power/domain/low_power_mode_changed.dart';
import 'package:p2p_chat_app/modules/low_power/domain/low_power_mode_service.dart';
import 'package:p2p_chat_app/modules/low_power/domain/low_power_preference_store.dart';
import 'package:p2p_chat_app/modules/low_power/presentation/low_power_settings_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('defaults off and emits an event when changed', () async {
    final config = ConfigService();
    final events = EventBus();
    final changes = <bool>[];
    events.on<LowPowerModeChanged>((event) => changes.add(event.enabled));
    final service = LowPowerModeService(
      store: _MemoryStore(),
      config: config,
      eventBus: events,
    );

    await service.load();
    expect(service.enabled, isFalse);
    await service.setEnabled(true);

    expect(config.lowPowerMode, isTrue);
    expect(changes, [false, true]);
    service.dispose();
  });

  test('preference survives database close and reopen', () async {
    final directory = await Directory.systemTemp.createTemp('p2p_low_power_');
    DatabaseService? database;
    try {
      database = _database();
      await database.open(directoryPath: directory.path);
      await SqliteLowPowerPreferenceStore(database.db).write(true);
      await database.close();

      database = _database();
      await database.open(directoryPath: directory.path);
      expect(await SqliteLowPowerPreferenceStore(database.db).read(), isTrue);
    } finally {
      await database?.close();
      await directory.delete(recursive: true);
    }
  });

  test('resource policy contracts in low power mode', () {
    final config = ConfigService(initial: {'autoDownloadImages': true});
    final policy = ResourcePolicyService(config);

    expect(policy.maxConcurrentP2pConnections, 3);
    expect(policy.presenceHeartbeatSeconds, 60);
    expect(policy.idleDisconnectAfter, const Duration(minutes: 2));
    expect(policy.autoDownloadImages, isTrue);
    expect(policy.keepP2pInBackground, isFalse);
    expect(policy.allowHeavyModuleAutoActivate(), isTrue);

    config.lowPowerMode = true;
    expect(policy.maxConcurrentP2pConnections, 1);
    expect(policy.presenceHeartbeatSeconds, 180);
    expect(policy.idleDisconnectAfter, const Duration(minutes: 1));
    expect(policy.autoDownloadImages, isFalse);
    expect(policy.keepP2pInBackground, isFalse);
    expect(policy.allowHeavyModuleAutoActivate(), isFalse);
  });

  testWidgets('settings switch updates the service in Traditional Chinese',
      (tester) async {
    final service = LowPowerModeService(
      store: _MemoryStore(),
      config: ConfigService(),
      eventBus: EventBus(),
    );
    await service.load();
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh', 'TW'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LowPowerSettingsPage(service: service),
    ));

    expect(find.text('低功耗模式已關閉'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(service.enabled, isTrue);
    expect(find.text('低功耗模式已開啟'), findsOneWidget);
    service.dispose();
  });
}

DatabaseService _database() => DatabaseService(
      databaseFactory: databaseFactoryFfi,
      logger: LoggingService(),
      fileName: 'low_power.db',
    );

class _MemoryStore implements LowPowerPreferenceStore {
  bool? value;

  @override
  Future<bool?> read() async => value;

  @override
  Future<void> write(bool enabled) async => value = enabled;
}
