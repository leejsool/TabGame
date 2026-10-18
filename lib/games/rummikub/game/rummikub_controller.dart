import 'dart:async';
import 'dart:math';
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';

import '../../../core/game_info.dart';
import '../../../versus/cpu_turn.dart';
import '../core/rummikub_ai.dart';
import '../core/rummikub_rules.dart';
import 'rummikub_layout.dart';

part 'rummikub_controller_board.dart';
part 'rummikub_controller_history.dart';
part 'rummikub_controller_turn.dart';
part 'rummikub_controller_cpu.dart';

/// 루미큐브 한 판의 진행 (규칙 + 내 손/판 만지기 + CPU + 같은 Wi‑Fi 상대의 수 받기).
///
/// 남의 패가 보이면 안 되니 사람끼리는 같은 Wi‑Fi로 각자 기기에서만 한다 ([PlayMode.wifi], 2명).
/// [PlayMode.vsCpu]는 내가 한 명이고 나머지(1~3명)는 CPU다. 나는 [humanSeat]번째 자리다.
///
/// 내 차례에는 판 위 묶음 복사본([work])과 내 손([hand])을 마음껏 옮겨 보다가, 올바르게 맞춰졌을 때 [endTurn]으로 내놓는다.
/// 맞추기 어려우면 [reset]으로 처음 모습으로 돌리거나 [draw]로 타일을 뽑고 차례를 넘긴다.
class RummikubController extends ChangeNotifier {
  /// 다른 파일(part)에 나눠 둔 조각에서 화면에 바뀐 것을 알릴 때 쓴다.
  void _notify() => notifyListeners();

  RummikubController({
    required this.mode,
    this.players = 2,
    this.humanSeat = 0,
    this.level = RkLevel.normal,
    int? seed,
    this.animate = true,
    Iterable<int>? cpuSeats,
    this.cpuHost = false,
  }) : seed = seed ?? Random().nextInt(1 << 30) {
    assert(mode == PlayMode.vsCpu || (mode == PlayMode.wifi && players >= 2 && players <= 4));
    // CPU 대결은 나 말고 모두 CPU다. 같은 Wi‑Fi 방에서는 [cpuSeats]에 든 자리들이 CPU다.
    this.cpuSeats = {...?cpuSeats};
    if (mode == PlayMode.vsCpu && cpuSeats == null) {
      this.cpuSeats.addAll([for (var p = 0; p < players; p++) if (p != humanSeat) p]);
    }
    _deal();
  }

  /// 저장해 둔 판([toJson])을 되살린다 (CPU 대결만). 이번 차례에 판 위에 올려 두던 타일은 손으로 돌아온다.
  /// 맞지 않는 내용이면 null.
  static RummikubController? fromJson(Map<String, dynamic> j, {bool animate = true}) {
    try {
      final st = RkState.fromJson(j['state'] as Map<String, dynamic>);
      final players = j['players'] as int;
      final humanSeat = j['humanSeat'] as int;
      final levelIndex = j['level'] as int;
      if (st == null || st.players != players || humanSeat < 0 || humanSeat >= players) return null;
      if (levelIndex < 0 || levelIndex >= RkLevel.values.length) return null;
      final c = RummikubController(
        mode: PlayMode.vsCpu,
        players: players,
        humanSeat: humanSeat,
        level: RkLevel.values[levelIndex],
        seed: j['seed'] as int,
        animate: animate,
      );
      c.state = st;
      c.rotation = j['rotation'] as int;
      c.moveCount = j['moveCount'] as int;
      c.lastActor = j['lastActor'] as int;
      c.lastDrew = j['lastDrew'] as bool;
      c.lastCount = j['lastCount'] as int;
      // 내 손: 저장한 순서를 지키되, 실제 손과 다르면 정렬해서 다시 만든다
      final rack = st.racks[humanSeat];
      final saved = [for (final t in j['hand'] as List) t as int];
      final ok = saved.length == rack.length && saved.toSet().containsAll(rack);
      c.hand = ok ? saved : ([...rack]..sort(compareByColor));
      c.anchors.clear();
      (j['anchors'] as Map<String, dynamic>).forEach((k, v) {
        final a = v as List;
        c.anchors[int.parse(k)] = Offset((a[0] as num).toDouble(), (a[1] as num).toDouble());
      });
      c.work = c._copyTable();
      c._liveSig = c._workSig();
      return c;
    } catch (_) {
      return null;
    }
  }

  /// 지금 판의 모습을 JSON으로 (CPU 대결의 이어하기용). 이번 차례에 판 위에 올려 둔 타일은 저장하지 않는다 (손으로 돌아온다).
  Map<String, dynamic> toJson() => {
        'v': 1,
        'players': players,
        'humanSeat': humanSeat,
        'level': level.index,
        'seed': seed,
        'rotation': rotation,
        'moveCount': moveCount,
        'lastActor': lastActor,
        'lastDrew': lastDrew,
        'lastCount': lastCount,
        'state': state.toJson(),
        'hand': hand,
        'anchors': {for (final e in anchors.entries) '${e.key}': [e.value.dx, e.value.dy]},
      };

  /// 이어하기로 보관할 만한 판인가 (CPU 대결이고, 한 차례라도 지났고, 끝나지 않았다).
  bool get savable => vsCpu && !isOver && !halted && moveCount > 0;

  final PlayMode mode;
  final int players;

  /// CPU가 앉은 자리들. 한 판 더 할 때마다 사람과 함께 한 칸씩 돈다.
  late final Set<int> cpuSeats;

  /// 같은 Wi‑Fi 방에서 CPU의 수를 이 기기가 정해서 다른 기기들에 알리는가 (방을 연 기기만).
  final bool cpuHost;

  /// 한 판 더 한 횟수 (자리가 이만큼 돌았다).
  int rotation = 0;

  /// CPU와 상대 기기의 수를 타일을 한 장씩 옮기는 모습으로 보여 주는가 (시험에서는 끄고 한 번에 반영한다).
  final bool animate;

  /// 이 기기에서 내가 맡은 자리 (0 = 먼저). 한 판 더 할 때마다 한 칸씩 돈다.
  int humanSeat;
  final RkLevel level;

  /// 패를 나눈 씨앗. 같은 Wi‑Fi 대결에서는 두 기기가 같은 값으로 시작한다.
  int seed;

  bool get vsCpu => mode == PlayMode.vsCpu;
  bool get online => mode == PlayMode.wifi;

  bool isCpuSeat(int seat) => cpuSeats.contains(seat);

  /// 이 기기가 CPU의 수를 정하는가 (CPU 대결, 또는 CPU가 낀 Wi‑Fi 방의 방장).
  bool get runsCpu => cpuSeats.isNotEmpty && (vsCpu || cpuHost);

  /// 판에 앉은 사람 수 (CPU 빼고).
  int get humans => players - cpuSeats.length;

  /// 다른 기기에서 온 수가 어긋났을 때 (대기열에 있던 수를 나중에 적용하다 알게 된 경우).
  void Function()? onDesync;

  late RkState state;

  /// 지금까지 끝난 차례 수.
  int moveCount = 0;

  /// 내 손의 타일들 (내가 늘어놓은 순서). 판 위에 올려 둔 타일도 포함한다 — 손에 보이는 것은 [rackTiles].
  List<int> hand = [];

  /// 이번 차례에 만지고 있는 판 (처음에는 [state.table]의 복사본).
  List<List<int>> work = [];

  /// 누른 타일들.
  final Set<int> selected = {};

  /// 방금 뽑은 타일 (손에서 반짝이게 한다).
  int? lastDrawn;


  /// 누군가 기권해서 멈춘 판인가.
  bool halted = false;

  /// 방금 한 동작이 안 된 이유 (화면 아래에 잠깐 보여 준다).
  String? notice;

  /// 내가 한 차례를 마칠 때 알린다 (Wi‑Fi 대결에서 상대에게 보내려고).
  void Function(Map<String, dynamic> move)? onLocalMove;

  /// 내가 이번 차례에 판을 만지는 동안, 바뀔 때마다 그 모습을 알린다 (Wi‑Fi 대결에서 상대 화면에 실시간으로 보이려고).
  void Function(Map<String, dynamic> live)? onLocalLive;

  /// 소리/진동 알림 ('place' | 'draw' | 'bad' | 'win').
  void Function(String kind)? onFeedback;

  final CpuTurnRunner _cpu = CpuTurnRunner();
  final Random _rng = Random();

  // ── 녹색 판의 자리 ──

  /// 타일 번호 → 그 타일이 든 묶음의 왼쪽 위 자리 (타일 칸 단위). 묶음이 바뀌어도 타일이 자리를 기억해서 놓은 자리가 유지된다.
  final Map<int, Offset> anchors = {};

  /// 화면이 알려 주는 판의 폭(칸 수)과 한 줄에 놓을 수 있는 타일 수.
  double layoutWidth = 8;
  int layoutPerRow = 8;

  // ── 상대의 수 보여 주기 ──

  /// 지금 상대(CPU·다른 기기)의 수를 한 장씩 옮겨 보여 주는 중인가.
  bool _animating = false;
  int _animEpoch = 0;

  /// 한 장 옮길 때마다 기다리는 시간.
  Duration stepDelay = const Duration(milliseconds: 520);

  /// 상대가 이번에 손에서 꺼내 판에 올리는 타일들 (화면 위쪽에서 날아 들어오게 한다).
  final Set<int> flying = {};

  /// 상대가 더미에서 고르는 중인 바닥 타일의 번호 (그 타일을 들어 올려 보여 준다). 없으면 null.
  int? opponentPick;

  /// 한 판 더 할 때의 다음 씨앗 (두 기기가 똑같이 계산한다).
  static int nextSeed(int seed) => (seed * 1103515245 + 12345) & 0x3fffffff;

  // ── 손 ──


  // ── 녹색 판 자리 계산과 놓기 ──

  // ── 한 단계 되돌리기 ──

  /// 이번 차례에 만지기 전 모습들 (판·손·묶음 자리). 끝내기·뽑기·처음으로·새 판에서 비운다.
  final List<({List<List<int>> work, List<int> hand, Map<int, Offset> anchors})> _undo = [];




  /// 방금 만진 묶음의 타일들 (자리를 정할 때 이 묶음의 자리를 가장 먼저 지킨다).
  final Set<int> _recent = {};




  // ── 만지기 ──


  // ── 차례 마치기 ──

  /// 방금 차례를 마친 사람과 그 내용 (화면의 안내 글에 쓴다).
  int lastActor = -1;
  bool lastDrew = false;
  int lastCount = 0;



  // ── 실시간 중계 (Wi‑Fi 대결) ──

  /// 마지막으로 알린 판의 모습 (같은 모습을 다시 보내지 않으려고).
  String _liveSig = '';

  /// 지금 상대가 만지는 판을 실시간으로 받아 보여 주는 중인가.
  bool _liveActive = false;


  @override
  void notifyListeners() {
    super.notifyListeners();
    _maybeSendLive();
  }



  // ── 상대 기기의 수 (Wi‑Fi 대결) ──


  /// 앞선 수를 보여 주는 동안 도착한 다른 기기의 수들 (보여 주기가 끝나면 차례로 적용한다).
  final List<({Map<String, dynamic> m, int? fromSeat})> _queuedMoves = [];


  // ── CPU ──



  // ── 상대의 차례 보여 주기 ──




  // ── 기권 ──




  @override
  void dispose() {
    _cpu.dispose();
    super.dispose();
  }
}

/// 다른 isolate에서 CPU의 차례를 정한다. args = [난이도, 씨앗, 손, 판, 처음 내려놓기를 마쳤는지]. 빈 목록이면 타일을 뽑는다.
List<List<int>> _cpuTask(List<Object> args) {
  final plan = RkAi.plan(
    rack: (args[2] as List).cast<int>(),
    table: [for (final s in args[3] as List) (s as List).cast<int>()],
    melded: args[4] as bool,
    level: RkLevel.values[args[0] as int],
    rng: Random(args[1] as int),
  );
  return plan ?? const [];
}
