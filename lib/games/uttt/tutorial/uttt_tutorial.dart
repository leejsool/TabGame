import 'dart:math';

import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/tutorial.dart';
import '../core/uttt_rules.dart';
import '../ui/uttt_board.dart' show UtttLayout, drawMark, kOColor, kXColor, sideColor;

const Color _utttColor = Color(0xFFD1495B);

/// 궁극 틱택토 게임 방법.
GameTutorial utttTutorial() => GameTutorial(
      title: '궁극 틱택토',
      color: _utttColor,
      steps: [
        TutorialStep(
          title: '틱택토 속의 틱택토',
          body: '큰 판 안에 작은 틱택토 판이 9개 들어 있어요. 작은 판마다 틱택토를 하는 거예요.\n'
              '가로·세로·대각선으로 내 표시(X 또는 O) 세 개를 이으면 그 작은 판을 차지해요.',
          art: (context, accent) => _board(
            marks: const {
              4 * 9 + 4: kX,
              4 * 9 + 0: kO,
              0 * 9 + 4: kO,
              8 * 9 + 8: kX,
              2 * 9 + 6: kX,
              2 * 9 + 2: kO,
            },
          ),
        ),
        TutorialStep(
          title: '내가 둔 곳이 상대의 판',
          body: '내가 둔 칸의 위치가 곧 상대가 다음에 둘 작은 판이에요.\n'
              '예를 들어 어느 판의 "오른쪽 위" 칸에 뒀다면, 상대는 큰 판의 "오른쪽 위" 판에서 둬야 해요. '
              '반짝이는 판이 지금 둘 수 있는 판이에요.',
          art: (context, accent) => _board(
            marks: const {
              4 * 9 + 4: kO,
              4 * 9 + 2: kX,
              2 * 9 + 4: kO,
            },
            active: const {2},
            arrow: (from: 4, cell: 2, to: 2),
          ),
        ),
        TutorialStep(
          title: '한 줄을 만들면 그 판은 내 것',
          body: '작은 판에서 세 칸을 한 줄로 이으면 그 판을 차지해요. 차지한 판에는 큰 표시가 생겨요.\n'
              '차지한 판에는 더 이상 둘 수 없어요.',
          art: (context, accent) => _board(
            marks: const {
              0 * 9 + 0: kX,
              0 * 9 + 1: kX,
              0 * 9 + 2: kX,
              0 * 9 + 4: kO,
              0 * 9 + 5: kO,
              4 * 9 + 4: kO,
              8 * 9 + 0: kX,
            },
            owned: const {0: kX},
          ),
        ),
        TutorialStep(
          title: '보내진 판이 끝났다면 아무 곳이나',
          body: '상대가 보낸 작은 판이 이미 끝났다면(누가 차지했거나 가득 찼다면), 아무 판에서나 둘 수 있어요.\n'
              '이 규칙을 잘 쓰면 상대를 원하지 않는 판으로 보내거나, 자유롭게 둘 기회를 만들 수 있어요.',
          art: (context, accent) => _board(
            marks: const {
              0 * 9 + 0: kX,
              0 * 9 + 1: kX,
              0 * 9 + 2: kX,
              4 * 9 + 4: kO,
              5 * 9 + 0: kO,
              5 * 9 + 8: kX,
            },
            owned: const {0: kX},
            active: const {1, 2, 3, 4, 5, 6, 7, 8},
          ),
        ),
        TutorialStep(
          title: '큰 판에서 한 줄을 이으면 승리!',
          body: '차지한 작은 판 세 개를 큰 판에서 가로·세로·대각선으로 이으면 이겨요!\n'
              '작은 판 하나를 이기는 것보다, 큰 판의 줄을 만드는 것이 더 중요해요.',
          art: (context, accent) => _board(
            marks: const {
              0 * 9 + 0: kX,
              0 * 9 + 1: kX,
              0 * 9 + 2: kX,
              4 * 9 + 2: kX,
              4 * 9 + 4: kX,
              4 * 9 + 6: kX,
              8 * 9 + 0: kX,
              8 * 9 + 4: kX,
              8 * 9 + 8: kX,
              2 * 9 + 4: kO,
              6 * 9 + 4: kO,
            },
            owned: const {0: kX, 4: kX, 8: kX},
            winLine: const [0, 4, 8],
          ),
        ),
        TutorialStep(
          title: '무승부 판과 대결 방법',
          body: '작은 판이 가득 찼는데 줄이 없으면 무승부 판이에요. 아무도 가져가지 못해요.\n'
              '한 기기로 친구와 둘이서 하거나, CPU와 대결할 수 있어요. CPU는 난이도를 고를 수 있어요.',
          art: (context, accent) => _board(
            marks: const {
              0 * 9 + 0: kX,
              0 * 9 + 1: kO,
              0 * 9 + 2: kX,
              0 * 9 + 3: kX,
              0 * 9 + 4: kO,
              0 * 9 + 5: kO,
              0 * 9 + 6: kO,
              0 * 9 + 7: kX,
              0 * 9 + 8: kX,
              4 * 9 + 4: kX,
            },
            drawn: const {0},
          ),
        ),
      ],
    );

Widget _board({
  Map<int, int> marks = const {},
  Map<int, int> owned = const {},
  Set<int> active = const {},
  Set<int> drawn = const {},
  List<int>? winLine,
  ({int from, int cell, int to})? arrow,
}) {
  return ArtCanvas(
    width: 340,
    height: 340,
    child: CustomPaint(
      painter: _UtttArtPainter(
        marks: marks,
        owned: owned,
        active: active,
        drawn: drawn,
        winLine: winLine,
        arrow: arrow,
      ),
    ),
  );
}

/// 게임 화면과 같은 모양의 정지 그림.
class _UtttArtPainter extends CustomPainter {
  _UtttArtPainter({
    required this.marks,
    required this.owned,
    required this.active,
    required this.drawn,
    required this.winLine,
    required this.arrow,
  });

  /// 수(b*9+c) → 표시 (kX / kO).
  final Map<int, int> marks;

  /// 작은 판 → 차지한 쪽.
  final Map<int, int> owned;
  final Set<int> active;
  final Set<int> drawn;
  final List<int>? winLine;

  /// 방금 둔 수의 위치와, 그래서 상대가 가야 하는 판을 이어 주는 화살표.
  final ({int from, int cell, int to})? arrow;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = UtttLayout(size.width);
    final frame = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.04));
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7D9A8), Color(0xFFEBC083)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      frame.deflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFD9A55F),
    );

    // 다음에 둘 차례 색: 화살표 예시에서는 상대(O), 그 밖에는 X.
    final turnColor = arrow != null ? kOColor : kXColor;

    for (var b = 0; b < 9; b++) {
      final tile = layout.boardRect(b);
      final rr = RRect.fromRectAndRadius(tile, Radius.circular(layout.sb * 0.09));
      var base = const Color(0xFFFFF7E8);
      final owner = owned[b];
      if (owner == kX) base = Color.lerp(base, kXColor, 0.2)!;
      if (owner == kO) base = Color.lerp(base, kOColor, 0.2)!;
      if (drawn.contains(b)) base = Color.lerp(base, const Color(0xFF8A8A8A), 0.25)!;
      if (active.contains(b)) base = Color.lerp(base, turnColor, 0.16)!;
      canvas.drawRRect(rr.shift(Offset(0, layout.sb * 0.02)), Paint()..color = Colors.brown.withValues(alpha: 0.18));
      canvas.drawRRect(rr, Paint()..color = base);
      if (active.contains(b)) {
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = layout.sb * 0.045
            ..color = turnColor.withValues(alpha: 0.9),
        );
      }
      final inner = layout.inner(b);
      final line = Paint()
        ..color = const Color(0xFF8B6B3E).withValues(alpha: 0.38)
        ..strokeWidth = max(1.2, layout.sb * 0.014)
        ..strokeCap = StrokeCap.round;
      for (var i = 1; i <= 2; i++) {
        final x = inner.left + inner.width * i / 3;
        final y = inner.top + inner.height * i / 3;
        canvas.drawLine(Offset(x, inner.top + 4), Offset(x, inner.bottom - 4), line);
        canvas.drawLine(Offset(inner.left + 4, y), Offset(inner.right - 4, y), line);
      }
      final isOwned = owner != null;
      for (var cell = 0; cell < 9; cell++) {
        final who = marks[b * 9 + cell];
        if (who == null) continue;
        drawMark(canvas, who, layout.cellRect(b, cell), 1, alpha: isOwned ? 0.3 : 1);
      }
      if (isOwned) {
        drawMark(canvas, owner, tile.deflate(tile.width * 0.1), 1, alpha: 0.92, strokeWidth: tile.width * 0.1);
      }
    }

    final win = winLine;
    if (win != null) {
      final a = layout.boardRect(win[0]).center;
      final z = layout.boardRect(win[2]).center;
      canvas.drawLine(
        a,
        z,
        Paint()
          ..color = sideColor(kX).withValues(alpha: 0.35)
          ..strokeWidth = layout.sb * 0.2
          ..strokeCap = StrokeCap.round,
      );
    }

    final ar = arrow;
    if (ar != null) {
      // 둔 칸 → 상대가 가야 하는 판
      final from = layout.cellRect(ar.from, ar.cell).center;
      final to = layout.boardRect(ar.to).center;
      final paint = Paint()
        ..color = const Color(0xFF3B2F2F)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      final dir = (to - from) / (to - from).distance;
      final end = to - dir * layout.sb * 0.38;
      canvas.drawLine(from + dir * layout.sb * 0.12, end, paint);
      final left = Offset(-dir.dy, dir.dx);
      canvas.drawLine(end, end - dir * 14 + left * 8, paint);
      canvas.drawLine(end, end - dir * 14 - left * 8, paint);
      canvas.drawCircle(
        layout.cellRect(ar.from, ar.cell).center,
        layout.sb * 0.11,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = sideColor(kX),
      );
    }
  }

  @override
  bool shouldRepaint(_UtttArtPainter old) => true;
}
