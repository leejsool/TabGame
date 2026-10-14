import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/mines_rules.dart';
import '../core/mines_solver.dart';

enum MinesStatus { ready, playing, won, lost }

/// 지뢰찾기 한 판의 진행.
class MinesController extends ChangeNotifier {
  MinesController({
    required this.level,
    MinesBoard? board,
    int elapsedSeconds = 0,
    Random? rng,
    List<int>? presetMines,
    List<int>? retryOf,
  })  : board = board ?? MinesBoard.forLevel(level),
        _preset = presetMines,
        retryOf = retryOf ?? presetMines,
        elapsed = ValueNotifier<int>(elapsedSeconds),
        _rng = rng ?? Random() {
    if (this.board.minesPlaced) status = MinesStatus.playing;
  }

  final MinesLevel level;
  MinesBoard board;
  final ValueNotifier<int> elapsed;
  final Random _rng;

  /// 다시 도전하는 판의 지뢰 배치 (첫 칸을 열 때 쓰고 비운다).
  List<int>? _preset;

  /// 포기했던 판에 다시 도전하는 중이면 그 판의 원래 지뢰 배치 (클리어/다시 포기할 때 같은 판임을 알아본다).
  List<int>? retryOf;

  /// 기록에 남길 이 판의 지뢰 배치: 다시 도전 중이면 원래 배치, 아니면 지금 배치.
  List<int> get recordMines => retryOf ?? mineCells;

  /// 포기한 판 (더 이상 손댈 수 없다).
  bool gaveUp = false;

  MinesStatus status = MinesStatus.ready;
  bool paused = false;

  /// true면 탭이 "깃발 꽂기", false면 "열기".

  MinesHint? hint;
  String? hintMessage;

  /// 첫 칸을 연 순간 (도전 횟수를 세려고).
  VoidCallback? onStarted;
  VoidCallback? onWon;
  VoidCallback? onLost;

  /// 소리/진동 알림 ('reveal' | 'flag' | 'boom' | 'win').
  void Function(String kind)? onFeedback;

  // ── 애니메이션용 시각 정보 (밀리초, [clockMs] 기준) ──

  final Stopwatch _clock = Stopwatch()..start();
  int get clockMs => _clock.elapsedMilliseconds;

  /// 칸이 화면에 열려 보이기 시작하는 시각 (연쇄로 열릴 때 거리만큼 늦춘다).
  final Map<int, int> revealAt = {};

  /// 깃발이 꽂힌/뽑힌 시각, 지뢰가 드러나는 시각 (졌을 때).
  final Map<int, int> flagAt = {};
  final Map<int, int> mineShowAt = {};
  int boomAt = -1;
  int winAt = -1;

  /// 자동으로 끝나는 애니메이션이 끝나는 시각.
  int animEndMs = 0;

  int get minesLeft => board.minesLeft;
  bool get isOver => status == MinesStatus.won || status == MinesStatus.lost;
  bool get canAct => !isOver && !paused && !gaveUp;

  /// 지금 칸이 (애니메이션까지 포함해) 열려 보이는가.
  bool shownRevealed(int i, int now) {
    if (board.marks[i] != CellMark.revealed) return false;
    return now >= (revealAt[i] ?? 0);
  }

  /// 졌을 때 지뢰 칸이 이미 드러났는가.
  bool mineShown(int i, int now) => status == MinesStatus.lost && board.mine[i] && now >= (mineShowAt[i] ?? 0);

  // ── 입력 ──

  /// 칸을 열기로 골랐다. 열린 숫자면 코드(주변 한꺼번에 열기), 깃발 칸은 그대로, 아니면 열기(물음표 칸도 연다).
  void tap(int i) {
    if (!canAct) return;
    final m = board.marks[i];
    if (m == CellMark.revealed) {
      _afterReveal(board.chord(i), origin: i);
    } else if (m != CellMark.flagged) {
      _open(i);
    }
  }

  /// 깃발 꽂기/뽑기.
  void flag(int i) {
    if (!canAct) return;
    _toggleFlag(i);
  }

  /// 물음표(?) 달기/떼기.
  void question(int i) {
    if (!canAct) return;
    _toggleFlag(i, question: true);
  }

  /// 이 칸에 깃발·물음표를 달 수 있는가 (시작 전이거나 이미 열린 칸이면 안 된다).
  bool canMark(int i) => canAct && status != MinesStatus.ready && board.marks[i] != CellMark.revealed;

  void _toggleFlag(int i, {bool question = false}) {
    if (!canMark(i)) return; // 시작 전에는 깃발이 의미 없다
    if (question) {
      board.toggleQuestion(i);
    } else {
      board.toggleFlag(i);
    }
    flagAt[i] = clockMs;
    animEndMs = max(animEndMs, clockMs + 400);
    hint = null;
    hintMessage = null;
    onFeedback?.call('flag');
    notifyListeners();
  }

  void _open(int i) {
    if (status == MinesStatus.ready) {
      final preset = _preset;
      _preset = null;
      if (preset == null) {
        board.placeMines(i, _rng);
      } else {
        board.placePresetMines(preset, i, _rng);
      }
      status = MinesStatus.playing;
      onStarted?.call();
    }
    _afterReveal(board.reveal(i), origin: i);
  }

  void _afterReveal(List<(int, int)> opened, {required int origin}) {
    if (opened.isEmpty) return;
    hint = null;
    hintMessage = null;
    final now = clockMs;
    var last = now;
    for (final (cell, dist) in opened) {
      final at = now + dist * 34;
      revealAt[cell] = at;
      last = max(last, at + 260);
    }
    animEndMs = max(animEndMs, last);
    onFeedback?.call('reveal');
    if (board.isLost) {
      _lose(origin);
    } else if (board.isWon) {
      _win();
    }
    notifyListeners();
  }

  void _lose(int originHint) {
    status = MinesStatus.lost;
    final hit = board.explodedCell!;
    boomAt = clockMs;
    // 다른 지뢰들이 터진 칸에서 가까운 순서로 연달아 드러난다
    final others = [for (var i = 0; i < board.size; i++) if (board.mine[i] && i != hit && board.marks[i] != CellMark.flagged) i];
    int d(int i) {
      final dr = board.rowOf(i) - board.rowOf(hit), dc = board.colOf(i) - board.colOf(hit);
      return dr * dr + dc * dc;
    }

    others.sort((a, b) => d(a).compareTo(d(b)));
    final step = others.isEmpty ? 0 : min(90.0, 1500 / others.length);
    for (var k = 0; k < others.length; k++) {
      mineShowAt[others[k]] = boomAt + 500 + (k * step).round();
    }
    animEndMs = max(animEndMs, boomAt + 500 + (others.length * step).round() + 500);
    onFeedback?.call('boom');
    onLost?.call();
  }

  void _win() {
    status = MinesStatus.won;
    winAt = clockMs;
    final before = board.marks.toList();
    board.flagAllMines();
    var k = 0;
    for (var i = 0; i < board.size; i++) {
      if (before[i] != board.marks[i]) flagAt[i] = winAt + 120 + (k++ * 25);
    }
    animEndMs = max(animEndMs, winAt + 120 + k * 25 + 600);
    onFeedback?.call('win');
    onWon?.call();
  }

  // ── 힌트 ──

  void requestHint() {
    if (!canAct) return;
    if (status == MinesStatus.ready) {
      hint = null;
      hintMessage = '아무 칸이나 눌러서 시작해 보세요. 첫 칸은 늘 안전해요!';
      notifyListeners();
      return;
    }
    final h = MinesSolver.findHint(board);
    hint = h;
    hintMessage = h == null ? '숫자만으로는 확실한 칸이 없어요. 어느 쪽이 더 안전할지 추측해야 해요.' : h.message;
    notifyListeners();
  }

  void dismissHint() {
    if (hint == null && hintMessage == null) return;
    hint = null;
    hintMessage = null;
    notifyListeners();
  }

  // ── 포기 ──

  /// 이 판을 포기한다 (칸을 연 판만). 포기했으면 true.
  bool giveUp() {
    if (status != MinesStatus.playing || gaveUp) return false;
    gaveUp = true;
    hint = null;
    hintMessage = null;
    notifyListeners();
    return true;
  }

  /// 지금 판의 지뢰 위치 (첫 칸을 열기 전에는 빈 목록).
  List<int> get mineCells => [for (var i = 0; i < board.size; i++) if (board.mine[i]) i];

  // ── 새 판 / 시계 ──

  /// 같은 난이도의 새 판.
  void restart() {
    board = MinesBoard.forLevel(level);
    _preset = null;
    retryOf = null;
    gaveUp = false;
    status = MinesStatus.ready;
    paused = false;
    hint = null;
    hintMessage = null;
    revealAt.clear();
    flagAt.clear();
    mineShowAt.clear();
    boomAt = -1;
    winAt = -1;
    animEndMs = 0;
    elapsed.value = 0;
    notifyListeners();
  }

  void tick() {
    if (paused || gaveUp || status != MinesStatus.playing) return;
    elapsed.value++;
  }

  void setPaused(bool v) {
    if (isOver || gaveUp || status == MinesStatus.ready || paused == v) return;
    paused = v;
    notifyListeners();
  }

  // ── 저장 ──

  /// 진행 중(첫 칸을 연 뒤)인 판만 저장한다.
  bool get saveable => status == MinesStatus.playing && !gaveUp;

  Map<String, dynamic> toJson() => {
        'level': level.index,
        'mines': [for (var i = 0; i < board.size; i++) if (board.mine[i]) i],
        'marks': board.marks.map((m) => m.index).join(),
        'elapsed': elapsed.value,
        if (retryOf != null) 'retry': retryOf,
      };

  static MinesController fromJson(Map<String, dynamic> j) {
    final level = MinesLevel.values[j['level'] as int];
    final board = MinesBoard.forLevel(level)..setMines(List<int>.from(j['mines'] as List));
    final marks = j['marks'] as String;
    for (var i = 0; i < board.size && i < marks.length; i++) {
      final m = CellMark.values[int.parse(marks[i])];
      board.marks[i] = m;
      if (m == CellMark.revealed) board.revealedCount++;
      if (m == CellMark.flagged) board.flagCount++;
    }
    return MinesController(
      level: level,
      board: board,
      elapsedSeconds: j['elapsed'] as int,
      retryOf: j['retry'] == null ? null : List<int>.from(j['retry'] as List),
    );
  }

  @override
  void dispose() {
    elapsed.dispose();
    super.dispose();
  }
}
