import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/game_info.dart';
import '../../../core/game_speed.dart';
import '../../../versus/cpu_turn.dart';
import '../core/yacht_advisor.dart';
import '../core/yacht_cpu.dart';
import '../core/yacht_daesung_advisor.dart';
import '../core/yacht_daesung_values.dart';
import '../core/yacht_game.dart';
import '../core/yacht_rules.dart';
import '../core/yacht_values.dart';

part 'yacht_controller_clock.dart';
part 'yacht_controller_rejoin.dart';

/// "시간 제한"을 켠 판에서 사람의 한 차례에 주어지는 시간 (초).
const int kYachtTurnSeconds = 60;

/// 주사위가 구르는 시간 (밀리초. "빠른 진행"이면 더 짧아진다).
const int kYachtRollMs = 950;

Future<YachtAdvisor>? _advisor;
Future<YachtDaesungAdvisor>? _daesungAdvisor;

/// 기대 점수 표를 읽어 길잡이(확률 계산)를 만든다. 한 번만 읽는다.
Future<YachtAdvisor> loadYachtAdvisor() => _advisor ??= rootBundle
    .load('assets/yacht/values.bin')
    .then((data) => YachtAdvisor(YachtValues.fromBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes))));

/// 대성One Rule의 길잡이 (표: assets/yacht/values_ds.bin). 한 번만 읽는다.
Future<YachtDaesungAdvisor> loadYachtDaesungAdvisor() => _daesungAdvisor ??= rootBundle
    .load('assets/yacht/values_ds.bin')
    .then((data) => YachtDaesungAdvisor(YachtDaesungValues.fromBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes))));

/// 야추 한 판의 진행: 사람의 입력(굴리기 · 잡기 · 칸 고르기 · 적기)과 CPU의 차례.
class YachtController extends ChangeNotifier {
  YachtController({
    required this.mode,
    this.players = 2,
    this.level = YachtLevel.normal,
    this.first = 0,
    this.humanSeat = 0,
    Iterable<int>? cpuSeats,
    this.cpuHost = false,
    this.names,
    this.advisor,
    this.threeKind = false,
    this.daesung = false,
    this.turnSeconds,
    Random? rng,
  })  : _rng = rng ?? Random(),
        // CPU와 대결(옛 방식)은 내 자리 빼고 모두 CPU. 한 기기로 함께 · 같은 Wi‑Fi는 알려 준 자리들이 CPU(봇)다.
        cpuSeats = mode == PlayMode.vsCpu ? {for (var i = 0; i < players; i++) if (i != humanSeat) i} : {...?cpuSeats},
        game = YachtGame(playerCount: players, first: first, threeKind: threeKind, daesung: daesung);

  /// 이어하기용으로 보관한 모습에서 되살린다. 맞지 않는 내용이면 null.
  static YachtController? fromJson(Map<String, dynamic> j) {
    try {
      final game = YachtGame.fromJson(j['game'] as Map<String, dynamic>);
      final c = YachtController(
        mode: PlayMode.values.byName(j['mode'] as String),
        players: game.playerCount,
        level: YachtLevel.values.byName(j['level'] as String),
        first: j['first'] as int? ?? 0,
        threeKind: game.threeKind,
        daesung: game.daesung,
        turnSeconds: j['sec'] as int?,
        cpuSeats: [for (final s in (j['cpu'] as List?) ?? const []) if (s is int && s >= 0 && s < game.playerCount) s],
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

  /// 쓰리카드 칸을 넣고 하는 판인가 (시작 전에 정한다. "한 판 더"에서도 그대로).
  final bool threeKind;

  /// 대성One Rule 판인가 (시작 전에 정한다. 0번 주사위가 만능 대성One).
  final bool daesung;

  /// 사람의 한 차례 제한 시간(초). null이면 시간 무제한. 같은 Wi‑Fi 판에서는 쓰지 않는다.
  final int? turnSeconds;

  /// 지금 차례에 남은 시간(초). 시계가 돌지 않으면 null (yacht_controller_clock.dart).
  /// 1초마다 바뀌니 화면 전체가 아니라 남은 시간 막대만 다시 그리도록 따로 알린다.
  final ValueNotifier<int?> clock = ValueNotifier<int?>(null);
  int? get secondsLeft => clock.value;
  set secondsLeft(int? v) => clock.value = v;
  Timer? _clock;
  String? _clockFor;

  /// 시간이 다 돼서 저절로 적는 중인가 (그동안 사람은 누를 수 없다).
  bool _timeUp = false;

  /// 시간이 다 돼서 저절로 적는 중인가.
  bool get timeUp => _timeUp;

  /// 화면에 알리기 전에 시계를 지금 상황에 맞춘다.
  @override
  void notifyListeners() {
    _syncClock();
    super.notifyListeners();
  }

  void _rawNotify() => super.notifyListeners();

  /// 이번 판을 먼저 시작한 자리 (한 판 더 할 때마다 한 칸씩 돈다).
  int first;

  YachtGame game;

  /// 확률 계산. [start]에서 읽는다 (시험에서는 미리 넣어 준다).
  YachtBrain? advisor;

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

  /// 화면에 알리는 일: 'roll' 굴리기 시작, 'land' 주사위가 멈춤, 'hold' 잡기, 'score' 적음, 'zero' 0점을 적음, 'yahtzee' 주사위 5개가 모두 같은 눈으로 멈춤(야추 성공), 'end' 판이 끝남.
  void Function(String kind)? onFeedback;

  final Random _rng;
  final CpuTurnRunner _cpu = CpuTurnRunner();
  int _epoch = 0;
  bool _disposed = false;
  bool _cpuBusy = false;

  /// 사람 한 명이 CPU(봇)들과 하는 판인가 (옛 "CPU와 대결"이거나, 한 기기 설정에서 사람 1명 + 봇).
  bool get vsCpu => mode == PlayMode.vsCpu || (!online && cpuSeats.isNotEmpty && cpuSeats.length == players - 1);

  /// 같은 Wi‑Fi로 함께 하는 판인가.
  bool get online => mode == PlayMode.wifi;

  /// 이 기기에서 한 자리만 맡는가 (CPU 대결 · 같은 Wi‑Fi).
  bool get oneSeat => vsCpu || online;

  /// CPU 대결 · 같은 Wi‑Fi 판에서 내 자리.
  final int humanSeat;

  /// 같은 Wi‑Fi 판에서 CPU가 앉은 자리들 (처음부터 CPU였거나, 나간 사람 대신 맡았거나).
  final Set<int> cpuSeats;

  /// 같은 Wi‑Fi 판에서 이 기기가 CPU의 차례를 진행하는가 (방을 연 기기만).
  final bool cpuHost;

  /// 같은 Wi‑Fi 판의 자리별 이름.
  final List<String>? names;

  /// 같은 Wi‑Fi 판에서 이 기기가 한 일(내 입력 · 방장 기기의 CPU)을 다른 기기에 알린다.
  /// `{'t': 'roll', 'd': 눈 5개}` · `{'t': 'hold', 'h': 잡은 주사위}` · `{'t': 'score', 'c': 칸 번호}`, 모두 `i`(그때까지의 행동 수)가 붙는다.
  void Function(Map<String, dynamic> action)? onLocalAction;

  bool isCpu(int seat) => cpuSeats.contains(seat);
  bool get isOver => game.over;
  bool get thinking => _cpu.thinking;

  /// 이 기기가 CPU의 차례를 진행하는가.
  bool get runsCpu => cpuSeats.isNotEmpty && (!online || cpuHost);

  /// 같은 Wi‑Fi 판에 있는 사람 수.
  int get humans => players - cpuSeats.length;

  /// 지금 (이 기기의) 사람이 누를 수 있는 차례인가.
  bool get humanTurn => !game.over && !isCpu(game.turn) && (!online || game.turn == humanSeat);

  /// 이어하기용으로 보관할 만한 판인가 (시작했고 아직 안 끝났다. 같은 Wi‑Fi 판은 보관하지 않는다).
  bool get savable => !online && !game.over && actions > 0;

  String name(int seat) {
    if (online) {
      if (seat == humanSeat) return '나';
      final given = names;
      return given != null && given.length == players ? given[seat] : '상대';
    }
    if (vsCpu) {
      if (seat == humanSeat) return '나';
      return players == 2 ? 'CPU' : 'CPU $seat';
    }
    if (isCpu(seat)) return cpuSeats.length == 1 ? 'CPU' : 'CPU ${cpuSeats.where((s) => s < seat).length + 1}';
    return '플레이어 ${seat + 1}';
  }

  /// 좁은 칸에 쓰는 짧은 이름.
  String shortName(int seat) {
    if (!online) return vsCpu || isCpu(seat) ? name(seat) : '${seat + 1}번';
    final n = name(seat);
    return n.runes.length <= 4 ? n : String.fromCharCodes(n.runes.take(4));
  }

  void _notify() => notifyListeners();

  void _emit(Map<String, dynamic> action) {
    if (online) onLocalAction?.call({...action, 'i': actions});
  }

  /// 화면이 뜬 뒤 한 번 부른다: 확률 계산을 준비하고, CPU 차례면 CPU가 시작한다.
  Future<void> start() async {
    advisor ??= daesung ? await loadYachtDaesungAdvisor() : await loadYachtAdvisor();
    if (_disposed) return;
    notifyListeners();
    _runCpu();
  }

  // ── 사람의 입력 ──

  Future<void> roll() async {
    if (rolling || _timeUp || !humanTurn || !game.canRoll) return;
    await _roll();
  }

  void toggleHold(int i) {
    if (rolling || _timeUp || !humanTurn || !game.canHold) return;
    game.toggleHold(i);
    _emit({'t': 'hold', 'h': List<bool>.of(game.held)});
    onFeedback?.call('hold');
    notifyListeners();
  }

  /// 적을 칸을 고른다 (같은 칸을 다시 누르면 취소).
  void choose(YachtCategory c) {
    if (rolling || _timeUp || !humanTurn || !game.canScore(c)) return;
    pick = pick == c ? null : c;
    onFeedback?.call('hold');
    notifyListeners();
  }

  /// 힌트대로 해 준다: [holds]대로 주사위를 잡거나, [category] 칸을 고른다 (굴리기·적기는 사람이 누른다).
  void applyHint({List<bool>? holds, YachtCategory? category}) {
    if (rolling || _timeUp || !humanTurn) return;
    if (holds != null && game.canHold) {
      game.setHolds(holds);
      _emit({'t': 'hold', 'h': List<bool>.of(game.held)});
      pick = null;
    } else if (category != null && game.canScore(category)) {
      pick = category;
    }
    onFeedback?.call('hold');
    notifyListeners();
  }

  /// 지금 힌트를 볼 수 있는가 (내 차례에 한 번은 굴린 뒤).
  bool get canHint => advisor != null && !_timeUp && humanTurn && !rolling && game.rollsUsed > 0;

  /// 고른 칸에 적는다.
  void confirm() {
    final c = pick;
    if (c == null || rolling || _timeUp || !humanTurn || !game.canScore(c)) return;
    _score(c);
    _runCpu();
  }

  /// 새 판. [rotate]면 시작하는 자리가 한 칸 돈다.
  void restart({bool rotate = true}) {
    _epoch++;
    _cpu.cancel();
    _cpuBusy = false;
    _timeUp = false;
    rolling = false;
    _pendingRoll = null;
    pick = null;
    lastSeat = null;
    lastCategory = null;
    actions = 0;
    if (rotate) first = (first + 1) % players;
    game = YachtGame(playerCount: players, first: first, threeKind: threeKind, daesung: daesung);
    notifyListeners();
    _runCpu();
  }

  // ── 진행 ──

  Future<bool> _wait(int ms) async {
    final epoch = _epoch;
    await Future<void>.delayed(GameSpeed.scale(Duration(milliseconds: ms)));
    return !_disposed && epoch == _epoch;
  }

  /// 구르는 중인 주사위가 멈출 눈 (아직 판에 적용하지 않았다).
  List<int>? _pendingRoll;

  /// 주사위를 굴린다 (구르는 동안 잠깐 기다린다). 그 사이에 새 판이 시작됐으면 false.
  Future<bool> _roll() {
    final target = game.nextRoll(_rng);
    _emit({'t': 'roll', 'd': target});
    return _showRoll(target);
  }

  /// [target]으로 멈추는 주사위를 굴려 보인 뒤 판에 적용한다 (내가 굴렸거나, 다른 기기가 굴린 결과를 받았거나).
  Future<bool> _showRoll(List<int> target) async {
    rollTarget = target;
    _pendingRoll = target;
    rolling = true;
    pick = null;
    onFeedback?.call('roll');
    notifyListeners();
    final alive = await _wait(kYachtRollMs);
    if (_disposed) return false;
    if (identical(_pendingRoll, target)) _settleRoll();
    return alive;
  }

  /// 구르는 중인 주사위를 바로 멈춰 판에 적용한다 (다음 소식이 먼저 왔거나, 자리 주인이 바뀔 때).
  void _settleRoll() {
    final target = _pendingRoll;
    if (target == null) return;
    _pendingRoll = null;
    game.applyRoll(target);
    rolling = false;
    actions++;
    // 야추 성공: 굴린 주사위 5개가 모두 같은 눈으로 멈췄을 때 (점수를 적는 때가 아니라, 눈이 완성된 그 순간. 누가 굴려도 같다)
    onFeedback?.call(game.dice.every((d) => d == game.dice.first) ? 'yahtzee' : 'land');
    notifyListeners();
  }

  void _score(YachtCategory c, {bool local = true}) {
    if (local) _emit({'t': 'score', 'c': c.index});
    lastSeat = game.turn;
    lastCategory = c;
    final s = game.score(c);
    pick = null;
    actions++;
    onFeedback?.call(game.over ? 'end' : (s > 0 ? 'score' : 'zero'));
    notifyListeners();
  }

  /// 다른 기기가 한 일을 받아 그대로 따라 한다. 지금 판과 맞지 않으면 false (판이 어긋났다).
  bool receive(Map<String, dynamic> m) {
    if (!online || game.over || game.turn == humanSeat) return false;
    _settleRoll();
    final i = m['i'];
    if (i is int && i != actions) return false;
    switch (m['t']) {
      case 'roll':
        final d = m['d'];
        if (d is! List || d.length != kYachtDice || !game.canRoll) return false;
        final target = <int>[];
        for (var k = 0; k < kYachtDice; k++) {
          final v = d[k];
          if (v is! int || v < 1 || v > 6) return false;
          if (game.rollsUsed > 0 && game.held[k] && v != game.dice[k]) return false;
          target.add(v);
        }
        _showRoll(target);
        return true;
      case 'hold':
        final h = m['h'];
        if (h is! List || h.length != kYachtDice || h.any((x) => x is! bool) || !game.canHold) return false;
        game.setHolds(h.cast<bool>());
        onFeedback?.call('hold');
        notifyListeners();
        return true;
      case 'score':
        final k = m['c'];
        if (k is! int || k < 0 || k >= YachtCategory.values.length) return false;
        final c = YachtCategory.values[k];
        if (!game.canScore(c)) return false;
        _score(c, local: false);
        _runCpu();
        return true;
    }
    return false;
  }

  /// CPU 차례가 이어지는 동안 CPU가 굴리고 · 잡고 · 적는다.
  Future<void> _runCpu() async {
    final brain = advisor;
    if (_cpuBusy || brain == null || (online && !cpuHost)) return;
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
          _emit({'t': 'hold', 'h': List<bool>.of(game.held)});
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
        if (cpuSeats.isNotEmpty && !online) 'cpu': [...cpuSeats],
        if (turnSeconds != null) 'sec': turnSeconds,
      };

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _clock?.cancel();
    clock.dispose();
    _cpu.dispose();
    super.dispose();
  }
}
