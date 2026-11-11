import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/game_info.dart';
import '../../../core/game_speed.dart';
import '../../../versus/cpu_turn.dart';
import '../core/yacht_advisor.dart';
import '../core/yacht_cpu.dart';
import '../core/yacht_game.dart';
import '../core/yacht_rules.dart';
import '../core/yacht_values.dart';

/// 주사위가 구르는 시간 (밀리초. "빠른 진행"이면 더 짧아진다).
const int kYachtRollMs = 950;

Future<YachtAdvisor>? _advisor;

/// 기대 점수 표를 읽어 길잡이(확률 계산)를 만든다. 한 번만 읽는다.
Future<YachtAdvisor> loadYachtAdvisor() => _advisor ??= rootBundle
    .load('assets/yacht/values.bin')
    .then((data) => YachtAdvisor(YachtValues.fromBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes))));

/// 야추 한 판의 진행: 사람의 입력(굴리기 · 잡기 · 칸 고르기 · 적기)과 CPU의 차례.
class YachtController extends ChangeNotifier {
  YachtController({
    required this.mode,
    this.players = 2,
    this.level = YachtLevel.normal,
    this.first = 0,
    this.advisor,
    Random? rng,
  })  : _rng = rng ?? Random(),
        game = YachtGame(playerCount: players, first: first);

  /// 이어하기용으로 보관한 모습에서 되살린다. 맞지 않는 내용이면 null.
  static YachtController? fromJson(Map<String, dynamic> j) {
    try {
      final game = YachtGame.fromJson(j['game'] as Map<String, dynamic>);
      final c = YachtController(
        mode: PlayMode.values.byName(j['mode'] as String),
        players: game.playerCount,
        level: YachtLevel.values.byName(j['level'] as String),
        first: j['first'] as int? ?? 0,
      );
      c.game = game;
      c.actions = j['actions'] as int? ?? 1;
      return c;
    } catch (_) {
      return null;
    }
  }

  final PlayMode mode;

  /// 앉은 사람 수 (2~4, CPU 포함).
  final int players;
  final YachtLevel level;

  /// 이번 판을 먼저 시작한 자리 (한 판 더 할 때마다 한 칸씩 돈다).
  int first;

  YachtGame game;

  /// 확률 계산. [start]에서 읽는다 (시험에서는 미리 넣어 준다).
  YachtAdvisor? advisor;

  /// 주사위가 구르는 중인가.
  bool rolling = false;

  /// 구르는 주사위가 멈출 눈 ([rolling]일 때. 화면이 이 눈으로 멈추는 모습을 그린다).
  List<int> rollTarget = const [1, 1, 1, 1, 1];

  /// 적으려고 고른 칸 (사람은 "적기"를 눌러야 확정된다. CPU가 고른 칸도 잠깐 보여 준다).
  YachtCategory? pick;

  /// 마지막으로 점수를 적은 자리와 칸 (점수판에서 표시해 준다).
  int? lastSeat;
  YachtCategory? lastCategory;

  /// 이번 판에서 한 행동 수 (굴리기 + 적기). 0이면 아직 시작 전이다.
  int actions = 0;

  /// 화면에 알리는 일: 'roll' 굴리기 시작, 'land' 주사위가 멈춤, 'hold' 잡기, 'score' 적음, 'zero' 0점을 적음, 'end' 판이 끝남.
  void Function(String kind)? onFeedback;

  final Random _rng;
  final CpuTurnRunner _cpu = CpuTurnRunner();
  int _epoch = 0;
  bool _disposed = false;
  bool _cpuBusy = false;

  bool get vsCpu => mode == PlayMode.vsCpu;

  /// CPU 대결에서 내 자리.
  int get humanSeat => 0;

  bool isCpu(int seat) => vsCpu && seat != humanSeat;
  bool get isOver => game.over;
  bool get thinking => _cpu.thinking;

  /// 지금 사람이 누를 수 있는 차례인가.
  bool get humanTurn => !game.over && !isCpu(game.turn);

  /// 이어하기용으로 보관할 만한 판인가 (시작했고 아직 안 끝났다).
  bool get savable => !game.over && actions > 0;

  String name(int seat) {
    if (!vsCpu) return '플레이어 ${seat + 1}';
    if (seat == humanSeat) return '나';
    return players == 2 ? 'CPU' : 'CPU $seat';
  }

  /// 좁은 칸에 쓰는 짧은 이름.
  String shortName(int seat) => vsCpu ? name(seat) : '${seat + 1}번';

  /// 화면이 뜬 뒤 한 번 부른다: 확률 계산을 준비하고, CPU 차례면 CPU가 시작한다.
  Future<void> start() async {
    advisor ??= await loadYachtAdvisor();
    if (_disposed) return;
    notifyListeners();
    _runCpu();
  }

  // ── 사람의 입력 ──

  Future<void> roll() async {
    if (rolling || !humanTurn || !game.canRoll) return;
    await _roll();
  }

  void toggleHold(int i) {
    if (rolling || !humanTurn || !game.canHold) return;
    game.toggleHold(i);
    onFeedback?.call('hold');
    notifyListeners();
  }

  /// 적을 칸을 고른다 (같은 칸을 다시 누르면 취소).
  void choose(YachtCategory c) {
    if (rolling || !humanTurn || !game.canScore(c)) return;
    pick = pick == c ? null : c;
    onFeedback?.call('hold');
    notifyListeners();
  }

  /// 힌트대로 해 준다: [holds]대로 주사위를 잡거나, [category] 칸을 고른다 (굴리기·적기는 사람이 누른다).
  void applyHint({List<bool>? holds, YachtCategory? category}) {
    if (rolling || !humanTurn) return;
    if (holds != null && game.canHold) {
      game.setHolds(holds);
      pick = null;
    } else if (category != null && game.canScore(category)) {
      pick = category;
    }
    onFeedback?.call('hold');
    notifyListeners();
  }

  /// 지금 힌트를 볼 수 있는가 (내 차례에 한 번은 굴린 뒤).
  bool get canHint => advisor != null && humanTurn && !rolling && game.rollsUsed > 0;

  /// 고른 칸에 적는다.
  void confirm() {
    final c = pick;
    if (c == null || rolling || !humanTurn || !game.canScore(c)) return;
    _score(c);
    _runCpu();
  }

  /// 새 판. [rotate]면 시작하는 자리가 한 칸 돈다.
  void restart({bool rotate = true}) {
    _epoch++;
    _cpu.cancel();
    _cpuBusy = false;
    rolling = false;
    pick = null;
    lastSeat = null;
    lastCategory = null;
    actions = 0;
    if (rotate) first = (first + 1) % players;
    game = YachtGame(playerCount: players, first: first);
    notifyListeners();
    _runCpu();
  }

  // ── 진행 ──

  Future<bool> _wait(int ms) async {
    final epoch = _epoch;
    await Future<void>.delayed(GameSpeed.scale(Duration(milliseconds: ms)));
    return !_disposed && epoch == _epoch;
  }

  /// 주사위를 굴린다 (구르는 동안 잠깐 기다린다). 그 사이에 새 판이 시작됐으면 false.
  Future<bool> _roll() async {
    final target = game.nextRoll(_rng);
    rollTarget = target;
    rolling = true;
    pick = null;
    onFeedback?.call('roll');
    notifyListeners();
    if (!await _wait(kYachtRollMs)) return false;
    game.applyRoll(target);
    rolling = false;
    actions++;
    onFeedback?.call('land');
    notifyListeners();
    return true;
  }

  void _score(YachtCategory c) {
    lastSeat = game.turn;
    lastCategory = c;
    final s = game.score(c);
    pick = null;
    actions++;
    onFeedback?.call(game.over ? 'end' : (s > 0 ? 'score' : 'zero'));
    notifyListeners();
  }

  /// CPU 차례가 이어지는 동안 CPU가 굴리고 · 잡고 · 적는다.
  Future<void> _runCpu() async {
    final brain = advisor;
    if (_cpuBusy || brain == null) return;
    final epoch = _epoch;
    _cpuBusy = true;
    try {
      while (!game.over && isCpu(game.turn)) {
        if (game.rollsUsed == 0) {
          if (!await _wait(350) || !await _roll()) return;
          continue;
        }
        final move = await _cpu.run(
          task: () async => YachtCpu.choose(brain, game, level, _rng),
          minTime: const Duration(milliseconds: 750),
          onStart: notifyListeners,
        );
        if (move == null || epoch != _epoch) return;
        final category = move.category;
        if (category != null) {
          pick = category;
          notifyListeners();
          if (!await _wait(800)) return;
          _score(category);
        } else {
          game.setHolds(move.holds!);
          onFeedback?.call('hold');
          notifyListeners();
          if (!await _wait(650) || !await _roll()) return;
        }
      }
    } finally {
      if (epoch == _epoch) _cpuBusy = false;
    }
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'level': level.name,
        'first': first,
        'actions': actions,
        'game': game.toJson(),
      };

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _cpu.dispose();
    super.dispose();
  }
}
