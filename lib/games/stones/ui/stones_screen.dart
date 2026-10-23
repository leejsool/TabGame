import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/game_info.dart';
import '../../../core/game_speed.dart';
import '../../../core/tablet_scale.dart';
import '../../../core/win_sound.dart';
import '../../../versus/vs_screen_parts.dart';
import '../core/stones_rules.dart';
import '../tutorial/stones_tutorial.dart';
import 'stones_board.dart';

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
  Timer? _cpu;
  late final Random _rng = Random(widget.seed);

  /// 문제에서 처음 둔 수가 이기는 수였는지 (아직 안 뒀으면 null).
  bool? _verdict;
  String? _firstMove;

  bool get _isPuzzle => widget.puzzle != kStartBoard;
  Side? get _cpuSide => widget.mode == PlayMode.vsCpu ? widget.cpuSide : null;
  bool get _cpuTurn => !_s.isOver && _s.turn == _cpuSide;

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
    if (_landscapeLocked) SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  void _restart() {
    _cpu?.cancel();
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
    if (_s.isOver || _cpuTurn) return;
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
    final human = _s.turn != _cpuSide;
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
    if (_s.isOver) {
      _finish();
    } else {
      _scheduleCpu();
    }
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
        art: _StoneDot(side: winner, size: 48),
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

  String get _bannerText {
    if (_s.isOver) return '${_who(_s.winner!)}의 승리!';
    if (_cpuTurn) return '${_who(_s.turn)}가 생각하고 있어요…';
    return '${_who(_s.turn)} 차례 — 옮길 칸을 누르세요';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chips = VsPlayerChips(chips: [
      for (final side in Side.values)
        VsPlayerChip(
          icon: _StoneDot(side: side, size: 22),
          label: _who(side),
          color: kStonesColor,
          active: _s.isOver ? _s.winner == side : _s.turn == side,
        ),
    ]);
    final question = _isPuzzle
        ? _InfoCard(
            color: kStonesColor,
            icon: Icons.quiz_rounded,
            title: widget.puzzle.title,
            text: widget.puzzle.question,
          )
        : null;
    final verdict = _verdict == null
        ? null
        : _InfoCard(
            color: _verdict! ? const Color(0xFF2E8B3E) : scheme.error,
            icon: _verdict! ? Icons.check_circle_rounded : Icons.cancel_rounded,
            title: _verdict! ? '정답! 이기는 수예요' : '아쉬워요, 상대가 잘하면 지는 수예요',
            text: '$_firstMove\n계속 두면서 확인해 보세요.',
          );
    final extras = [?question, ?verdict];
    return VsGameScaffold(
      light: const [Color(0xFFF4F7EC), Color(0xFFE3EBD2)],
      dark: const [Color(0xFF1E2219), Color(0xFF171A14)],
      topBar: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Row(children: [
          IconButton(tooltip: '뒤로', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).maybePop()),
          Expanded(
            child: Text(
              _isPuzzle ? '바둑돌 옮기기 · ${widget.puzzle.title}' : '바둑돌 옮기기',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(tooltip: '규칙', icon: const Icon(Icons.help_outline_rounded), onPressed: () => showStonesRules(context)),
        ]),
      ),
      chips: chips,
      banner: VsStatusBanner(text: _bannerText, color: kStonesColor),
      board: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: StonesBoard(state: _s, onTapCell: _tap, selectedRow: _selected, lastMove: _last, showGaps: _showGaps),
      ),
      extras: [for (final e in extras) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: e)],
      bottom: VsBottomBar(children: [
        VsButton(icon: Icons.undo_rounded, label: '무르기', onPressed: _undo.isEmpty ? null : _undoMove),
        VsButton(icon: Icons.restart_alt_rounded, label: _isPuzzle ? '다시 풀기' : '새 판', onPressed: () => setState(_restart)),
        VsButton(
          icon: _showGaps ? Icons.visibility_off_rounded : Icons.straighten_rounded,
          label: _showGaps ? '빈칸 수 숨기기' : '빈칸 수 보기',
          onPressed: () => setState(() => _showGaps = !_showGaps),
        ),
        if (_isPuzzle) VsButton(icon: Icons.lightbulb_rounded, label: '정답 보기', onPressed: _showAnswer),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.color, required this.icon, required this.title, required this.text});

  final Color color;
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
            const SizedBox(height: 2),
            Text(text, style: const TextStyle(height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}

/// 선수 칩·결과 창에 쓰는 작은 바둑돌.
class _StoneDot extends StatelessWidget {
  const _StoneDot({required this.side, required this.size});

  final Side side;
  final double size;

  @override
  Widget build(BuildContext context) {
    final white = side == Side.white;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: white ? const [Colors.white, Color(0xFFD6D6D6)] : const [Color(0xFF5A5A5A), Color(0xFF111111)],
        ),
        border: Border.all(color: white ? const Color(0xFF555555) : Colors.black, width: 1.2),
      ),
    );
  }
}

Future<void> showStonesRules(BuildContext context) => showVsRules(
      context,
      title: '바둑돌 옮기기 규칙',
      lines: const [
        '갑은 흰 돌, 을은 검은 돌을 움직이며 갑부터 번갈아 둬요.',
        '자기 돌 한 개를 같은 행의 다른 빈칸으로 옮겨요. 앞으로도, 뒤로도 갈 수 있어요.',
        '다른 돌을 건너뛸 수는 없어요.',
        '더는 움직일 수 없는 사람이 져요.',
        '옮길 칸을 바로 누르면 그 행의 내 돌이 옮겨 가요. 내 돌을 먼저 누르면 갈 수 있는 칸이 점으로 보여요.',
      ],
      openTutorial: () => stonesTutorial().open(context),
    );
