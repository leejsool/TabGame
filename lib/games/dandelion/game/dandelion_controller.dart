import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/game_info.dart';
import '../../../versus/cpu_turn.dart';
import '../core/dandelion_ai.dart';
import '../core/dandelion_rules.dart';

/// 민들레 한 판의 진행 (규칙 + CPU + 되돌리기).
/// 같은 Wi‑Fi 대결([PlayMode.wifi])에서는 내 수를 [onLocalMove]로 알리고, 상대의 수는 [receiveMove]로 받는다.
class DandelionController extends ChangeNotifier {
  DandelionController({
    required this.mode,
    this.humanRole = Role.dandelion,
    this.level = DandLevel.normal,
  }) {
    _rebuild();
  }

  /// 저장해 둔 판([toJson])을 되살린다 (한 기기·CPU 대결). 맞지 않는 내용이면 null.
  static DandelionController? fromJson(Map<String, dynamic> j) {
    try {
      final mode = PlayMode.values.byName(j['mode'] as String);
      if (mode != PlayMode.vsCpu && mode != PlayMode.local2p) return null;
      final roleIndex = j['humanRole'] as int, levelIndex = j['level'] as int;
      if (roleIndex < 0 || roleIndex >= Role.values.length || levelIndex < 0 || levelIndex >= DandLevel.values.length) return null;
      final moves = [for (final m in j['moves'] as List) m as int];
      // 수를 하나씩 다시 둔다 (둘 수 없는 수가 끼어 있으면 저장이 깨진 것)
      final check = DandState.fromMoves(const []);
      for (final m in moves) {
        final ok = check.turn == Role.dandelion
            ? m >= 0 && m < check.cells.length && check.canPlant(m)
            : m >= 0 && m < WindDir.values.length && check.canBlow(WindDir.values[m]);
        if (!ok) return null;
        check.apply(m);
      }
      final c = DandelionController(mode: mode, humanRole: Role.values[roleIndex], level: DandLevel.values[levelIndex]);
      c.moves.addAll(moves);
      c._rebuild();
      c.moveSerial = moves.length;
      return c;
    } catch (_) {
      return null;
    }
  }

  /// 지금 판의 모습을 JSON으로 (이어하기용). 수들만 있으면 판이 그대로 되살아난다.
  Map<String, dynamic> toJson() => {
        'v': 1,
        'mode': mode.name,
        'humanRole': humanRole.index,
        'level': level.index,
        'moves': moves,
      };

  /// 이어하기로 보관할 만한 판인가 (같은 Wi‑Fi가 아니고, 한 수라도 뒀고, 끝나지 않았다).
  bool get savable => !online && !isOver && !halted && moves.isNotEmpty;

  final PlayMode mode;

  /// CPU 대결·Wi‑Fi 대결에서 내가 맡은 쪽. Wi‑Fi 대결은 한 판 더 할 때마다 서로 바뀐다 (민들레와 바람은 유불리가 달라서).
  Role humanRole;
  final DandLevel level;

  bool get vsCpu => mode == PlayMode.vsCpu;

  /// 같은 Wi‑Fi의 다른 기기와 겨루는 판인가.
  bool get online => mode == PlayMode.wifi;

  /// 이 기기에서 한쪽만 맡는 판인가 (CPU 대결이거나 Wi‑Fi 대결).
  bool get oneSeat => vsCpu || online;
  Role get cpuRole => humanRole.other;

  /// 내가 둔 수를 알린다 (Wi‑Fi 대결에서 상대에게 보내려고).
  void Function(int move)? onLocalMove;

  /// 누군가 기권해서 중단된 판인가 (더는 둘 수 없다. [restart]하면 풀린다).
  bool halted = false;

  /// 지금까지 둔 수들 (민들레: 칸 번호, 바람: 방향 번호).
  final List<int> moves = [];

  late DandState state;
  final CpuTurnRunner _cpu = CpuTurnRunner();

  /// CPU가 수를 고르는 중인가.
  bool get thinking => _cpu.thinking;

  /// 방금 심은 꽃의 칸 (없으면 -1).
  int lastPlanted = -1;

  /// 방금 분 바람의 방향과 그때 새로 생긴 씨앗들.
  WindDir? lastWind;
  List<Seeding> lastSeeds = const [];

  /// 수를 둘 때마다 늘어나는 번호 (애니메이션을 다시 시작하는 신호).
  int moveSerial = 0;

  final Random _rng = Random();

  /// 수를 둘 때/끝났을 때 알림 ('plant' | 'wind' | 'win').
  void Function(String kind)? onFeedback;

  bool get isOver => state.isOver;
  Role? get winner => state.winner;
  int get moveCount => moves.length;

  /// 지금 사람이 둘 수 있는가.
  bool get humanCanAct => !isOver && !halted && !thinking && (!oneSeat || state.turn == humanRole);

  void _rebuild() {
    state = DandState.fromMoves(moves);
  }

  /// 화면이 준비되면 부른다 (CPU가 민들레를 맡았다면 CPU가 먼저 꽃을 심는다).
  void start() => _maybeCpu();

  /// 새 판을 시작한다. [swapRoles]면 내가 맡은 쪽을 바꾼다 (Wi‑Fi 대결의 한 판 더).
  void restart({bool swapRoles = false}) {
    if (swapRoles) humanRole = humanRole.other;
    halted = false;
    moves.clear();
    lastPlanted = -1;
    lastWind = null;
    lastSeeds = const [];
    _cpu.cancel();
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
    onLocalMove?.call(cell);
    _maybeCpu();
    return true;
  }

  /// 사람(바람)이 [dir] 방향으로 분다. 불 수 없으면 false.
  bool blow(WindDir dir) {
    if (!humanCanAct || !state.canBlow(dir)) return false;
    _apply(dir.index);
    onLocalMove?.call(dir.index);
    _maybeCpu();
    return true;
  }

  /// 상대 기기에서 온 수를 둔다 (Wi‑Fi 대결: 칸 번호 또는 바람 방향 번호). 상대 차례가 아니거나 둘 수 없는 수면 false
  /// (그러면 판이 어긋난 것이다).
  bool receiveMove(int move) {
    if (!online || isOver || halted || state.turn == humanRole) return false;
    if (state.turn == Role.dandelion) {
      if (move < 0 || move >= state.cells.length || !state.canPlant(move)) return false;
    } else {
      if (move < 0 || move >= WindDir.values.length || !state.canBlow(WindDir.values[move])) return false;
    }
    _apply(move);
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
    if (_cpu.disposed || !(vsCpu || cpuCover) || isOver || state.turn != cpuRole) return;
    _cpuTurn();
  }

  // ── 상대가 나갔을 때 (같은 Wi‑Fi 판) ──

  /// 나간 상대의 자리를 CPU가 대신 두고 있는가 (방장 기기에서만 켠다).
  bool cpuCover = false;

  /// 나간 상대 자리를 CPU가 대신 맡는다. 지금이 상대 차례이면 CPU가 바로 둔다.
  void coverOpponent() {
    if (!online || cpuCover) return;
    cpuCover = true;
    notifyListeners();
    _maybeCpu();
  }

  /// 돌아온 상대에게 자리를 돌려준다. CPU가 수를 고르는 중이었으면 버린다.
  void uncoverOpponent() {
    if (!cpuCover) return;
    cpuCover = false;
    _cpu.cancel();
    notifyListeners();
  }

  /// 같은 Wi‑Fi 판의 지금 모습 (다시 들어오는 상대에게 보낸다). 수들만 있으면 판이 그대로 되살아난다.
  Map<String, dynamic> wifiSnapshot() => {
        'guestRole': cpuRole.index, // 돌아오는 상대가 맡은 쪽
        'level': level.index,
        'moves': [...moves],
      };

  /// [wifiSnapshot]으로 판을 되살린다 (돌아온 상대 쪽 기기). 맞지 않는 내용이면 null.
  static DandelionController? fromWifiSnapshot(Map<String, dynamic> j) {
    try {
      final roleIndex = j['guestRole'] as int, levelIndex = j['level'] as int;
      if (roleIndex < 0 || roleIndex >= Role.values.length || levelIndex < 0 || levelIndex >= DandLevel.values.length) return null;
      final moves = [for (final m in j['moves'] as List) m as int];
      final check = DandState.fromMoves(const []);
      for (final m in moves) {
        final ok = check.turn == Role.dandelion
            ? m >= 0 && m < check.cells.length && check.canPlant(m)
            : m >= 0 && m < WindDir.values.length && check.canBlow(WindDir.values[m]);
        if (!ok) return null;
        check.apply(m);
      }
      final c = DandelionController(mode: PlayMode.wifi, humanRole: Role.values[roleIndex], level: DandLevel.values[levelIndex]);
      c.moves.addAll(moves);
      c._rebuild();
      c.moveSerial = moves.length;
      return c;
    } catch (_) {
      return null;
    }
  }

  Future<void> _cpuTurn() async {
    final args = [level.index, _rng.nextInt(1 << 30), ...moves];
    final move = await _cpu.run(
      task: () => compute(_cpuTask, args),
      minTime: const Duration(milliseconds: 700),
      onStart: notifyListeners,
    );
    if (move == null) return;
    _apply(move);
    _maybeCpu();
  }

  // ── 기권 ──

  /// 기권할 수 있는가 (한 수라도 둔 진행 중인 판).
  bool get canResign => !isOver && !halted && moves.isNotEmpty;

  /// 기권하는 쪽: CPU 대결·Wi‑Fi 대결이면 나, 둘이서 할 때는 지금 차례인 쪽.
  Role get resigningRole => oneSeat ? humanRole : state.turn;

  /// 기권한다. CPU가 생각 중이었으면 그 수는 버린다. 기권했으면 true.
  bool resign() {
    if (!canResign) return false;
    _cpu.cancel();
    halted = true;
    notifyListeners();
    return true;
  }

  /// 상대가 기권했다는 소식을 받았다 (Wi‑Fi 대결). 판은 거기서 멈춘다.
  void opponentResigned() {
    if (!online || isOver || halted) return;
    halted = true;
    notifyListeners();
  }

  // ── 되돌리기 ──

  /// 되돌렸을 때의 수 개수 (되돌릴 수 없으면 null).
  int? get _undoTarget {
    if (moves.isEmpty || thinking || online || halted) return null; // (Wi‑Fi 대결은 되돌릴 수 없다)
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
    _cpu.cancel();
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
    _cpu.dispose();
    super.dispose();
  }
}

/// 다른 isolate에서 CPU의 수를 고른다. args = [난이도, seed, ...지금까지의 수]
int _cpuTask(List<int> args) {
  final state = DandState.fromMoves(args.sublist(2));
  return DandAi.choose(state, DandLevel.values[args[0]], Random(args[1]));
}
