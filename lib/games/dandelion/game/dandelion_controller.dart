import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/game_info.dart';
import '../core/dandelion_ai.dart';
import '../core/dandelion_rules.dart';

/// 민들레 한 판의 진행 (규칙 + CPU + 되돌리기).
class DandelionController extends ChangeNotifier {
  DandelionController({
    required this.mode,
    this.humanRole = Role.dandelion,
    this.level = DandLevel.normal,
  }) {
    _rebuild();
  }

  final PlayMode mode;

  /// CPU 대결에서 사람이 맡은 쪽.
  final Role humanRole;
  final DandLevel level;

  bool get vsCpu => mode == PlayMode.vsCpu;
  Role get cpuRole => humanRole.other;

  /// 지금까지 둔 수들 (민들레: 칸 번호, 바람: 방향 번호).
  final List<int> moves = [];

  late DandState state;
  bool thinking = false;

  /// 방금 심은 꽃의 칸 (없으면 -1).
  int lastPlanted = -1;

  /// 방금 분 바람의 방향과 그때 새로 생긴 씨앗들.
  WindDir? lastWind;
  List<Seeding> lastSeeds = const [];

  /// 수를 둘 때마다 늘어나는 번호 (애니메이션을 다시 시작하는 신호).
  int moveSerial = 0;

  int _epoch = 0;
  bool _disposed = false;
  final Random _rng = Random();

  /// 수를 둘 때/끝났을 때 알림 ('plant' | 'wind' | 'win').
  void Function(String kind)? onFeedback;

  bool get isOver => state.isOver;
  Role? get winner => state.winner;
  int get moveCount => moves.length;

  /// 지금 사람이 둘 수 있는가.
  bool get humanCanAct => !isOver && !thinking && (!vsCpu || state.turn == humanRole);

  void _rebuild() {
    state = DandState.fromMoves(moves);
  }

  /// 화면이 준비되면 부른다 (CPU가 민들레를 맡았다면 CPU가 먼저 꽃을 심는다).
  void start() => _maybeCpu();

  void restart() {
    moves.clear();
    thinking = false;
    lastPlanted = -1;
    lastWind = null;
    lastSeeds = const [];
    _epoch++;
    moveSerial++;
    _rebuild();
    notifyListeners();
    _maybeCpu();
  }

  // ── 두기 ──

  /// 사람이 칸 [cell]에 꽃을 심는다. 둘 수 없으면 false.
  bool plant(int cell) {
    if (!humanCanAct || !state.canPlant(cell)) return false;
    _apply(cell);
    _maybeCpu();
    return true;
  }

  /// 사람(바람)이 [dir] 방향으로 분다. 불 수 없으면 false.
  bool blow(WindDir dir) {
    if (!humanCanAct || !state.canBlow(dir)) return false;
    _apply(dir.index);
    _maybeCpu();
    return true;
  }

  void _apply(int move) {
    final planting = state.turn == Role.dandelion;
    moves.add(move);
    if (planting) {
      state.plant(move);
      lastPlanted = move;
      lastWind = null;
      lastSeeds = const [];
    } else {
      lastWind = WindDir.values[move];
      lastSeeds = state.blow(lastWind!);
      lastPlanted = -1;
    }
    moveSerial++;
    onFeedback?.call(state.isOver ? 'win' : (planting ? 'plant' : 'wind'));
    notifyListeners();
  }

  // ── CPU ──

  void _maybeCpu() {
    if (_disposed || !vsCpu || isOver || state.turn != cpuRole) return;
    _cpuTurn();
  }

  Future<void> _cpuTurn() async {
    final epoch = _epoch;
    thinking = true;
    notifyListeners();
    final args = [level.index, _rng.nextInt(1 << 30), ...moves];
    final results = await Future.wait([
      compute(_cpuTask, args),
      Future<void>.delayed(const Duration(milliseconds: 700)),
    ]);
    if (_disposed || epoch != _epoch) return;
    thinking = false;
    _apply(results[0] as int);
    _maybeCpu();
  }

  // ── 기권 ──

  /// 기권할 수 있는가 (한 수라도 둔 진행 중인 판).
  bool get canResign => !isOver && moves.isNotEmpty;

  /// 기권하는 쪽: CPU 대결이면 사람, 둘이서 할 때는 지금 차례인 쪽.
  Role get resigningRole => vsCpu ? humanRole : state.turn;

  /// 기권한다. CPU가 생각 중이었으면 그 수는 버린다. 기권했으면 true.
  bool resign() {
    if (!canResign) return false;
    _epoch++;
    thinking = false;
    notifyListeners();
    return true;
  }

  // ── 되돌리기 ──

  /// 되돌렸을 때의 수 개수 (되돌릴 수 없으면 null).
  int? get _undoTarget {
    if (moves.isEmpty || thinking) return null;
    if (!vsCpu) return moves.length - 1;
    // 사람 차례가 되는 가장 가까운 시점까지
    for (var k = moves.length - 1; k >= 0; k--) {
      final turn = k.isEven ? Role.dandelion : Role.wind;
      if (turn == humanRole) return k;
    }
    return null;
  }

  bool get canUndo => !isOver && _undoTarget != null;

  /// 내 마지막 수를 되돌린다. (CPU 대결이면 CPU의 응답 수까지 함께)
  void undo() {
    final k = _undoTarget;
    if (k == null || isOver) return;
    moves.length = k;
    _epoch++;
    _rebuild();
    lastPlanted = -1;
    lastWind = null;
    lastSeeds = const [];
    moveSerial++;
    notifyListeners();
    _maybeCpu();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// 다른 isolate에서 CPU의 수를 고른다. args = [난이도, seed, ...지금까지의 수]
int _cpuTask(List<int> args) {
  final state = DandState.fromMoves(args.sublist(2));
  return DandAi.choose(state, DandLevel.values[args[0]], Random(args[1]));
}
