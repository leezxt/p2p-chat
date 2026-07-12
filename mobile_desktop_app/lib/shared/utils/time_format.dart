/// 將 Unix epoch 秒格式化為聊天室用的簡短時間字串。
///
/// 保持純函式、無 intl 依賴的最小實作，方便測試；正式版可換 intl 做在地化。
String formatChatTime(int epochSeconds, {DateTime? now}) {
  final dt = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  final current = now ?? DateTime.now();
  final sameDay = dt.year == current.year &&
      dt.month == current.month &&
      dt.day == current.day;

  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  if (sameDay) return '$hh:$mm';

  return '${dt.month}/${dt.day} $hh:$mm';
}
