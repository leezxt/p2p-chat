import 'dart:async';

import 'package:flutter/foundation.dart';

import 'presence_client.dart';

class PresenceService extends ChangeNotifier {
  PresenceService({
    required PresenceClient client,
    required this.localDeviceId,
    required this.interval,
    DateTime Function()? clock,
  })  : _client = client,
        _clock = clock ?? DateTime.now;

  final PresenceClient _client;
  final String localDeviceId;
  final Duration interval;
  final DateTime Function() _clock;
  final Map<String, ContactPresence> _contacts = {};
  Timer? _timer;
  bool _enabled = false;
  bool _refreshing = false;

  bool get active => _enabled;

  Future<void> start() async {
    if (_enabled) return;
    _enabled = true;
    await _refreshSafely();
    if (!_enabled) return;
    _timer = Timer.periodic(interval, (_) => unawaited(_refreshSafely()));
  }

  void stop() {
    _enabled = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await _client.heartbeat(localDeviceId);
      final contacts = await _client.fetchContacts();
      _contacts
        ..clear()
        ..addEntries(contacts.map((item) => MapEntry(item.userId, item)));
      notifyListeners();
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refreshSafely() async {
    if (!_enabled) return;
    try {
      await refresh();
    } catch (_) {
      // Presence is best-effort and must not block local chat workflows.
    }
  }

  String labelFor(String userId) {
    final lastSeen = _contacts[userId]?.lastSeenAt;
    if (lastSeen == null) return '離線';
    final age = _clock().toUtc().difference(lastSeen.toUtc());
    if (age <= const Duration(seconds: 90)) return '在線';
    if (age <= const Duration(minutes: 5)) return '剛剛在線';
    return '離線';
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
