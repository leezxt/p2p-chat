import 'package:flutter/material.dart';

String formatChatTime(
  BuildContext context,
  int epochSeconds, {
  DateTime? now,
}) {
  final dt = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  final current = now ?? DateTime.now();
  final sameDay = dt.year == current.year &&
      dt.month == current.month &&
      dt.day == current.day;

  final material = MaterialLocalizations.of(context);
  final time = material.formatTimeOfDay(
    TimeOfDay.fromDateTime(dt),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  if (sameDay) return time;

  return '${material.formatShortDate(dt)} $time';
}
