import 'dart:math';

import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/tutorial.dart';
import '../ui/mines_painter.dart' show drawFlagGlyph, drawQuestionBadge, numberColors;

const Color _minesColor = Color(0xFFC8553D);

/// 지뢰찾기 게임 방법.
GameTutorial minesTutorial() => GameTutorial(
      title: '지뢰찾기',
      color: _minesColor,
      steps: [
        TutorialStep(
          title: '지뢰만 피해서 모두 열어요',
          body: '숨겨진 지뢰를 피해서, 지뢰가 없는 칸을 모두 열면 이겨요. 지뢰가 있는 칸을 열면 져요.\n'
              '첫 번째로 연 칸은 언제나 안전하니까 걱정 말고 시작해요!',
          art: (context, accent) => _board(
            const [
              '.....',
              '.111.',
              '.101.',
              '.111.',
              '.....',
            ],
            label: '열린 칸에는 숫자가 나타나요',
          ),
        ),
        TutorialStep(
          title: '숫자는 둘레의 지뢰 개수',
          body: '열린 칸의 숫자는 그 칸 둘레 8칸에 지뢰가 몇 개 있는지 알려 줘요.\n'
              '지금 그림의 2는 둘레 8칸 중 지뢰가 2개라는 뜻이에요.',
          art: (context, accent) => _board(
            const [
              '.*.',
              '.2.',
              '.*.',
            ],
            ring: {(1, 1)},
            label: '둘레 8칸 중 지뢰 2개',
            showMines: true,
          ),
        ),
        TutorialStep(
          title: '숫자로 지뢰를 찾아내요',
          body: '숫자를 단서로 추리해요. 그림에서 1 둘레를 보세요. 안 열린 칸이 딱 하나뿐이죠? '
              '그러면 그 칸이 지뢰예요! 지뢰라고 확신한 칸에는 깃발을 꽂아 두어요.',
          art: (context, accent) => _board(
            const [
              '000',
              '110',
              '.10',
            ],
            glow: {(2, 0)},
            label: '1 둘레에 안 열린 칸이 하나뿐 → 지뢰!',
          ),
        ),
        TutorialStep(
          title: '열기와 깃발, 물음표',
          body: '칸을 톡 치면 열려요.\n'
              '칸을 꾹 누르면 동그란 메뉴가 떠요. 손가락을 그대로 밀었다 떼세요: '
              '위쪽은 열기, 오른쪽 아래는 깃발, 왼쪽 아래는 물음표(?)예요. 가운데에서 떼면 취소돼요.\n'
              '물음표는 "잘 모르겠어요" 표시라서 지뢰 수에 들어가지 않아요.',
          art: (context, accent) => const ArtCanvas(width: 320, height: 320, child: _RadialMenuArt()),
        ),
        TutorialStep(
          title: '숫자를 눌러 한꺼번에 열기',
          body: '열린 숫자 둘레에 깃발이 숫자만큼 꽂혀 있으면, 그 숫자를 눌러서 나머지 칸을 한꺼번에 열 수 있어요.\n'
              '깃발을 잘못 꽂았다면 지뢰를 밟을 수 있으니 조심하세요!',
          art: (context, accent) => _board(
            const [
              'F..',
              '.2.',
              '..F',
            ],
            pulse: true,
            label: '깃발 2개 = 숫자 2 → 숫자를 톡!',
          ),
        ),
        TutorialStep(
          title: '막힐 땐 힌트, 큰 판은 확대',
          body: '힌트 버튼은 지금 보이는 숫자로 "확실한" 칸과 그 이유를 알려 줘요.\n'
              '판이 크면 두 손가락으로 벌려서 확대하고, 두 손가락으로 밀어서 옮길 수 있어요. '
              '(한 손가락으로 끄는 건 깃발·물음표 메뉴예요)',
          art: (context, accent) => ArtCanvas(
            width: 340,
            height: 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ArtBadge(icon: Icons.lightbulb_rounded, color: accent, label: '힌트'),
                ArtBadge(icon: Icons.pinch_rounded, color: accent, label: '확대·이동'),
              ],
            ),
          ),
        ),
      ],
    );

/// 작은 지뢰찾기 판 그림.
///
/// 글자 뜻: `.` 안 열린 칸 · `0`~`8` 열린 칸(0은 빈 칸) · `F` 깃발 · `*` 지뢰 · `?` 물음표.
Widget _board(
  List<String> rows, {
  Set<(int, int)> glow = const {},
  Set<(int, int)> ring = const {},
  bool showMines = false,
  bool pulse = false,
  String? label,
}) {
  const cell = 64.0;
  final cols = rows.first.length;
  final w = cols * cell + 24;
  final h = rows.length * cell + 24;
  return ArtCanvas(
    width: max(w, 300),
    height: h + (label == null ? 0 : 60),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: w,
          height: h,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _MiniMinesPainter(rows, cell, glow, ring, showMines),
                ),
              ),
              // 가운데 칸을 톡 누르는 모습
              if (pulse) const IgnorePointer(child: TapPulse(size: 96)),
            ],
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 14),
          ArtLabel(label, color: _minesColor, filled: false),
        ],
      ],
    ),
  );
}

class _MiniMinesPainter extends CustomPainter {
  _MiniMinesPainter(this.rows, this.s, this.glow, this.ring, this.showMines);

  final List<String> rows;
  final double s;
  final Set<(int, int)> glow;
  final Set<(int, int)> ring;
  final bool showMines;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = rows.first.length;
    final origin = Offset((size.width - cols * s) / 2, (size.height - rows.length * s) / 2);

    // 판 바탕 (게임과 같은 나무 테두리)
    final panel = RRect.fromRectAndRadius(
      (origin & Size(cols * s, rows.length * s)).inflate(s * 0.12),
      Radius.circular(s * 0.28),
    );
    canvas.drawRRect(panel, Paint()..color = const Color(0xFF6B4F3A));
    canvas.drawRRect(panel.deflate(s * 0.06), Paint()..color = const Color(0xFFCDBB97));

    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < cols; c++) {
        final ch = rows[r][c];
        final rect = Rect.fromLTWH(origin.dx + c * s, origin.dy + r * s, s, s).deflate(s * 0.03);
        final alt = (r + c).isOdd;
        final open = '012345678'.contains(ch) || (ch == '*' && showMines);
        if (open) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(s * 0.14)),
            Paint()..color = alt ? const Color(0xFFE6D9BC) : const Color(0xFFEDE1C7),
          );
        } else {
          _tile(canvas, rect, alt);
        }
        final center = rect.center;
        if ('12345678'.contains(ch)) {
          final n = int.parse(ch);
          _text(canvas, '$n', center, s * 0.62, numberColors[n]);
        } else if (ch == 'F') {
          drawFlagGlyph(canvas, center, s, 1);
        } else if (ch == '?') {
          drawQuestionBadge(canvas, center, s, 1);
        } else if (ch == '*' && showMines) {
          _bomb(canvas, center, s * 0.3);
        }
        if (glow.contains((r, c))) {
          final p = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.1
            ..color = const Color(0xFFE5484D);
          canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(s * 0.02), Radius.circular(s * 0.16)), p);
          // 지뢰라고 짐작되는 칸을 알려 주는 깃발
          drawFlagGlyph(canvas, center, s, 0.9);
        }
        if (ring.contains((r, c))) {
          // 이 칸의 둘레 8칸을 감싸는 테두리
          final around = Rect.fromLTWH(origin.dx + (c - 1) * s, origin.dy + (r - 1) * s, 3 * s, 3 * s);
          canvas.drawRRect(
            RRect.fromRectAndRadius(around.deflate(s * 0.02), Radius.circular(s * 0.2)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = s * 0.07
              ..color = const Color(0xFF3E7BFA),
          );
        }
      }
    }
  }

  void _tile(Canvas canvas, Rect rect, bool alt) {
    final face = alt ? const Color(0xFF86CC62) : const Color(0xFF92D46E);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.16));
    canvas.drawRRect(rr.shift(Offset(0, s * 0.07)), Paint()..color = const Color(0xFF4F9A3A));
    canvas.drawRRect(rr, Paint()..color = face);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + s * 0.08, rect.top + s * 0.07, rect.width - s * 0.16, rect.height * 0.3),
        Radius.circular(s * 0.1),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  void _bomb(Canvas canvas, Offset center, double radius) {
    final body = Paint()..color = const Color(0xFF2B2D42);
    final spike = Paint()
      ..color = const Color(0xFF2B2D42)
      ..strokeWidth = radius * 0.28
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 8; k++) {
      final a = k * pi / 4;
      canvas.drawLine(
        center + Offset(cos(a), sin(a)) * radius * 0.8,
        center + Offset(cos(a), sin(a)) * radius * 1.22,
        spike,
      );
    }
    canvas.drawCircle(center, radius, body);
    canvas.drawCircle(
      center + Offset(-radius * 0.35, -radius * 0.38),
      radius * 0.2,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
  }

  void _text(Canvas canvas, String t, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          fontFamily: 'NanumGothic',
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_MiniMinesPainter old) => true;
}

/// 꾹 눌렀을 때 뜨는 동그란 메뉴 그림.
class _RadialMenuArt extends StatelessWidget {
  const _RadialMenuArt();

  @override
  Widget build(BuildContext context) {
    const c = Offset(160, 150);
    const r = 44.0;
    Widget option(Offset center, Color color, String label, Widget icon) => Positioned(
          left: center.dx - r,
          top: center.dy - r,
          child: Container(
            width: r * 2,
            height: r * 2,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 4),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), offset: const Offset(0, 4))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 34, child: Center(child: icon)),
                Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
        );
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _RadialLinesPainter(c))),
        option(const Offset(160, 56), const Color(0xFF3E7BFA), '열기',
            const Icon(Icons.touch_app_rounded, size: 30, color: Color(0xFF3E7BFA))),
        option(const Offset(256, 240), const Color(0xFFE5484D), '깃발',
            CustomPaint(size: const Size(34, 34), painter: _GlyphPainter(flag: true))),
        option(const Offset(64, 240), const Color(0xFF7E57C2), '물음표',
            CustomPaint(size: const Size(34, 34), painter: _GlyphPainter(flag: false))),
        const Positioned(
          left: 160 - 20,
          top: 150 - 6,
          child: Icon(Icons.touch_app_rounded, size: 40, color: Color(0xFF3B2F2F)),
        ),
      ],
    );
  }
}

class _RadialLinesPainter extends CustomPainter {
  _RadialLinesPainter(this.c);

  final Offset c;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final p in const [Offset(160, 56), Offset(256, 240), Offset(64, 240)]) {
      canvas.drawLine(c, p, line);
    }
    final tile = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: 76, height: 76),
      const Radius.circular(14),
    );
    canvas.drawRRect(tile.shift(const Offset(0, 5)), Paint()..color = const Color(0xFF4F9A3A));
    canvas.drawRRect(tile, Paint()..color = const Color(0xFF92D46E));
  }

  @override
  bool shouldRepaint(_RadialLinesPainter old) => false;
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({required this.flag});

  final bool flag;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (flag) {
      drawFlagGlyph(canvas, c + const Offset(0, -2), 40, 1);
    } else {
      drawQuestionBadge(canvas, c, 52, 0.9);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.flag != flag;
}
