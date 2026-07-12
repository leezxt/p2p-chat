import 'dart:async';
import 'dart:collection';

import '../../mailbox/domain/mailbox_refresh_service.dart';
import 'notification_launch_source.dart';
import 'push_notification_payload.dart';

class PushLaunchCoordinator {
  PushLaunchCoordinator({
    required NotificationLaunchSource source,
    required MailboxRefreshService mailbox,
    required Future<void> Function() openChatList,
    void Function(Object error, StackTrace stackTrace)? onError,
    this.maxRememberedLaunches = 128,
  })  : _source = source,
        _mailbox = mailbox,
        _openChatList = openChatList,
        _onError = onError;

  final NotificationLaunchSource _source;
  final MailboxRefreshService _mailbox;
  final Future<void> Function() _openChatList;
  final void Function(Object error, StackTrace stackTrace)? _onError;
  final int maxRememberedLaunches;
  final LinkedHashSet<String> _handledLaunchIds = LinkedHashSet<String>();
  Future<void> _pending = Future<void>.value();
  StreamSubscription<NotificationLaunch>? _subscription;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _subscription = _source.launches.listen((launch) {
      unawaited(
          handle(launch).catchError((Object error, StackTrace stackTrace) {
        _onError?.call(error, stackTrace);
      }));
    });
    final initial = await _source.initialLaunch();
    if (initial != null) await handle(initial);
  }

  Future<void> handle(NotificationLaunch launch) {
    final operation = _pending.then((_) => _handleOne(launch));
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _handleOne(NotificationLaunch launch) async {
    if (_handledLaunchIds.contains(launch.launchId) ||
        PushNotificationPayload.tryParse(launch.data) == null) {
      return;
    }
    if (launch.launchId.isEmpty) return;
    await _mailbox.refresh();
    await _openChatList();
    _remember(launch.launchId);
  }

  void _remember(String launchId) {
    _handledLaunchIds.add(launchId);
    while (_handledLaunchIds.length > maxRememberedLaunches) {
      _handledLaunchIds.remove(_handledLaunchIds.first);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
