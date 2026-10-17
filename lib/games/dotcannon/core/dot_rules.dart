/// 도트 캐논의 규칙 (화면·시간과 상관없는 순수한 계산).
///
/// 액자 속 도트 그림을 둘러싼 컨베이어 벨트가 시계 방향으로 돌고, 벨트에 올린 대포는 한 칸 갈 때마다
/// 마주 보는 줄에서 "가장 바깥에 보이는 도트"가 자기 색이면 한 발 쏘아 지운다.
/// 대포는 탄이 다 떨어지면 사라지고, 그림을 다 지우면 이긴다.
library;

import 'dart:math';

/// 빈 칸.
const int kDotEmpty = -1;

/// 대포 한 대. 같은 색 도트를 [ammo]발까지 지울 수 있다.
class Cannon {
  Cannon({required this.id, required this.color, required this.ammo, required this.column, this.pos = -1, this.steps = 0});

  final int id;
  final int color;
  int ammo;

  /// 처음 줄 선 열 (대기열 번호).
  final int column;

  /// 벨트 위 자리 (대기 중이면 -1).
  int pos;

  /// 벨트에 오른 뒤 움직인 칸 수.
  int steps;

  Map<String, dynamic> toJson() => {'i': id, 'c': color, 'a': ammo, 'k': column, 'p': pos, 's': steps};

  static Cannon fromJson(Map<String, dynamic> j) => Cannon(
        id: j['i'] as int,
        color: j['c'] as int,
        ammo: j['a'] as int,
        column: j['k'] as int,
        pos: j['p'] as int,
        steps: j['s'] as int,
      );
}

/// 한 발: 벨트 자리 [from]에서 그림 칸 ([tx], [ty])의 도트를 맞혔다.
class Shot {
  const Shot({required this.cannonId, required this.color, required this.from, required this.tx, required this.ty});

  final int cannonId;
  final int color;
  final int from;
  final int tx;
  final int ty;
}

class DotGame {
  DotGame({
    required this.width,
    required this.height,
    required this.grid,
    required this.queue,
    this.capacity = 5,
    List<Cannon>? belt,
    this.stepCount = 0,
    this.deploys = 0,
  })  : belt = belt ?? [],
        remaining = grid.where((c) => c != kDotEmpty).length;

  final int width;
  final int height;

  /// 그림 칸의 색 번호 (줄 단위로 이어 붙임). 지워진 칸은 [kDotEmpty].
  final List<int> grid;

  /// 대기열. 열마다 맨 앞(0번)이 눌러서 벨트에 올릴 수 있는 대포다.
  final List<List<Cannon>> queue;

  /// 벨트에 한꺼번에 올려 둘 수 있는 대포 수.
  final int capacity;

  final List<Cannon> belt;
  int stepCount;
  int deploys;
  int remaining;

  /// 벨트 한 바퀴의 칸 수 (그림 둘레 + 네 모서리).
  int get ringLength => 2 * (width + height) + 4;

  /// 대포가 벨트에 오르는 자리 (왼쪽 아래 모서리).
  int get entryPos => 2 * width + height + 3;

  bool get won => remaining == 0;

  /// 벨트 자리 [i]의 좌표. 그림 칸은 0..width-1, 0..height-1이고 벨트는 그 바깥 한 줄이다.
  (int, int) ringCell(int i) {
    final w = width, h = height;
    if (i <= w + 1) return (i - 1, -1);
    if (i <= w + h + 1) return (w, i - (w + 2));
    if (i == w + h + 2) return (w, h);
    if (i <= 2 * w + h + 2) return (w - 1 - (i - (w + h + 3)), h);
    if (i == 2 * w + h + 3) return (-1, h);
    return (-1, h - 1 - (i - (2 * w + h + 4)));
  }

  /// 벨트 자리 [i]에서 쏘는 방향 (그림 쪽). 모서리에서는 쏘지 않는다.
  (int, int)? facing(int i) {
    final (x, y) = ringCell(i);
    if (y == -1 && x >= 0 && x < width) return (0, 1);
    if (x == width && y >= 0 && y < height) return (-1, 0);
    if (y == height && x >= 0 && x < width) return (0, -1);
    if (x == -1 && y >= 0 && y < height) return (1, 0);
    return null;
  }

  /// 벨트 자리 [i]에서 쏘면 맞는 그림 칸의 번호 (없으면 -1).
  int target(int i) {
    final f = facing(i);
    if (f == null) return -1;
    final (x, y) = ringCell(i);
    var cx = x + f.$1, cy = y + f.$2;
    while (cx >= 0 && cy >= 0 && cx < width && cy < height) {
      final idx = cy * width + cx;
      if (grid[idx] != kDotEmpty) return idx;
      cx += f.$1;
      cy += f.$2;
    }
    return -1;
  }

  bool canDeploy(int column) =>
      column >= 0 &&
      column < queue.length &&
      queue[column].isNotEmpty &&
      belt.length < capacity &&
      !belt.any((c) => c.pos == entryPos);

  /// 열 [column]의 맨 앞 대포를 벨트에 올린다.
  bool deploy(int column) {
    if (!canDeploy(column)) return false;
    final c = queue[column].removeAt(0);
    c.pos = entryPos;
    c.steps = 0;
    belt.add(c);
    deploys++;
    return true;
  }

  /// 벨트를 한 칸 돌린다. 이번에 쏜 탄들을 돌려준다.
  List<Shot> step() {
    final shots = <Shot>[];
    stepCount++;
    final len = ringLength;
    for (final c in List<Cannon>.of(belt)) {
      c.pos = (c.pos + 1) % len;
      c.steps++;
      final t = target(c.pos);
      if (t >= 0 && grid[t] == c.color) {
        grid[t] = kDotEmpty;
        remaining--;
        c.ammo--;
        shots.add(Shot(cannonId: c.id, color: c.color, from: c.pos, tx: t % width, ty: t ~/ width));
      }
      if (c.ammo <= 0) belt.remove(c);
    }
    return shots;
  }

  /// 바깥(네 방향 중 하나)에서 보이는 도트들의 칸 번호.
  Set<int> exposedCells() {
    final out = <int>{};
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (grid[y * width + x] != kDotEmpty) {
          out.add(y * width + x);
          break;
        }
      }
      for (var x = width - 1; x >= 0; x--) {
        if (grid[y * width + x] != kDotEmpty) {
          out.add(y * width + x);
          break;
        }
      }
    }
    for (var x = 0; x < width; x++) {
      for (var y = 0; y < height; y++) {
        if (grid[y * width + x] != kDotEmpty) {
          out.add(y * width + x);
          break;
        }
      }
      for (var y = height - 1; y >= 0; y--) {
        if (grid[y * width + x] != kDotEmpty) {
          out.add(y * width + x);
          break;
        }
      }
    }
    return out;
  }

  /// 지금 쏠 수 있는(바깥에서 보이는) 도트가 있는 색들.
  Set<int> exposedColors() => {for (final i in exposedCells()) grid[i]};

  /// 남은 도트 수 (색별).
  List<int> remainingByColor(int colors) {
    final out = List<int>.filled(colors, 0);
    for (final c in grid) {
      if (c != kDotEmpty) out[c]++;
    }
    return out;
  }

  /// 더 지울 방법이 없는가: 벨트의 대포도, 대기열 앞의 대포도 지금 보이는 도트를 맞힐 수 없다.
  /// (맞히지 못하는 대포를 먼저 올려 대기열을 파 내려가도 그림은 그대로이니, 올릴 자리가 모자랄 때만 막힌 것이다.)
  bool get stuck {
    if (won) return false;
    final ex = exposedColors();
    if (belt.any((c) => ex.contains(c.color))) return false;
    final free = capacity - belt.length;
    if (free <= 0) return true;
    for (final col in queue) {
      final d = col.indexWhere((c) => ex.contains(c.color));
      if (d >= 0 && d < free) return false;
    }
    return true;
  }

  /// 대기 중인 대포 수.
  int get waiting => queue.fold(0, (s, q) => s + q.length);

  Map<String, dynamic> toJson() => {
        'grid': grid,
        'queue': [
          for (final q in queue) [for (final c in q) c.toJson()],
        ],
        'belt': [for (final c in belt) c.toJson()],
        'cap': capacity,
        'w': width,
        'h': height,
        'step': stepCount,
        'dep': deploys,
      };

  static DotGame fromJson(Map<String, dynamic> j) => DotGame(
        width: j['w'] as int,
        height: j['h'] as int,
        grid: List<int>.from(j['grid'] as List),
        queue: [
          for (final q in j['queue'] as List) [for (final c in q as List) Cannon.fromJson(c as Map<String, dynamic>)],
        ],
        capacity: j['cap'] as int,
        belt: [for (final c in j['belt'] as List) Cannon.fromJson(c as Map<String, dynamic>)],
        stepCount: j['step'] as int,
        deploys: j['dep'] as int,
      );

  DotGame copy() => DotGame.fromJson(toJson());
}

/// 그림의 색별 도트 수만큼 탄을 나눠 대포를 만들고, 대기열 [columns]개에 섞어서 세운다.
///
/// 한 대포의 탄은 [ammoLo]..[ammoHi] 사이다. 색마다 탄 합계가 도트 수와 같아서, 대포를 다 쓰면 그림이 다 지워진다.
List<List<Cannon>> buildQueue(
  List<int> grid,
  int colors, {
  required int columns,
  required int ammoLo,
  required int ammoHi,
  required int seed,
}) {
  final rnd = Random(seed);
  final counts = List<int>.filled(colors, 0);
  for (final c in grid) {
    if (c != kDotEmpty) counts[c]++;
  }
  final cannons = <Cannon>[];
  var id = 0;
  for (var color = 0; color < colors; color++) {
    var left = counts[color];
    while (left > 0) {
      int take;
      if (left <= ammoHi) {
        take = left;
      } else {
        take = ammoLo + rnd.nextInt(ammoHi - ammoLo + 1);
        if (left - take < ammoLo) take = left - ammoLo;
      }
      cannons.add(Cannon(id: id++, color: color, ammo: take, column: 0));
      left -= take;
    }
  }
  cannons.shuffle(rnd);
  final queue = List.generate(columns, (_) => <Cannon>[]);
  final out = <Cannon>[];
  for (var i = 0; i < cannons.length; i++) {
    final c = cannons[i];
    out.add(Cannon(id: c.id, color: c.color, ammo: c.ammo, column: i % columns));
  }
  for (final c in out) {
    queue[c.column].add(c);
  }
  return queue;
}

/// 시험·검증용: 간단한 규칙으로 지금 벨트에 올릴 대포의 열을 고른다 (올릴 대포가 없으면 null).
///
/// 규칙: 지금 보이는 도트의 색과 같은 대포가 대기열 앞에 있으면 올린다(보이는 도트를 가장 많이 맞힐 대포부터).
/// 벨트의 대포가 아무도 맞힐 수 없고 앞에도 맞힐 대포가 없으면, 맞힐 수 있는 대포가 가장 얕게 있는 열의 앞 대포를 올려 파 내려간다.
int? botPick(DotGame g) {
  if (g.belt.length >= g.capacity || g.belt.any((c) => c.pos == g.entryPos)) return null;
  final ex = g.exposedCells();
  final exColors = {for (final i in ex) g.grid[i]};
  var bestCol = -1, bestScore = 0;
  for (var col = 0; col < g.queue.length; col++) {
    if (g.queue[col].isEmpty) continue;
    final c = g.queue[col].first;
    if (!exColors.contains(c.color)) continue;
    // 이미 벨트에 같은 색이 탄을 넉넉히 들고 있으면 또 올릴 필요가 없다
    final onBelt = g.belt.where((b) => b.color == c.color).fold<int>(0, (s, b) => s + b.ammo);
    final visible = ex.where((i) => g.grid[i] == c.color).length;
    if (onBelt >= visible) continue;
    final score = min(c.ammo, visible) * 100 + c.ammo;
    if (score > bestScore) {
      bestScore = score;
      bestCol = col;
    }
  }
  if (bestCol >= 0) return bestCol;
  // 벨트가 맞힐 수 없고 올릴 대포도 없으면 파 내려간다
  if (!g.belt.any((c) => exColors.contains(c.color))) {
    final free = g.capacity - g.belt.length;
    var digCol = -1, bestDepth = 1 << 30;
    for (var col = 0; col < g.queue.length; col++) {
      final d = g.queue[col].indexWhere((c) => exColors.contains(c.color));
      if (d >= 0 && d < bestDepth && d < free) {
        bestDepth = d;
        digCol = col;
      }
    }
    if (digCol >= 0 && bestDepth > 0) return digCol;
  }
  return null;
}

/// 시험·검증용: [botPick]의 규칙으로 판을 끝까지 돌려 본다. 이기면 true (= 풀 수 있는 판).
bool botSolves(DotGame g, {int maxSteps = 40000}) {
  while (g.stepCount < maxSteps) {
    if (g.won) return true;
    if (g.stuck) return false;
    final col = botPick(g);
    if (col != null && g.deploy(col)) continue;
    g.step();
  }
  return false;
}
