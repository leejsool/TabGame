/// 스도쿠 격자의 공통 상수와 도우미.
///
/// 칸 번호는 0~80 (행*9+열). 후보 숫자 집합은 9비트 마스크(숫자 1→bit0 … 9→bit8)로 다룬다.
const int kAllDigits = 0x1FF;

int bit(int digit) => 1 << (digit - 1);

int popCount(int mask) {
  var c = 0;
  while (mask != 0) {
    mask &= mask - 1;
    c++;
  }
  return c;
}

/// 마스크에 들어 있는 숫자들 (오름차순).
List<int> digitsOf(int mask) => [
      for (var d = 1; d <= 9; d++)
        if (mask & bit(d) != 0) d,
    ];

final List<int> rowOf = List.unmodifiable([for (var i = 0; i < 81; i++) i ~/ 9]);
final List<int> colOf = List.unmodifiable([for (var i = 0; i < 81; i++) i % 9]);
final List<int> boxOf = List.unmodifiable(
  [for (var i = 0; i < 81; i++) (i ~/ 27) * 3 + (i % 9) ~/ 3],
);

/// 27개 유닛: 0~8 = 행, 9~17 = 열, 18~26 = 박스. 각 유닛은 칸 번호 9개.
final List<List<int>> unitCells = List.unmodifiable([
  for (var r = 0; r < 9; r++)
    List<int>.unmodifiable([for (var c = 0; c < 9; c++) r * 9 + c]),
  for (var c = 0; c < 9; c++)
    List<int>.unmodifiable([for (var r = 0; r < 9; r++) r * 9 + c]),
  for (var b = 0; b < 9; b++)
    List<int>.unmodifiable([
      for (var i = 0; i < 9; i++) ((b ~/ 3) * 3 + i ~/ 3) * 9 + (b % 3) * 3 + i % 3,
    ]),
]);

/// 각 칸과 같은 행/열/박스에 있는 다른 칸 20개.
final List<List<int>> peers = List.unmodifiable([
  for (var i = 0; i < 81; i++) _peersOf(i),
]);

List<int> _peersOf(int i) {
  final s = <int>{};
  for (final u in [rowOf[i], 9 + colOf[i], 18 + boxOf[i]]) {
    s.addAll(unitCells[u]);
  }
  s.remove(i);
  return List.unmodifiable(s.toList()..sort());
}

/// 서로 다른 두 칸이 같은 행/열/박스에 있는가.
bool sees(int a, int b) =>
    a != b &&
    (rowOf[a] == rowOf[b] || colOf[a] == colOf[b] || boxOf[a] == boxOf[b]);

/// 두 칸을 모두 보는 칸들.
List<int> commonPeers(int a, int b) => [
      for (final p in peers[a])
        if (p != b && sees(p, b)) p,
    ];
