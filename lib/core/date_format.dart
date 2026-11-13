/// 기록 목록에 쓰는 날짜 표시. 올해면 "10월 11일", 아니면 "2025년 12월 3일".
/// (시·분은 넣지 않는다: 기록 한 줄의 작은 글씨가 두 줄로 넘어가지 않게)
String formatDate(int epochMs, {DateTime? now}) {
  final d = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final today = now ?? DateTime.now();
  final year = d.year == today.year ? '' : '${d.year}년 ';
  return '$year${d.month}월 ${d.day}일';
}
