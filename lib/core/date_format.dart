/// 기록 목록에 쓰는 날짜 표시. 올해면 "10월 11일 16:04", 아니면 "2025년 12월 3일 09:30".
String formatDate(int epochMs, {DateTime? now}) {
  final d = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final today = now ?? DateTime.now();
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  final year = d.year == today.year ? '' : '${d.year}년 ';
  return '$year${d.month}월 ${d.day}일 $hh:$mm';
}
