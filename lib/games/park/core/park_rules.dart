/// 공원 길찾기 (수학 멘토링 '경우의 수와 민들레 게임' 9쪽 원본 문제).
///
/// 바둑판 모양 공원의 선분이 산책로, ○가 숲이다. 왼쪽 위 A에서 들어가 최단경로(오른쪽·아래로만)로
/// 오른쪽 아래 B로 나온다. 진행 방향의 바로 왼편에 숲이 있는 구간과 바로 오른편에 숲이 있는 구간이
/// 모두 한 번 이상 있어야 조건에 맞는 길이다.
library;

/// 한 걸음: 오른쪽(→) 또는 아래(↓).
enum Walk { right, down }

/// 한 구간을 걸을 때 숲이 어느 쪽에 붙어 있는가.
enum ForestSide { none, left, right }

/// 점(교차점) 좌표: 행·열 모두 0..n.
typedef Pt = (int, int);

class ParkStage {
  const ParkStage({required this.title, required this.size, required this.forests});

  final String title;

  /// 칸 수 (n×n 칸, 점은 (n+1)×(n+1)).
  final int size;

  /// 숲이 있는 칸 (행, 열).
  final Set<(int, int)> forests;

  Pt get start => (0, 0);
  Pt get goal => (size, size);

  bool _forest(int r, int c) => forests.contains((r, c));

  /// [from]에서 [step]으로 한 구간 걸을 때, 숲이 바로 왼편/오른편에 있는가.
  ///
  /// 오른쪽으로 걸으면 왼편은 위 칸, 오른편은 아래 칸.
  /// 아래로 걸으면 왼편은 동쪽(오른쪽) 칸, 오른편은 서쪽(왼쪽) 칸.
  ForestSide sideOf(Pt from, Walk step) {
    final (r, c) = from;
    final (left, right) = step == Walk.right ? ((r - 1, c), (r, c)) : ((r, c), (r, c - 1));
    if (_forest(left.$1, left.$2)) return ForestSide.left;
    if (_forest(right.$1, right.$2)) return ForestSide.right;
    return ForestSide.none;
  }

  /// 걸음들을 따라간 점들 (처음 A 포함).
  List<Pt> points(List<Walk> steps) {
    final out = <Pt>[start];
    for (final s in steps) {
      final (r, c) = out.last;
      out.add(s == Walk.right ? (r, c + 1) : (r + 1, c));
    }
    return out;
  }

  List<ForestSide> sides(List<Walk> steps) {
    final pts = points(steps);
    return [for (var i = 0; i < steps.length; i++) sideOf(pts[i], steps[i])];
  }

  bool isComplete(List<Walk> steps) => points(steps).last == goal;

  /// 조건에 맞는 길인가 (왼편 숲 구간과 오른편 숲 구간이 모두 있다).
  bool isValid(List<Walk> steps) {
    final s = sides(steps);
    return isComplete(steps) && s.contains(ForestSide.left) && s.contains(ForestSide.right);
  }

  /// 조건에 맞는 길의 수 (정답).
  int get answer {
    var n = 0;
    void go(List<Walk> path, int r, int c) {
      if (r == size && c == size) {
        if (isValid(path)) n++;
        return;
      }
      if (c < size) go([...path, Walk.right], r, c + 1);
      if (r < size) go([...path, Walk.down], r + 1, c);
    }

    go([], 0, 0);
    return n;
  }
}

/// 길을 글자로: 오른쪽 R, 아래 D (같은 길인지 비교하고, 사전식으로 정렬하는 데 쓴다). 예: "RRDD"
String pathKey(List<Walk> steps) => steps.map((s) => s == Walk.right ? 'R' : 'D').join();

final kParkStages = [
  ParkStage(title: '2×2', size: 2, forests: {(0, 0), (1, 1)}),
  ParkStage(title: '3×3', size: 3, forests: {(0, 0), (1, 1), (2, 2)}),
  ParkStage(title: '4×4', size: 4, forests: {(0, 0), (1, 1), (2, 2), (3, 3)}),
];
