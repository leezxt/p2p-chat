import 'dart:async';

import 'package:flutter/material.dart';

import 'core/lifecycle/app_lifecycle_coordinator.dart';
import 'core/module/module_lifecycle.dart';
import 'core/module/module_registry.dart';
import 'core/routing/route_registry.dart';
import 'modules/chat/chat_module.dart';

/// App 根 Widget。路由交由 [RouteRegistry]（各模組自行註冊）。
class P2pChatApp extends StatefulWidget {
  const P2pChatApp({super.key, required this.routes, required this.registry});

  final RouteRegistry routes;
  final ModuleRegistry registry;

  @override
  State<P2pChatApp> createState() => _P2pChatAppState();
}

class _P2pChatAppState extends State<P2pChatApp> with WidgetsBindingObserver {
  late final AppLifecycleCoordinator _lifecycle = AppLifecycleCoordinator(
    onBackground: () async {
      final presenceState = widget.registry.stateOf('presence');
      if (presenceState != null &&
          presenceState != ModuleState.sleeping &&
          presenceState != ModuleState.disabled) {
        await widget.registry.sleep('presence');
      }
      final state = widget.registry.stateOf('p2p');
      if (state != null &&
          state != ModuleState.sleeping &&
          state != ModuleState.disabled) {
        await widget.registry.sleep('p2p');
      }
    },
    onForeground: () async {
      final state = widget.registry.stateOf('presence');
      if (state != null &&
          state != ModuleState.active &&
          state != ModuleState.disabled) {
        await widget.registry.activate('presence');
      }
    },
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_handleLifecycle(AppLifecycleState.resumed));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_handleLifecycle(state));
  }

  Future<void> _handleLifecycle(AppLifecycleState state) async {
    try {
      await _lifecycle.handle(state);
    } catch (error, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'p2p lifecycle',
        context:
            ErrorDescription('while applying app lifecycle resource policy'),
      ));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.registry.disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P2P Messenger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3A6EA5),
        useMaterial3: true,
      ),
      // 首頁為聊天室列表（Chat Module 註冊的路由）。
      initialRoute: ChatModule.route,
      onGenerateRoute: widget.routes.onGenerateRoute,
    );
  }
}
