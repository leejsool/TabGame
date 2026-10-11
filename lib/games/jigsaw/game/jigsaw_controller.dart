import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/jigsaw_geometry.dart';

/// 직소퍼즐 한 판의 상태: 조각 위치, 끌기, 딸깍 붙기, 힌트, 시간.
///
/// 좌표는 "탁자 좌표": 그림 크기의 [tableFactor]배 되는 넓은 탁자 위에 판(그림 자리)이 가운데 있고,
/// 조각들은 그 둘레에 흩어져 있다.
class JigsawController extends ChangeNotifier {
  JigsawController({
    required this.geometry,
    List<Offset>? positions,
    List<bool>? placed,
    List<int>? order,
    List<int>? groups,
    int elapsedSeconds = 0,
    this.ghost = true,
    int? scatterSeed,
    double? tableAspect,
  })  : tableAspect = tableAspect ?? geometry.imageSize.width / geometry.imageSize.height,
        pos = positions ?? List.filled(geometry.count, Offset.zero),
        placed = placed ?? List.filled(geometry.count, false),
        order = order ?? List.generate(geometry.count, (i) => i),
        group = groups ?? List.generate(geometry.count, (i) => i),
        elapsed = ValueNotifier<int>(elapsedSeconds) {
    if (positions == null) scatter(Random(scatterSeed));
    completed = this.placed.every((p) => p);
  }

  static const double tableFactor = 1.9;

  final JigsawGeometry geometry;

  /// 조각 i의 현재 위치 (조각 상자 왼쪽 위, 탁자 좌표).
  final List<Offset> pos;
  final List<bool> placed;

  /// 그리는 순서 (뒤로 갈수록 위에 보임).
  final List<int> order;

  /// 조각 i가 속한 덩어리 번호. 같은 번호끼리는 서로 맞붙은 채로 한꺼번에 움직인다.
  final List<int> group;

  final ValueNotifier<int> elapsed;

  /// 밑그림(희미한 완성 그림) 보이기.
  bool ghost;
  bool paused = false;
  bool completed = false;

  /// 지금 끌고 있는 조각.
  int? dragging;
  Offset _grab = Offset.zero;

  /// 방금 판에 붙거나 서로 이어진 조각들과 그 횟수 (애니메이션용).
  List<int> lastPlaced = const [];
  int placeSerial = 0;

  /// 지금 끌고 있는 덩어리의 조각들 ([dragging]이 속한 덩어리).
  List<int> dragMembers = const [];

  /// 힌트로 알려주는 조각 (몇 초 뒤 사라짐).
  int? hintPiece;
  int hintSerial = 0;

  /// 조각이 딸깍 붙었을 때 / 퍼즐을 완성했을 때 알림.
  void Function()? onSnap;
  VoidCallback? onCompleted;

  /// 탁자의 가로세로비(= 퍼즐을 하는 화면 영역의 비율). 화면 모양대로 탁자를 만들어
  /// 가로로 긴 그림을 세로 화면에서 해도 위아래 빈 공간 없이 조각을 흩어 놓을 수 있다.
  final double tableAspect;

  Size get tableSize {
    final w0 = geometry.imageSize.width * tableFactor;
    final h0 = geometry.imageSize.height * tableFactor;
    return Size(max(w0, h0 * tableAspect), max(h0, w0 / tableAspect));
  }

  /// 탁자 안에서 판(그림 자리)의 왼쪽 위.
  Offset get boardOffset => Offset(
        (tableSize.width - geometry.imageSize.width) / 2,
        (tableSize.height - geometry.imageSize.height) / 2,
      );

  Rect get boardRect => boardOffset & geometry.imageSize;

  /// 조각 i가 제자리에 있을 때의 위치.
  Offset targetPos(int i) => boardOffset + geometry.boxes[i].topLeft;

  int get placedCount => placed.where((p) => p).length;
  double get progress => placedCount / geometry.count;

  /// 조각이 이 거리 안으로 들어오면 딸깍 붙는다 (조각 한 칸 크기에 비례).
  double get snapDistance => 0.42 * min(geometry.cw, geometry.ch);

  // ── 흩어 놓기 ──

  /// 붙지 않은 조각들을 판 둘레에 무작위로 흩어 놓는다.
  void scatter(Random rng) {
    final table = tableSize;
    final board = boardRect.deflate(min(geometry.cw, geometry.ch) * 0.2);
    for (var i = 0; i < geometry.count; i++) {
      if (placed[i]) continue;
      group[i] = i; // 흩어 놓으면 이어진 덩어리도 다시 낱개가 된다
      final box = geometry.boxes[i];
      final w = box.width, h = box.height;
      Offset best = Offset.zero;
      for (var tries = 0; tries < 80; tries++) {
        final p = Offset(
          rng.nextDouble() * (table.width - w),
          rng.nextDouble() * (table.height - h),
        );
        best = p;
        if (!(p & Size(w, h)).overlaps(board)) break;
      }
      pos[i] = best;
    }
    // 흩어진 순서도 섞어서 어떤 조각이 위에 있을지 모르게
    final unplaced = [for (final i in order) if (!placed[i]) i]..shuffle(rng);
    final done = [for (final i in order) if (placed[i]) i];
    order
      ..clear()
      ..addAll(done)
      ..addAll(unplaced);
    notifyListeners();
  }

  // ── 끌기 ──

  /// 탁자 좌표 [p]에 있는 (붙지 않은) 맨 위 조각. 없으면 null.
  int? pieceAt(Offset p) {
    // 1순위: 조각 모양 안
    for (var k = order.length - 1; k >= 0; k--) {
      final i = order[k];
      if (placed[i]) continue;
      final local = p - pos[i];
      final size = geometry.boxes[i].size;
      if (local.dx < 0 || local.dy < 0 || local.dx > size.width || local.dy > size.height) {
        continue;
      }
      if (geometry.containsLocal(i, local)) return i;
    }
    // 2순위: 손가락이 살짝 빗나간 경우, 가까운 조각 중심
    int? nearest;
    var bestD = 0.45 * min(geometry.cw, geometry.ch);
    for (var k = order.length - 1; k >= 0; k--) {
      final i = order[k];
      if (placed[i]) continue;
      final center = pos[i] + (geometry.boxes[i].size).center(Offset.zero);
      final d = (center - p).distance;
      if (d < bestD) {
        bestD = d;
        nearest = i;
      }
    }
    return nearest;
  }

  /// 조각 [i]와 같은 덩어리의 모든 조각.
  List<int> membersOf(int i) {
    final g = group[i];
    return [for (var k = 0; k < group.length; k++) if (group[k] == g) k];
  }

  void beginDrag(int i, Offset tablePoint) {
    if (paused || completed || placed[i]) return;
    dragging = i;
    dragMembers = membersOf(i);
    _grab = pos[i] - tablePoint;
    // 덩어리 전체를 맨 위로 (원래 그려지던 순서는 유지)
    final members = {...dragMembers};
    final moved = [for (final j in order) if (members.contains(j)) j];
    order
      ..removeWhere(members.contains)
      ..addAll(moved);
    if (hintPiece != null && members.contains(hintPiece)) hintPiece = null;
    notifyListeners();
  }

  void dragTo(Offset tablePoint) {
    final i = dragging;
    if (i == null) return;
    final box = geometry.boxes[i];
    final table = tableSize;
    var delta = tablePoint + _grab - pos[i];
    // 덩어리 전체가 탁자 밖으로 너무 나가지 못하게
    var bounds = pos[i] & box.size;
    for (final m in dragMembers) {
      bounds = bounds.expandToInclude(pos[m] & geometry.boxes[m].size);
    }
    delta = Offset(
      delta.dx.clamp(-box.width * 0.5 - bounds.left, table.width - box.width * 0.5 - bounds.right),
      delta.dy.clamp(-box.height * 0.5 - bounds.top, table.height - box.height * 0.5 - bounds.bottom),
    );
    for (final m in dragMembers) {
      pos[m] += delta;
    }
    notifyListeners();
  }

  /// 손을 뗐을 때. 제자리 가까이면 딸깍 붙고, 이웃한 조각 가까이면 서로 이어진다.
  void endDrag() {
    final i = dragging;
    if (i == null) return;
    dragging = null;
    dragMembers = const [];
    final glow = <int>{};

    _joinNeighbors(i, glow);
    if ((pos[i] - targetPos(i)).distance <= snapDistance) {
      for (final m in membersOf(i)) {
        pos[m] = targetPos(m);
        placed[m] = true;
        glow.add(m);
      }
      // 붙은 조각은 맨 아래쪽(붙지 않은 조각들 밑)으로
      final fixed = [for (final j in order) if (placed[j]) j];
      final loose = [for (final j in order) if (!placed[j]) j];
      order
        ..clear()
        ..addAll(fixed)
        ..addAll(loose);
    }
    if (glow.isNotEmpty) {
      lastPlaced = glow.toList();
      placeSerial++;
      onSnap?.call();
      if (placed.every((p) => p)) {
        completed = true;
        hintPiece = null;
        notifyListeners();
        onCompleted?.call();
        return;
      }
    }
    notifyListeners();
  }

  /// [i]의 덩어리 안 조각 가운데 맞는 이웃이 가까이 있으면 그 덩어리와 합친다.
  /// 처음 합칠 때는 끌던 덩어리를 이웃에 맞춰 옮기고, 이어서 합치는 덩어리는 이쪽에 맞춘다.
  void _joinNeighbors(int i, Set<int> glow) {
    var movedMine = false;
    while (true) {
      int? bestM, bestN;
      var bestD = snapDistance;
      var bestShift = Offset.zero;
      for (final m in membersOf(i)) {
        for (final n in _neighbors(m)) {
          if (placed[n] || group[n] == group[m]) continue;
          final expected = pos[m] + (targetPos(n) - targetPos(m));
          final d = (pos[n] - expected).distance;
          if (d <= bestD) {
            bestD = d;
            bestM = m;
            bestN = n;
            bestShift = expected - pos[n];
          }
        }
      }
      if (bestM == null || bestN == null) return;
      final other = membersOf(bestN);
      if (!movedMine) {
        for (final m in membersOf(i)) {
          pos[m] -= bestShift;
        }
        movedMine = true;
      } else {
        for (final m in other) {
          pos[m] += bestShift;
        }
      }
      final g = group[bestM];
      for (final m in other) {
        group[m] = g;
      }
      glow
        ..addAll(membersOf(i))
        ..addAll(other);
    }
  }

  Iterable<int> _neighbors(int i) sync* {
    final r = geometry.rowOf(i), c = geometry.colOf(i);
    if (r > 0) yield geometry.indexOf(r - 1, c);
    if (r < geometry.rows - 1) yield geometry.indexOf(r + 1, c);
    if (c > 0) yield geometry.indexOf(r, c - 1);
    if (c < geometry.cols - 1) yield geometry.indexOf(r, c + 1);
  }

  // ── 도우미 ──

  void toggleGhost() {
    ghost = !ghost;
    notifyListeners();
  }

  /// 아직 안 붙은 조각 하나를 골라 그 조각과 제자리를 반짝여 알려준다.
  void giveHint(Random rng) {
    if (paused || completed) return;
    final unplaced = [for (var i = 0; i < geometry.count; i++) if (!placed[i]) i];
    if (unplaced.isEmpty) return;
    // 모서리·가장자리 조각을 먼저 권한다
    final edge = unplaced.where((i) {
      final r = geometry.rowOf(i), c = geometry.colOf(i);
      return r == 0 || c == 0 || r == geometry.rows - 1 || c == geometry.cols - 1;
    }).toList();
    final pool = edge.isNotEmpty ? edge : unplaced;
    hintPiece = pool[rng.nextInt(pool.length)];
    hintSerial++;
    final i = hintPiece!;
    order
      ..remove(i)
      ..add(i);
    notifyListeners();
  }

  void clearHint() {
    if (hintPiece == null) return;
    hintPiece = null;
    notifyListeners();
  }

  // ── 시계 ──

  void tick() {
    if (paused || completed) return;
    elapsed.value++;
  }

  void setPaused(bool v) {
    if (completed || paused == v) return;
    paused = v;
    notifyListeners();
  }

  // ── 저장 ──

  Map<String, dynamic> toJson() => {
        'rows': geometry.rows,
        'cols': geometry.cols,
        'seed': geometry.seed,
        'w': geometry.imageSize.width,
        'h': geometry.imageSize.height,
        'pos': [for (final p in pos) [p.dx, p.dy]],
        'placed': [for (final p in placed) p ? 1 : 0],
        'order': order,
        'group': group,
        'elapsed': elapsed.value,
        'ghost': ghost,
        'ta': tableAspect,
      };

  static JigsawController fromJson(Map<String, dynamic> j) {
    final geometry = JigsawGeometry(
      rows: j['rows'] as int,
      cols: j['cols'] as int,
      imageSize: Size((j['w'] as num).toDouble(), (j['h'] as num).toDouble()),
      seed: j['seed'] as int,
    );
    return JigsawController(
      geometry: geometry,
      positions: [
        for (final p in j['pos'] as List)
          Offset(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()),
      ],
      placed: [for (final v in j['placed'] as List) v == 1],
      order: List<int>.from(j['order'] as List),
      groups: j['group'] == null ? null : List<int>.from(j['group'] as List),
      elapsedSeconds: j['elapsed'] as int,
      ghost: j['ghost'] as bool,
      tableAspect: (j['ta'] as num?)?.toDouble(),
    );
  }

  @override
  void dispose() {
    elapsed.dispose();
    super.dispose();
  }
}
