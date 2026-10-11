import 'dart:math';
import 'dart:ui';

/// 직소퍼즐 조각의 모양과 배치 (그림·화면과 무관한 순수 계산).
///
/// 좌표는 "이미지 좌표"(그림의 픽셀)를 쓴다. 이웃한 조각은 경계 곡선을 공유하므로
/// 한쪽이 볼록하면 반대쪽은 정확히 오목해서 빈틈 없이 맞물린다.
class JigsawGeometry {
  JigsawGeometry({
    required this.rows,
    required this.cols,
    required this.imageSize,
    required this.seed,
  }) {
    _build();
  }

  final int rows;
  final int cols;
  final Size imageSize;

  /// 같은 seed면 항상 같은 조각 모양이 나온다 (이어하기용).
  final int seed;

  int get count => rows * cols;
  double get cw => imageSize.width / cols;
  double get ch => imageSize.height / rows;

  /// 조각 i의 윤곽 (조각 상자 왼쪽 위를 (0,0)으로 한 좌표).
  late final List<Path> paths;

  /// 이미지 좌표에서 조각 i가 차지하는 상자.
  late final List<Rect> boxes;

  int indexOf(int row, int col) => row * cols + col;
  int rowOf(int i) => i ~/ cols;
  int colOf(int i) => i % cols;

  Rect cellRect(int row, int col) => Rect.fromLTWH(col * cw, row * ch, cw, ch);

  /// 목표 조각 수 [target]와 그림의 가로세로비로, 조각이 정사각형에 가깝게 되는 행·열 수.
  static (int rows, int cols) gridFor(int target, double aspect) {
    final cols = max(2, sqrt(target * aspect).round());
    final rows = max(2, (target / cols).round());
    return (rows, cols);
  }

  void _build() {
    final rng = Random(seed);
    // 가로 경계선(왼쪽→오른쪽)과 세로 경계선(위→아래). 바깥 테두리는 직선.
    final h = List.generate(rows + 1, (r) {
      return List.generate(cols, (c) {
        final a = Offset(c * cw, r * ch), b = Offset((c + 1) * cw, r * ch);
        return (r == 0 || r == rows) ? _straight(a, b) : _tabbed(a, b, rng);
      });
    });
    final v = List.generate(rows, (r) {
      return List.generate(cols + 1, (c) {
        final a = Offset(c * cw, r * ch), b = Offset(c * cw, (r + 1) * ch);
        return (c == 0 || c == cols) ? _straight(a, b) : _tabbed(a, b, rng);
      });
    });

    final ps = <Path>[];
    final bs = <Rect>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final path = Path()..moveTo(c * cw, r * ch);
        void add(List<Offset> pts) {
          for (var i = 1; i + 2 < pts.length; i += 3) {
            path.cubicTo(pts[i].dx, pts[i].dy, pts[i + 1].dx, pts[i + 1].dy,
                pts[i + 2].dx, pts[i + 2].dy);
          }
        }

        add(h[r][c]); // 위
        add(v[r][c + 1]); // 오른쪽
        add(h[r + 1][c].reversed.toList()); // 아래 (뒤집어서 오른쪽→왼쪽)
        add(v[r][c].reversed.toList()); // 왼쪽 (아래→위)
        path.close();
        final box = path.getBounds().inflate(3);
        ps.add(path.shift(-box.topLeft));
        bs.add(box);
      }
    }
    paths = List.unmodifiable(ps);
    boxes = List.unmodifiable(bs);
  }

  static List<Offset> _straight(Offset a, Offset b) =>
      [a, a + (b - a) / 3, a + (b - a) * 2 / 3, b];

  /// 볼록(탭)/오목 모양의 경계선. 점 목록은 [시작, (제어1, 제어2, 끝)...] 형태의 3차 베지어.
  static List<Offset> _tabbed(Offset a, Offset b, Random rng) {
    final d = b - a;
    final len = d.distance;
    final n = Offset(-d.dy, d.dx) / len; // 단위 법선
    final sign = rng.nextBool() ? 1.0 : -1.0;
    final shift = (rng.nextDouble() - 0.5) * 0.10; // 볼록이 놓이는 위치 흔들기
    final wide = 0.92 + rng.nextDouble() * 0.16; // 폭
    final tall = 0.92 + rng.nextDouble() * 0.16; // 높이

    Offset p(double u, double v) {
      final uu = 0.5 + shift + (u - 0.5) * wide;
      return a + d * uu + n * (v * len * tall * sign);
    }

    Offset line(double u) => a + d * u;

    final out = <Offset>[a];
    void seg(Offset c1, Offset c2, Offset end) => out.addAll([c1, c2, end]);

    final start = line(0.0), s1 = p(0.40, 0);
    seg(start + (s1 - start) / 3, start + (s1 - start) * 2 / 3, s1);
    seg(p(0.46, 0.02), p(0.44, 0.09), p(0.44, 0.12));
    seg(p(0.30, 0.16), p(0.30, 0.34), p(0.50, 0.34));
    seg(p(0.70, 0.34), p(0.70, 0.16), p(0.56, 0.12));
    seg(p(0.56, 0.09), p(0.54, 0.02), p(0.60, 0.00));
    final s2 = p(0.60, 0), end = line(1.0);
    seg(s2 + (end - s2) / 3, s2 + (end - s2) * 2 / 3, end);
    return out;
  }

  /// 조각 i의 로컬 좌표 [p] 가 조각 모양 안인가. (살짝 넉넉하게)
  bool containsLocal(int i, Offset p) => paths[i].contains(p);
}
