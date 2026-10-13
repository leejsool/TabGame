import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/tutorial.dart';

const Color _jigsawColor = Color(0xFFE09F3E);

/// 직소퍼즐 게임 방법.
GameTutorial jigsawTutorial() => GameTutorial(
      title: '직소퍼즐',
      color: _jigsawColor,
      steps: [
        TutorialStep(
          title: '그림을 고르고 조각 수를 정해요',
          body: '기본 그림 중에서 고르거나, 내 사진을 갤러리에서 골라 퍼즐로 만들 수 있어요.\n'
              '조각 수도 고를 수 있어요: 아주 쉬움(12조각)부터 어려움(96조각)까지. 처음엔 12조각으로 가볍게 시작해 보세요!',
          art: (context, accent) => const ArtCanvas(width: 340, height: 300, child: _ChooseArt()),
        ),
        TutorialStep(
          title: '조각을 끌어다 맞춰요',
          body: '흩어진 조각을 손가락으로 끌어서 그림 자리에 가져가요. 알맞은 자리에 가까워지면 '
              '"딸깍!" 하고 저절로 붙고 움직이지 않아요.\n'
              '판 위에 희미하게 보이는 밑그림이 길잡이가 되어 줘요.',
          art: (context, accent) => const ArtCanvas(width: 340, height: 320, child: _DragArt()),
        ),
        TutorialStep(
          title: '조각끼리도 붙어요',
          body: '서로 이웃한 두 조각을 맞대면 딸깍 이어져서 한 덩어리가 돼요. 덩어리는 한꺼번에 움직여요.\n'
              '판에서 먼 곳에서도 이웃 조각부터 이어 두면 나중에 한 번에 옮길 수 있어 편해요.',
          art: (context, accent) => const ArtCanvas(width: 340, height: 300, child: _GroupArt()),
        ),
        TutorialStep(
          title: '아래 버튼으로 도움받기',
          body: '막히면 화면 아래 버튼을 눌러 보세요. 어려운 도전을 하고 싶다면 밑그림을 꺼 보세요!',
          art: (context, accent) => ArtCanvas(
            width: 340,
            height: 300,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (icon, name, desc) in const [
                  (Icons.image_outlined, '완성 그림', '완성된 그림을 크게 보여 줘요'),
                  (Icons.visibility_rounded, '밑그림', '판 위의 희미한 그림을 켜고 꺼요'),
                  (Icons.lightbulb_rounded, '힌트', '맞출 조각과 제자리를 깜빡여 알려 줘요'),
                  (Icons.shuffle_rounded, '흩어 놓기', '조각을 다시 흩뿌려 줘요'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(icon, size: 30, color: accent),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                              Text(desc, style: const TextStyle(fontSize: 13.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        TutorialStep(
          title: '확대하고 밀어서 옮겨요',
          body: '조각이 작아서 맞추기 어렵다면 두 손가락을 벌려서 확대해 보세요. 오므리면 다시 작아져요.\n'
              '조각이 없는 빈 곳을 한 손가락으로 밀면 화면이 움직여요.',
          art: (context, accent) => const ArtCanvas(
            width: 340,
            height: 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ArtBadge(icon: Icons.pinch_rounded, color: _jigsawColor, label: '두 손가락: 확대·축소'),
                ArtBadge(icon: Icons.open_with_rounded, color: _jigsawColor, label: '빈 곳 밀기: 화면 이동'),
              ],
            ),
          ),
        ),
      ],
    );

// ── 퍼즐 조각 그림 ──

/// 작은 풍경 그림. [variant]마다 색이 다르다.
void _drawPicture(Canvas canvas, Rect r, int variant) {
  const skies = [
    [Color(0xFF8EC9F5), Color(0xFFE6F4FF)],
    [Color(0xFFF7A98B), Color(0xFFFFE9C7)],
    [Color(0xFF9B8CE0), Color(0xFFE3DDFB)],
  ];
  const hills = [
    [Color(0xFF6BBF6A), Color(0xFF3F9A4D)],
    [Color(0xFFC98B5A), Color(0xFF9B5F3A)],
    [Color(0xFF5FA8A0), Color(0xFF3B7C8A)],
  ];
  final sky = skies[variant % 3];
  final hill = hills[variant % 3];
  canvas.drawRect(
    r,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: sky,
      ).createShader(r),
  );
  canvas.drawCircle(
    Offset(r.left + r.width * 0.74, r.top + r.height * 0.24),
    r.width * 0.09,
    Paint()..color = const Color(0xFFFFE066),
  );
  Path hillPath(double top, double phase) {
    final p = Path()..moveTo(r.left, r.bottom);
    p.lineTo(r.left, r.top + r.height * top);
    p.quadraticBezierTo(
      r.left + r.width * (0.3 + phase),
      r.top + r.height * (top - 0.22),
      r.left + r.width * 0.62,
      r.top + r.height * (top - 0.02),
    );
    p.quadraticBezierTo(
      r.left + r.width * (0.85 - phase),
      r.top + r.height * (top + 0.1),
      r.right,
      r.top + r.height * (top - 0.08),
    );
    p.lineTo(r.right, r.bottom);
    p.close();
    return p;
  }

  canvas.drawPath(hillPath(0.62, 0.0), Paint()..color = hill[0]);
  canvas.drawPath(hillPath(0.78, 0.1), Paint()..color = hill[1]);
  // 작은 집
  final hx = r.left + r.width * 0.3, hy = r.top + r.height * 0.7;
  final hw = r.width * 0.12;
  canvas.drawRect(Rect.fromLTWH(hx, hy, hw, hw * 0.8), Paint()..color = const Color(0xFFFFF3E0));
  canvas.drawPath(
    Path()
      ..moveTo(hx - hw * 0.12, hy)
      ..lineTo(hx + hw * 0.5, hy - hw * 0.55)
      ..lineTo(hx + hw * 1.12, hy)
      ..close(),
    Paint()..color = const Color(0xFFD9534F),
  );
}

int _hEdge(int r, int c) => (r + c).isEven ? 1 : -1;
int _vEdge(int r, int c) => (r + c).isEven ? -1 : 1;

/// 3×3 퍼즐에서 조각 (r,c)의 네 변 모양: 위·오른쪽·아래·왼쪽. 1은 튀어나옴, -1은 들어감, 0은 평평.
List<int> _edges(int r, int c) => [
      r == 0 ? 0 : -_vEdge(r - 1, c),
      c == 2 ? 0 : _hEdge(r, c),
      r == 2 ? 0 : _vEdge(r, c),
      c == 0 ? 0 : -_hEdge(r, c - 1),
    ];

void _side(Path path, Offset p0, Offset p1, Offset n, int k) {
  if (k == 0) {
    path.lineTo(p1.dx, p1.dy);
    return;
  }
  final v = p1 - p0;
  final h = v.distance * 0.24 * k;
  Offset at(double t, double hh) => p0 + v * t + n * hh;
  void cubic(Offset a, Offset b, Offset c) => path.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
  final a = at(0.37, 0);
  path.lineTo(a.dx, a.dy);
  cubic(at(0.37, h * 0.5), at(0.29, h * 0.62), at(0.32, h * 0.92));
  cubic(at(0.35, h * 1.3), at(0.65, h * 1.3), at(0.68, h * 0.92));
  cubic(at(0.71, h * 0.62), at(0.63, h * 0.5), at(0.63, 0));
  path.lineTo(p1.dx, p1.dy);
}

/// 조각 (r,c)의 모양. [s]는 한 칸의 크기, 위치는 판 안 자리 그대로.
Path _piecePath(int r, int c, double s) {
  final e = _edges(r, c);
  final l = c * s, t = r * s;
  final tl = Offset(l, t), tr = Offset(l + s, t), br = Offset(l + s, t + s), bl = Offset(l, t + s);
  final p = Path()..moveTo(tl.dx, tl.dy);
  _side(p, tl, tr, const Offset(0, -1), e[0]);
  _side(p, tr, br, const Offset(1, 0), e[1]);
  _side(p, br, bl, const Offset(0, 1), e[2]);
  _side(p, bl, tl, const Offset(-1, 0), e[3]);
  p.close();
  return p;
}

class _PieceSpec {
  const _PieceSpec(this.r, this.c, {this.offset = Offset.zero, this.angle = 0, this.glow});

  final int r;
  final int c;

  /// 제자리에서 얼마나 떨어져 있는가.
  final Offset offset;
  final double angle;
  final Color? glow;
}

/// 3×3 퍼즐 그림: 밑그림, 제자리에 붙은 조각, 흩어진 조각.
class _PuzzlePainter extends CustomPainter {
  _PuzzlePainter({
    required this.s,
    required this.origin,
    this.placed = const {},
    this.loose = const [],
    this.ghost = true,
    this.variant = 0,
    this.targetGlow,
    this.showBoard = true,
  });

  final double s;
  final Offset origin;
  final Set<(int, int)> placed;
  final List<_PieceSpec> loose;
  final bool ghost;
  final int variant;
  final (int, int)? targetGlow;

  /// false이면 판과 빈 자리는 그리지 않고 조각만 그린다.
  final bool showBoard;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    final board = Rect.fromLTWH(0, 0, 3 * s, 3 * s);
    if (showBoard) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(board.inflate(8), const Radius.circular(14)),
        Paint()..color = const Color(0xFFE8DCC4),
      );
    }
    // 밑그림
    if (ghost) {
      canvas.saveLayer(board, Paint()..color = Colors.white.withValues(alpha: 0.28));
      _drawPicture(canvas, board, variant);
      canvas.restore();
    }
    // 빈 자리 테두리
    final slot = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFF8C7B5A).withValues(alpha: 0.35);
    for (var r = 0; r < 3 && showBoard; r++) {
      for (var c = 0; c < 3; c++) {
        if (!placed.contains((r, c))) canvas.drawPath(_piecePath(r, c, s), slot);
      }
    }
    for (final (r, c) in placed) {
      _drawPiece(canvas, board, _PieceSpec(r, c));
    }
    if (targetGlow != null) {
      canvas.drawPath(
        _piecePath(targetGlow!.$1, targetGlow!.$2, s),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFF2E9E5B),
      );
    }
    for (final p in loose) {
      _drawPiece(canvas, board, p);
    }
    canvas.restore();
  }

  void _drawPiece(Canvas canvas, Rect board, _PieceSpec p) {
    final center = Offset(p.c * s + s / 2, p.r * s + s / 2);
    canvas.save();
    canvas.translate(p.offset.dx + center.dx, p.offset.dy + center.dy);
    canvas.rotate(p.angle);
    canvas.translate(-center.dx, -center.dy);
    final path = _piecePath(p.r, p.c, s);
    canvas.drawShadow(path, Colors.black, 3, true);
    canvas.save();
    canvas.clipPath(path);
    _drawPicture(canvas, board, variant);
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: 0.85),
    );
    if (p.glow != null) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = p.glow!,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PuzzlePainter old) => true;
}

class _ChooseArt extends StatelessWidget {
  const _ChooseArt();

  @override
  Widget build(BuildContext context) {
    Widget thumb(int variant) => Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 3))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: CustomPaint(painter: _ThumbPainter(variant)),
          ),
        );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            thumb(0),
            thumb(1),
            thumb(2),
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: _jigsawColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _jigsawColor, width: 3),
              ),
              child: const Icon(Icons.photo_library_rounded, size: 40, color: _jigsawColor),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text('기본 그림 · 내 사진', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 26),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            ArtLabel('12조각', color: _jigsawColor),
            ArtLabel('24조각', color: _jigsawColor, filled: false),
            ArtLabel('48조각', color: _jigsawColor, filled: false),
            ArtLabel('96조각', color: _jigsawColor, filled: false),
          ],
        ),
      ],
    );
  }
}

class _ThumbPainter extends CustomPainter {
  _ThumbPainter(this.variant);

  final int variant;

  @override
  void paint(Canvas canvas, Size size) => _drawPicture(canvas, Offset.zero & size, variant);

  @override
  bool shouldRepaint(_ThumbPainter old) => old.variant != variant;
}

class _DragArt extends StatelessWidget {
  const _DragArt();

  @override
  Widget build(BuildContext context) {
    const s = 80.0;
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _PuzzlePainter(
              s: s,
              origin: const Offset(16, 40),
              placed: const {(0, 0), (0, 1), (0, 2), (1, 0), (2, 1), (2, 2), (1, 2)},
              targetGlow: (1, 1),
              loose: const [
                _PieceSpec(1, 1, offset: Offset(78, 112), angle: 0.18, glow: Color(0xFFE09F3E)),
              ],
            ),
          ),
        ),
        // 조각을 제자리로 끌고 가는 방향
        const Positioned(
          left: 150,
          top: 186,
          child: Icon(Icons.north_west_rounded, size: 46, color: Color(0xFF3B2F2F)),
        ),
        const Positioned(left: 74, top: 110, child: ArtLabel('딸깍!', color: Color(0xFF2E9E5B))),
        const Positioned(
          left: 196,
          top: 236,
          child: TapPulse(size: 60, color: _jigsawColor),
        ),
        const Positioned(left: 0, right: 0, top: 0, child: Center(child: ArtLabel('밑그림을 보고 제자리에', color: _jigsawColor, filled: false))),
      ],
    );
  }
}

class _GroupArt extends StatelessWidget {
  const _GroupArt();

  @override
  Widget build(BuildContext context) {
    const s = 56.0;
    Widget pieces(List<_PieceSpec> specs) => SizedBox(
          width: 150,
          height: 120,
          child: CustomPaint(
            painter: _PuzzlePainter(
              s: s,
              origin: const Offset(20, 30),
              showBoard: false,
              ghost: false,
              variant: 1,
              loose: specs,
            ),
          ),
        );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            pieces(const [
              _PieceSpec(0, 0, offset: Offset(-12, 6), angle: -0.12),
              _PieceSpec(0, 1, offset: Offset(20, -8), angle: 0.14),
            ]),
            const Icon(Icons.arrow_forward_rounded, size: 34, color: Color(0xFF3B2F2F)),
            pieces(const [
              _PieceSpec(0, 0, glow: Color(0xFF2E9E5B)),
              _PieceSpec(0, 1, glow: Color(0xFF2E9E5B)),
            ]),
          ],
        ),
        const SizedBox(height: 14),
        const ArtLabel('이어진 조각은 한 덩어리', color: Color(0xFF2E9E5B), filled: false),
        const SizedBox(height: 18),
        const Icon(Icons.open_with_rounded, size: 40, color: Color(0xFF3B2F2F)),
        const SizedBox(height: 4),
        const Text('한꺼번에 움직여요', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
