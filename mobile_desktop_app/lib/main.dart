import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

import 'app.dart';
import 'bootstrap.dart';

/// App 入口。依平台選擇 sqflite factory：
/// - Android / iOS：預設 [databaseFactory]。
/// - Windows / macOS / Linux 桌面副端：sqflite_common_ffi。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final DatabaseFactory factory;
  if (!Platform.isAndroid && !Platform.isIOS) {
    sqfliteFfiInit();
    factory = databaseFactoryFfi;
  } else {
    factory = databaseFactory;
  }

  const backendUrl = String.fromEnvironment('BACKEND_URL');
  const signalingUrl = String.fromEnvironment('SIGNALING_URL');
  const localDevKey = String.fromEnvironment('LOCAL_DEV_AUTH_KEY');
  final boot = await bootstrap(databaseFactory: factory, configValues: {
    if (backendUrl.isNotEmpty) 'backendUrl': backendUrl,
    if (signalingUrl.isNotEmpty) 'signalingUrl': signalingUrl,
    if (localDevKey.isNotEmpty) 'localDevKey': localDevKey,
  });
  runApp(P2pChatApp(routes: boot.routes, registry: boot.registry));
}
