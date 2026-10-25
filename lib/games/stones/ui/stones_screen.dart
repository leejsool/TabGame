import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/game_fx.dart';
import '../../../core/game_info.dart';
import '../../../core/game_speed.dart';
import '../../../core/tablet_scale.dart';
import '../../../core/win_sound.dart';
import '../../../versus/vs_screen_parts.dart';
import '../core/stones_rules.dart';
import 'stones_board.dart';
import 'stones_widgets.dart';

export 'stones_widgets.dart' show showStonesRules;

/// 바둑돌 옮기기 판 화면. [puzzle]의 판에서 시작한다 (처음 판이면 자유 대결).
/// [mode]가 CPU와 대결이면 [cpuSide] 쪽을 컴퓨터가 둔다.
class StonesScreen extends StatefulWidget {
  const StonesScreen({super.key, required this.mode, required this.puzzle, this.cpuSide, this.seed});

  final PlayMode mode;
  final StonesPuzzle puzzle;
  final Side? cpuSide;
  final int? seed;

  @override
  State<StonesScreen> createState() => _StonesScreenState();
}

class _Snap {
  _Snap(this.state, this.last);
  final StonesState state;
  final (int, int)? last;
}

class _StonesScreenState extends State<StonesScreen> {
  late StonesState _s;
  final List<_Snap> _undo = [];
  (int, int)? _last;
  int? _selected;
  bool _showGaps = false;

  /// "힌트 더보기"를 눌러 빈칸 수의 2진법 표까지 보는 중.
  bool _showBinary = false;
  Timer? _cpu;

  /// 빈칸이 모두 0이 되어 남은 수를 자동으로 두는 중.
  Timer? _auto;
  bool get _autoRunning => _auto != null;
  late final Random _rng = Random(widget.seed);

  /// 문제에서 처음 둔 수가 이기는 수였는지 (아직 안 뒀으면 null).
  bool? _verdict;
  String? _firstMove;

  bool get _isPuzzle => widget.puzzle != kStartBoard;
  Side? get _cpuSide => widget.mode == PlayMode.vsCpu ? widget.cpuSide : null;
  bool get _cpuTurn => !_s.isOver && !_autoRunning && _s.turn == _cpuSide;

  /// 돌을 옮길 때 나는 "탁" 소리 (내가 옮겨도, 컴퓨터·자동 진행이 옮겨도).
  final GameFx _fx = GameFx({'move': const Fx(sound: 'stones/clack.mp3')});

  @override
  void initState() {
    super.initState();
    _restart();
  }

  bool _landscapeLocked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 폰은 판(12칸)이 작아 보여서 가로로 고정한다. 태블릿은 그대로.
    if (!_landscapeLocked && MediaQuery.sizeOf(context).shortestSide < kTabletMinSide) {
      _landscapeLocked = true;
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
  }

  @override
  void dispose() {
    _cpu?.cancel();
    _auto?.cancel();
    _fx.dispose();
    if (_landscapeLocked) SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  void _restart() {
    _cpu?.cancel();
    _auto?.cancel();
    _auto = null;
    _s = widget.puzzle.start();
    _undo.clear();
    _last = null;
    _selected = null;
    _verdict = null;
    _firstMove = null;
    _scheduleCpu();
  }

  String _who(Side side) {
    final name = '${side.name}(${side.stone})';
    if (_cpuSide == null) return name;
    return side == _cpuSide ? '컴퓨터 $name' : '나 $name';
  }

  void _tap(int row, int col) {
    if (_s.isOver || _cpuTurn || _autoRunning) return;
    final mine = _s.stonesOf(_s.turn)[row];
    if (col == mine) {
      setState(() => _selected = _selected == row ? null : row);
      return;
    }
    if (_s.targets(row).contains(col)) {
      _play(StoneMove(row, col));
    } else {
      setState(() => _selected = row);
    }
  }

  void _play(StoneMove m) {
    final from = _s.stonesOf(_s.turn)[m.row];
    final human = _s.turn != _cpuSide && !_autoRunning;
    setState(() {
      if (_isPuzzle && _verdict == null && human) {
        _verdict = _s.isWinningMove(m);
        _firstMove = m.label(_s.turn, from);
      }
      _undo.add(_Snap(_s.copy(), _last));
      _s.apply(m);
      _last = (m.row, m.to);
      _selected = null;
    });
    _fx.play(context, 'move');
    if (_s.isOver) {
      _finish();
    } else if (!_autoRunning && _s.isDecided) {
      _startAuto();
    } else if (!_autoRunning) {
      _scheduleCpu();
    }
  }

  /// 빈칸이 0, 0, 0이면 승부가 정해졌으니 (스도쿠 빠른 완성처럼) 남은 수를 차례로 자동으로 둔다.
  void _startAuto() {
    final moves = _s.finishMoves();
    setState(() {
      _auto = Timer.periodic(GameSpeed.scale(const Duration(milliseconds: 650)), (t) {
        if (!mounted || moves.isEmpty) {
          t.cancel();
          return;
        }
        _play(moves.removeAt(0));
        if (moves.isEmpty) {
          t.cancel();
          _auto = null;
        }
      });
    });
  }

  void _scheduleCpu() {
    if (!_cpuTurn) return;
    _cpu = Timer(GameSpeed.scale(const Duration(milliseconds: 700)), () {
      if (!mounted || !_cpuTurn) return;
      _play(_s.cpuMove(_rng));
    });
  }

  void _undoMove() {
    _cpu?.cancel();
    setState(() {
      // CPU와 할 때는 내 차례가 될 때까지 되돌린다
      do {
        final snap = _undo.removeLast();
        _s = snap.state;
        _last = snap.last;
      } while (_undo.isNotEmpty && _cpuTurn);
      _selected = null;
      if (_undo.isEmpty) {
        _verdict = null;
        _firstMove = null;
      }
    });
    _scheduleCpu();
  }

  Future<void> _finish() async {
    final winner = _s.winner!;
    final iWon = _cpuSide == null || winner != _cpuSide;
    if (iWon) WinSound.play(context);
    await Future<void>.delayed(GameSpeed.scale(const Duration(milliseconds: 500)));
    if (!mounted) return;
    final again = await showDialog<bool>(
      context: context,
      builder: (_) => VsResultDialog(
        title: _cpuSide == null ? '${winner.name}의 승리!' : (iWon ? '이겼어요!' : '컴퓨터가 이겼어요'),
        body: '${winner.other.name}(${winner.other.stone})은 더 움직일 수 있는 돌이 없어요.',
        art: StoneDot(side: winner, size: 48),
      ),
    );
    if (!mounted) return;
    if (again == true) {
      setState(_restart);
    } else if (again == false) {
      Navigator.of(context).maybePop();
    }
  }

  void _showAnswer() {
    final start = widget.puzzle.start();
    final lines = [for (final m in start.winningMoves()) '• ${m.label(start.turn, start.stonesOf(start.turn)[m.row])}'];
    final gaps = start.gaps;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${widget.puzzle.title} 정답'),
        content: Text(
          '빈칸 수: ${gaps.join(', ')}\n'
          '세 수를 2진법으로 XOR 하면 ${start.nimSum}이에요. 이것을 0으로 만드는 수가 이기는 수예요.\n\n'
          '${lines.isEmpty ? '이 판에서는 이기는 수가 없어요.' : lines.join('\n')}',
          style: const TextStyle(height: 1.5),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기'))],
      ),
    );
  }

  /// 가로 화면의 작은 선수 표시에 쓰는 짧은 이름.
  String _short(Side side) {
    if (_cpuSide == null) return side.name;
    return side == _cpuSide ? '컴퓨터' : '나';
  }

  String get _bannerText {
    if (_s.isOver) return '${_who(_s.winner!)}의 승리!';
    if (_autoRunning) return '빈칸이 모두 0! ${_who(_s.turn.other)}의 승리가 정해졌어요. 남은 수를 자동으로 둬요';
    if (_cpuTurn) return '${_who(_s.turn)}가 생각하고 있어요…';
    return '${_who(_s.turn)} 차례 — 옮길 칸을 누르세요';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chips = VsPlayerChips(
      chips: [
        for (final side in Side.values)
          VsPlayerChip(
            icon: StoneDot(side: side, size: 22),
            label: _who(side),
            color: kStonesColor,
            active: _s.isOver ? _s.winner == side : _s.turn == side,
          ),
      ],
    );
    final question = _isPuzzle
        ? StonesInfoCard(color: kStonesColor, icon: Icons.quiz_rounded, title: widget.puzzle.title, text: widget.puzzle.question)
        : null;
    final verdict = _verdict == null
        ? null
        : StonesInfoCard(
            color: _verdict! ? const Color(0xFF2E8B3E) : scheme.error,
            icon: _verdict! ? Icons.check_circle_rounded : Icons.cancel_rounded,
            title: _verdict! ? '정답! 이기는 수예요' : '아쉬워요, 상대가 잘하면 지는 수예요',
            text: '$_firstMove\n계속 두면서 확인해 보세요.',
          );
    final extras = [?question, ?verdict];
    final title = Text(
      _isPuzzle ? '바둑돌 옮기기 · ${widget.puzzle.title}' : '바둑돌 옮기기',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    );
    final back = IconButton(tooltip: '뒤로', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).maybePop());
    final rules = IconButton(tooltip: '규칙', icon: const Icon(Icons.help_outline_rounded), onPressed: () => showStonesRules(context));
    final banner = VsStatusBanner(text: _bannerText, color: kStonesColor);
    final board = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: StonesBoard(
        state: _s,
        onTapCell: _tap,
        selectedRow: _selected,
        lastMove: _last,
        showGaps: _showGaps,
        showBinary: _showBinary,
        canDrag: !_s.isOver && !_cpuTurn && !_autoRunning,
        highlightMovable: !_s.isOver && !_cpuTurn && !_autoRunning,
        onMoreHint: () => setState(() => _showBinary = true),
      ),
    );
    final bottom = VsBottomBar(
      children: [
        VsButton(icon: Icons.undo_rounded, label: '무르기', onPressed: _undo.isEmpty || _autoRunning ? null : _undoMove),
        VsButton(icon: Icons.restart_alt_rounded, label: _isPuzzle ? '다시 풀기' : '새 판', onPressed: () => setState(_restart)),
        VsButton(
          icon: _showGaps ? Icons.visibility_off_rounded : Icons.straighten_rounded,
          label: _showGaps ? '빈칸 수 숨기기' : '빈칸 수 보기',
          onPressed: () => setState(() {
            _showGaps = !_showGaps;
            _showBinary = false;
          }),
        ),
        if (_isPuzzle) VsButton(icon: Icons.lightbulb_rounded, label: '정답 보기', onPressed: _showAnswer),
      ],
    );
    const light = [Color(0xFFF4F7EC), Color(0xFFE3EBD2)];
    const dark = [Color(0xFF1E2219), Color(0xFF171A14)];

    final size = MediaQuery.sizeOf(context);
    if (size.width > size.height * 1.2) {
      // 가로: 판이 좌우를 다 쓰도록 단추·안내는 위아래로 (판 옆 칸을 두지 않는다)
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: isDark ? dark : light),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 한 줄에 모은다: 뒤로 · 제목(끝났거나 자동 진행 중이면 그 안내) · 작은 차례 표시 · 규칙.
                // ("옮길 칸을 누르세요" 줄은 없앴다 — 차례는 작은 표시와 움직일 수 있는 돌의 빛으로 알린다)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                  child: Row(
                    children: [
                      back,
                      Expanded(
                        child: _s.isOver || _autoRunning
                            ? Text(
                                _s.isOver ? '${_who(_s.winner!)}의 승리!' : '빈칸이 모두 0! ${_who(_s.turn.other)}의 승리가 정해졌어요. 남은 수를 자동으로 둬요',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              )
                            : title,
                      ),
                      for (final side in Side.values) ...[
                        VsPlayerChip(
                          compact: true,
                          icon: StoneDot(side: side, size: 16),
                          label: _short(side),
                          color: kStonesColor,
                          active: _s.isOver ? _s.winner == side : _s.turn == side,
                        ),
                        const SizedBox(width: 6),
                      ],
                      rules,
                    ],
                  ),
                ),
                if (extras.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final e in extras) Expanded(child: Padding(padding: const EdgeInsets.only(right: 10), child: e)),
                      ],
                    ),
                  ),
                Expanded(child: board),
                bottom,
              ],
            ),
          ),
        ),
      );
    }
    return VsGameScaffold(
      light: light,
      dark: dark,
      topBar: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Row(
          children: [
            back,
            Expanded(child: title),
            rules,
          ],
        ),
      ),
      chips: chips,
      banner: banner,
      board: board,
      extras: [for (final e in extras) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: e)],
      bottom: bottom,
    );
  }
}
