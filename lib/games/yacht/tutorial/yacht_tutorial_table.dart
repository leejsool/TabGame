import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../core/yacht_rules.dart';
import '../game/yacht_controller.dart';
import '../ui/yacht_look.dart';
import '../ui/yacht_score_table.dart';

/// 게임 방법 그림에서 화살표가 가리키는 점수판의 자리.
class YachtTableSpot {
  /// 나(첫째 자리)의 [cat] 칸.
  const YachtTableSpot.cell(YachtCategory this.cat) : bonus = false;

  /// 나의 보너스 칸 (1~6 칸 합 / 63).
  const YachtTableSpot.bonus()
      : cat = null,
        bonus = true;

  final YachtCategory? cat;
  final bool bonus;
}

/// 화살표 하나: 점수판의 [spot]에서 설명 [target](GlobalKey를 단 위젯)까지.
class YachtTableArrow {
  const YachtTableArrow(this.spot, this.target);

  final YachtTableSpot spot;
  final GlobalKey target;
}

/// 게임 방법 그림: 진짜 게임의 점수판([YachtScoreTable])을 그대로 그리고, 오른쪽 설명과 화살표로 잇는다.
///
/// [setup]으로 판의 상황(굴린 주사위, 이미 적은 칸 …)을 만든다. 점수판은 핸드폰 화면처럼 그리고, 만질 수는 없다.
/// [arrows]는 칸에서 설명으로 가는 화살표(가리키는 칸은 노란 테두리), [braceTarget]이 있으면 족보 칸 전체를 괄호로 묶어
/// 그 설명을 가리킨다.
class YachtTutorialTable extends StatefulWidget {
  const YachtTutorialTable({
    super.key,
    required this.setup,
    required this.tableWidth,
    required this.tableHeight,
    required this.side,
    this.top,
    this.arrows = const [],
    this.braceTarget,
  });

  final void Function(YachtController c) setup;
  final double tableWidth;
  final double tableHeight;

  /// 점수판 오른쪽에 놓이는 설명.
  final Widget side;

  /// 점수판 위에 놓이는 것 (굴린 주사위 등).
  final Widget? top;
  final List<YachtTableArrow> arrows;
  final GlobalKey? braceTarget;

  @override
  State<YachtTutorialTable> createState() => _YachtTutorialTableState();
}

class _YachtTutorialTableState extends State<YachtTutorialTable> {
  late final YachtController _c = YachtController(mode: PlayMode.vsCpu, players: 2);
  final GlobalKey _stack = GlobalKey();
  final GlobalKey _table = GlobalKey();
  List<(Rect cell, Offset to)> _lines = const [];
  (Rect rows, Offset to)? _brace;

  @override
  void initState() {
    super.initState();
    widget.setup(_c);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// [key] 위젯이 그림 안에서 차지하는 자리.
  Rect? _rectOf(BuildContext? ctx) {
    final box = ctx?.findRenderObject() as RenderBox?;
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero, ancestor: stack) & box.size;
  }

  /// 점수판 안에서 [key]를 단 위젯을 찾아 자리를 돌려준다.
  Rect? _findInTable(Key key) {
    Rect? found;
    void visit(Element e) {
      if (found != null) return;
      if (e.widget.key == key) {
        found = _rectOf(e);
        return;
      }
      e.visitChildElements(visit);
    }

    _table.currentContext?.visitChildElements(visit);
    return found;
  }

  Rect? _spotRect(YachtTableSpot s) {
    if (!s.bonus) return _findInTable(ValueKey('yacht-cell-0-${s.cat!.name}'));
    // 보너스 칸: 폭은 내 점수 칸, 높이는 보너스 줄
    final col = _findInTable(const ValueKey('yacht-cell-0-sixes'));
    final row = _findInTable(const ValueKey('yacht-help-bonus'));
    if (col == null || row == null) return null;
    return Rect.fromLTRB(col.left, row.top, col.right, row.bottom);
  }

  Offset? _leftMid(GlobalKey k) {
    final r = _rectOf(k.currentContext);
    return r == null ? null : Offset(r.left - 4, r.center.dy);
  }

  void _measure() {
    if (!mounted) return;
    final lines = <(Rect, Offset)>[];
    for (final a in widget.arrows) {
      final cell = _spotRect(a.spot);
      final to = _leftMid(a.target);
      if (cell != null && to != null) lines.add((cell, to));
    }
    (Rect, Offset)? brace;
    final bt = widget.braceTarget;
    if (bt != null) {
      final first = _findInTable(const ValueKey('yacht-cell-1-ones'));
      final last = _findInTable(const ValueKey('yacht-cell-1-choice'));
      final to = _leftMid(bt);
      if (first != null && last != null && to != null) brace = (Rect.fromLTRB(first.left, first.top, last.right, last.bottom), to);
    }
    setState(() {
      _lines = lines;
      _brace = brace;
    });
  }

  @override
  Widget build(BuildContext context) {
    final table = SizedBox(
      key: _table,
      width: widget.tableWidth,
      height: widget.tableHeight,
      // 점수판은 핸드폰 화면에서 보이는 모습으로 (태블릿에서 글자가 따로 커지지 않게)
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(size: const Size(400, 860)),
        child: IgnorePointer(child: YachtScoreTable(c: _c)),
      ),
    );
    return Stack(
      key: _stack,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.top != null) ...[widget.top!, const SizedBox(height: 8)],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [table, const SizedBox(width: 46), Expanded(child: widget.side)],
            ),
          ],
        ),
        Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ArrowPainter(_lines, _brace)))),
      ],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.lines, this.brace);

  final List<(Rect cell, Offset to)> lines;
  final (Rect rows, Offset to)? brace;

  static const Color _ring = Color(0xFFF2A900);

  void _arrow(Canvas canvas, Offset from, Offset to, Paint p) {
    canvas.drawLine(from, to, p);
    final dir = (to - from) / (to - from).distance;
    final side = Offset(-dir.dy, dir.dx);
    canvas.drawPath(
      Path()
        ..moveTo((to - dir * 10 + side * 7).dx, (to - dir * 10 + side * 7).dy)
        ..lineTo(to.dx, to.dy)
        ..lineTo((to - dir * 10 - side * 7).dx, (to - dir * 10 - side * 7).dy),
      p,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..color = _ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final line = Paint()
      ..color = kYachtColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final (cell, to) in lines) {
      canvas.drawRRect(RRect.fromRectAndRadius(cell.inflate(1), const Radius.circular(9)), ring);
      _arrow(canvas, Offset(cell.right + 3, cell.center.dy), to, line);
    }
    final b = brace;
    if (b != null) {
      final (rows, to) = b;
      final x = rows.right + 12;
      canvas.drawPath(
        Path()
          ..moveTo(rows.right + 4, rows.top + 2)
          ..lineTo(x, rows.top + 2)
          ..lineTo(x, rows.bottom - 2)
          ..lineTo(rows.right + 4, rows.bottom - 2),
        line,
      );
      _arrow(canvas, Offset(x, rows.center.dy), to, line);
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.lines != lines || old.brace != brace;
}
