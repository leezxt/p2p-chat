import 'dart:async';

import 'package:flutter/material.dart';

import 'core/lifecycle/app_lifecycle_coordinator.dart';
import 'core/module/module_lifecycle.dart';
import 'core/module/module_registry.dart';
import 'core/routing/route_registry.dart';
import 'core/di/service_locator.dart';
import 'modules/chat/chat_module.dart';
import 'modules/mailbox/domain/mailbox_refresh_service.dart';
import 'modules/push/domain/notification_launch_source.dart';
import 'modules/push/domain/push_launch_coordinator.dart';

/// App 根 Widget。路由交由 [RouteRegistry]（各模組自行註冊）。
class P2pChatApp extends StatefulWidget {
  const P2pChatApp({
    super.key,
    required this.routes,
    required this.registry,
    required this.services,
    this.notificationLaunchSource = const NoopNotificationLaunchSource(),
  });

  final RouteRegistry routes;
  final ModuleRegistry registry;
  final ServiceLocator services;
  final NotificationLaunchSource notificationLaunchSource;

  @override
  State<P2pChatApp> createState() => _P2pChatAppState();
}

class _P2pChatAppState extends State<P2pChatApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  PushLaunchCoordinator? _pushLaunchCoordinator;
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
    if (widget.services.isRegistered<MailboxRefreshService>()) {
      _pushLaunchCoordinator = PushLaunchCoordinator(
        source: widget.notificationLaunchSource,
        mailbox: widget.services.get<MailboxRefreshService>(),
        openChatList: () async {
          final navigator = _navigatorKey.currentState;
          if (navigator != null) {
            unawaited(navigator.pushNamedAndRemoveUntil(
                ChatModule.route, (route) => false));
          }
        },
        onError: (error, stackTrace) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'p2p push',
            context: ErrorDescription('while handling notification launch'),
          ));
        },
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_pushLaunchCoordinator?.start());
      });
    }
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
    unawaited(_pushLaunchCoordinator?.dispose());
    widget.registry.disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
