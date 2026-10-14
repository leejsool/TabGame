/// 콩나물 판의 "위상수학적" 숫자들: 점·선·영역·부분.
///
/// 어떤 판이든 항상 `점 + 영역 = 선 + 부분` 이 성립한다 (오일러의 공식).
/// - 점: 점의 수 (새로 찍힌 점 포함)
/// - 선: 점과 점 사이를 잇는 선의 수. 곡선 한 줄은 그 위의 새 점 때문에 선 두 개로 센다.
/// - 부분: 서로 이어진 덩어리의 수 (아직 아무것도 안 이은 점도 하나의 덩어리)
/// - 영역: 선으로 둘러싸여 막힌 빈 공간의 수 (바깥은 세지 않는다)
///
/// 점·선·부분은 세기만 하면 되고, 영역은 점에서 선을 따라 한 바퀴 도는 길(면)을 하나하나 찾아 센다.
/// (공식으로 거꾸로 계산하지 않고 따로 세므로, 숫자가 맞아떨어지는 것은 판이 올바른 평면 그림이라는 확인이다.)
library;

import 'sprouts_board.dart';
import 'sprouts_faces.dart';

class SproutsCounts {
  const SproutsCounts({required this.points, required this.lines, required this.regions, required this.parts});

  final int points, lines, regions, parts;

  int get left => points + regions;
  int get right => lines + parts;

  /// 오일러 공식이 맞는가.
  bool get balanced => left == right;

  @override
  String toString() => '점 $points + 영역 $regions = 선 $lines + 부분 $parts';
}

SproutsCounts countTopology(SproutsBoard b) {
  // 부분: 서로 이어진 덩어리 (곡선은 시작점–새 점–끝점을 잇는다)
  final parent = List<int>.generate(b.dots.length, (i) => i);
  int find(int x) {
    while (parent[x] != x) {
      parent[x] = parent[parent[x]];
      x = parent[x];
    }
    return x;
  }

  void union(int a, int c) => parent[find(a)] = find(c);
  for (final c in b.curves) {
    union(c.from, c.mid);
    union(c.mid, c.to);
  }
  final parts = {for (var i = 0; i < b.dots.length; i++) find(i)}.length;

  // 영역: 점과 선의 이어진 구조(평면 지도)에서 면을 하나하나 찾아 센다 (바깥은 뺀다).
  final regions = analyzeRegions(b).regions.length - 1;

  return SproutsCounts(
    points: b.dots.length,
    lines: b.curves.length * 2,
    regions: regions < 0 ? 0 : regions,
    parts: parts,
  );
}
