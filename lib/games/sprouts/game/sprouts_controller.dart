import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/game_info.dart';
import '../../../versus/cpu_turn.dart';
import '../core/sprouts_ai.dart';
import '../core/sprouts_board.dart';
import '../core/sprouts_faces.dart';
import '../core/sprouts_geometry.dart';
import '../core/sprouts_planner.dart';
import '../core/sprouts_relax.dart' show boardIsPlanar;
import '../core/sprouts_tidy.dart';

part 'sprouts_controller_strokes.dart';
part 'sprouts_controller_turns.dart';
part 'sprouts_controller_rejoin.dart';

/// 같은 Wi‑Fi 대결에서 상대에게 보내는 (상대에게서 받는) 판 하나.
///
/// 콩나물은 자리를 만들려고 점과 선이 밀리거나 선 정리하기로 좌표가 바뀌니, 새 선의 좌표만 보내면 두 기기의 판이 달라진다.
/// 그래서 한 수를 둘 때마다(또는 선을 정리할 때마다) 결과 판을 통째로 보내고, 받는 쪽이 그 판으로 바꾼다.
class SproutsSync {
  const SproutsSync({required this.kind, required this.moveCount, required this.data});

  /// 'move' (선을 그었다) | 'tidy' (선 정리하기).
  final String kind;

  /// 보낸 쪽에서 이 일이 끝난 뒤의 수 번호.
  final int moveCount;

  /// 결과 판 ([SproutsBoard.toData]).
  final List<double> data;
}

class _Snapshot {
  _Snapshot(this.board, this.turn, this.moves);

  final SproutsBoard board;
  final int turn;
  final int moves;
}

/// 콩나물 한 판의 진행: 곡선 긋기, 차례, 끝 판정, CPU, 되돌리기, 힌트.
///
/// 플레이어는 0(먼저 시작)과 1. 마지막으로 수를 둔 사람이 이긴다.
/// 같은 Wi‑Fi 대결([PlayMode.wifi])에서는 내가 둔 결과 판을 [onSync]로 알리고, 상대의 판은 [receiveSync]로 받는다.
class SproutsController extends ChangeNotifier {
  /// 다른 파일(part)에 나눠 둔 조각에서 화면에 바뀐 것을 알릴 때 쓴다.
  void _notify() => notifyListeners();

  SproutsController({
    required this.mode,
    this.dotCount = 3,
    this.humanSide = 0,
    this.level = SproutsLevel.normal,
    Random? rng,
    SproutsBoard? board,
  })  : _rng = rng ?? Random(),
        board = board ?? SproutsBoard.initial(dotCount, rng ?? Random());

  /// 저장해 둔 판([toJson])을 되살린다 (한 기기·CPU 대결). 맞지 않는 내용이면 null.
  static SproutsController? fromJson(Map<String, dynamic> j) => _restore(j, wifi: false);

  /// [fromJson]과 [fromWifiSnapshot]이 함께 쓰는 복원. [wifi]면 같은 Wi‑Fi 판으로 되살린다.
  static SproutsController? _restore(Map<String, dynamic> j, {required bool wifi}) {
    try {
      final mode = wifi ? PlayMode.wifi : PlayMode.values.byName(j['mode'] as String);
      if (mode != PlayMode.vsCpu && mode != PlayMode.local2p && mode != PlayMode.wifi) return null;
      if (!wifi && mode == PlayMode.wifi) return null;
      final humanSide = j['humanSide'] as int;
      final levelIndex = j['level'] as int;
      if ((humanSide != 0 && humanSide != 1) || levelIndex < 0 || levelIndex >= SproutsLevel.values.length) return null;
      List<double> data(Object? raw) => [for (final v in raw as List) (v as num).toDouble()];
      final c = SproutsController(
        mode: mode,
        dotCount: j['dotCount'] as int,
        humanSide: humanSide,
        level: SproutsLevel.values[levelIndex],
        board: SproutsBoard.fromData(data(j['board'])),
      );
      c.turn = j['turn'] as int;
      c.moveCount = j['moveCount'] as int;
      if (c.turn != 0 && c.turn != 1) return null;
      for (final h in j['history'] as List) {
        final m = h as Map<String, dynamic>;
        c._history.add(_Snapshot(SproutsBoard.fromData(data(m['board'])), m['turn'] as int, m['moves'] as int));
      }
      return c;
    } catch (_) {
      return null;
    }
  }

  /// 지금 판의 모습을 JSON으로 (이어하기용). 되돌리기에 쓰는 최근 몇 수의 판도 함께 담는다.
  Map<String, dynamic> toJson() {
    List<double> round(List<double> d) => [for (final v in d) (v * 100).roundToDouble() / 100];
    final recent = _history.length > 12 ? _history.sublist(_history.length - 12) : _history;
    return {
      'v': 1,
      'mode': mode.name,
      'dotCount': dotCount,
      'humanSide': humanSide,
      'level': level.index,
      'turn': turn,
      'moveCount': moveCount,
      'board': round(board.toData()),
      'history': [
        for (final h in recent) {'board': round(h.board.toData()), 'turn': h.turn, 'moves': h.moves},
      ],
    };
  }

  /// 이어하기로 보관할 만한 판인가 (같은 Wi‑Fi가 아니고, 한 수라도 뒀고, 끝나지 않았다).
  bool get savable => !online && !isOver && moveCount > 0;

  final PlayMode mode;
  final int dotCount;

  /// CPU 대결·Wi‑Fi 대결에서 내가 맡은 쪽 (0 = 먼저, 1 = 나중).
  final int humanSide;
  final SproutsLevel level;
  final Random _rng;

  /// 같은 Wi‑Fi의 다른 기기와 겨루는 판인가.
  bool get online => mode == PlayMode.wifi;

  /// 이 기기에서 한쪽만 맡는 판인가 (CPU 대결이거나 Wi‑Fi 대결).
  bool get oneSeat => vsCpu || online;

  /// 내가 둔(또는 정리한) 결과 판을 알린다 (Wi‑Fi 대결에서 상대에게 보내려고).
  void Function(SproutsSync sync)? onSync;

  /// 방금 바뀐 판이 상대 기기에서 온 것인가 (그렇다면 화면이 상대의 선을 천천히 그려 보여 준다).
  bool lastRemote = false;

  SproutsBoard board;

  /// 지금 수를 둘 차례 (0 / 1).
  int turn = 0;

  /// 지금까지 둔 수.
  int moveCount = 0;

  /// 이긴 사람 (끝났을 때). null이면 진행 중.
  int? winner;

  /// 기권으로 끝났는가.
  bool resigned = false;

  /// CPU가 생각하는 중.
  final CpuTurnRunner _cpu = CpuTurnRunner();

  /// CPU가 수를 고르는 중인가.
  bool get thinking => _cpu.thinking;

  /// 안 되는 수를 그렸을 때의 안내 (다음 동작에서 지워진다).
  String? message;

  /// 손으로 그은 선을 알아서 바로잡아 두었을 때의 알림 (다음 수에서 지워진다).
  String? notice;

  /// 방금 둔 수 (애니메이션용): 번호와 새 점.
  int moveSerial = 0;
  int lastMid = -1;

  /// 자리를 만들려고 점과 선을 밀었다면, 밀기 전의 판 (화면이 천천히 옮겨 가는 모습을 보여 줄 때 쓴다).
  SproutsBoard? morphFrom;

  /// 방금 한 일이 "선 정리하기"인가 (그렇다면 새 곡선·새 점 애니메이션 없이 옮겨 가기만 한다).
  bool lastWasTidy = false;

  /// 선 정리하기를 계산하는 중.
  bool tidying = false;

  /// 방금 둔 수를 사람이 직접 그었는가 (그렇다면 곡선을 다시 그려 보이지 않고 새 점만 나타낸다).
  bool lastByHuman = false;

  /// 힌트로 보여 주는 곡선 (잠깐 보였다 사라진다).
  List<P>? hintPath;
  Timer? _hintTimer;

  /// 소리/진동 알림 ('draw' | 'bad' | 'win').
  void Function(String kind)? onFeedback;

  final List<_Snapshot> _history = [];

  bool get vsCpu => mode == PlayMode.vsCpu;
  int get cpuSide => 1 - humanSide;

  /// 나간 상대의 자리를 CPU가 대신 두고 있는가 (같은 Wi‑Fi 판의 방장 기기에서만 켠다).
  bool cpuCover = false;
  bool get isOver => winner != null;

  /// 지금 사람이 그을 수 있는가.
  bool get humanCanAct => !isOver && !thinking && !tidying && (!oneSeat || turn == humanSide);

  bool get canUndo => !online && !thinking && _undoTo() != null; // (Wi‑Fi 대결은 되돌릴 수 없다)
  bool get canResign => !isOver && moveCount > 0;

  /// 선 정리하기를 누를 수 있는가 (그어진 선이 있고, 계산 중이 아닐 때).
  bool get canTidy => !isOver && !thinking && !tidying && board.curves.isNotEmpty && (!online || turn == humanSide);

  /// 남은 목숨의 합 (한 수마다 1씩 줄어든다).
  int get livesLeft => board.totalLives;

  // ── 사람이 그은 곡선 ──



  int _repairEpoch = 0;

  // ── 상대 기기에서 온 판 (Wi‑Fi 대결) ──


  /// 새 판([after])에서 기존 점과 선(앞의 [before])의 자리나 판의 범위가 달라졌는가.
  static bool _geometryChanged(SproutsBoard before, SproutsBoard after) {
    if (before.bounds != after.bounds) return true;
    for (var i = 0; i < before.dots.length; i++) {
      if (before.dots[i].pos.dist(after.dots[i].pos) > 0.3) return true;
    }
    for (var i = 0; i < before.curves.length; i++) {
      final a = before.curves[i].pts, b = after.curves[i].pts;
      if (a.length != b.length) return true;
      for (var j = 0; j < a.length; j += 4) {
        if (a[j].dist(b[j]) > 0.3) return true;
      }
    }
    return false;
  }


  // ── CPU ──




  // ── 되돌리기 / 힌트 / 기권 / 새 판 ──


  /// 같은 설정의 새 판. [swapStart]면 CPU·Wi‑Fi 대결에서 먼저/나중을 바꾼다. [board]를 주면 그 처음 판으로 시작한다 (Wi‑Fi 대결은 두 기기가 같은 판으로).
  SproutsController fresh({bool swapStart = true, SproutsBoard? board}) => SproutsController(
        mode: mode,
        dotCount: dotCount,
        humanSide: oneSeat && swapStart ? 1 - humanSide : humanSide,
        level: level,
        board: board,
      );

  @override
  void dispose() {
    _cpu.dispose();
    _hintTimer?.cancel();
    super.dispose();
  }
}
