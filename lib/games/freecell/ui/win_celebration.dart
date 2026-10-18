import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/freecell_rules.dart' show suitOf;
import 'playing_card.dart';

part 'win_celebration_sim.dart';
part 'win_celebration_draw.dart';

enum _Mode {
  /// 윈도우 프리셀처럼 통통 튀면서 화면 밖으로 (잔상을 길게 남긴다).
  bounce,

  /// 위로 솟구쳤다가 꼭대기에서 폭발한다.
  burst,

  /// 화면 쪽으로 날아와 점점 커지다가 부딪히며 터진다.
  zoom,
}

class _Flyer {
  _Flyer({
    required this.card,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.launchAt,
    required this.mode,
    required this.spin,
  })  : x0 = x,
        y0 = y;

  final int card;
  double x, y, vx, vy; // 카드 왼쪽 위 좌표
  final double x0, y0;
  final double launchAt;
  final _Mode mode;
  final double spin;
  double rot = 0, scale = 1, alpha = 1, age = 0;
  double? lastStampX, lastStampY;

  /// 화면으로 날아오는 카드(zoom)가 부딪히는 자리 (카드마다 화면의 아무 곳이나).
  double tx = 0, ty = 0;
  bool launched = false, gone = false;

  /// 잔상: (가운데 x, 가운데 y, 크기, 회전)
  final List<(double, double, double, double)> trail = [];
}

class _Particle {
  _Particle(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color, this.kind,
      {this.gravity = 0, this.spin = 0})
      : maxLife = life;

  double x, y, vx, vy, life, size, gravity, spin, rot = 0;
  final double maxLife;
  final Color color;

  /// 0 = 색종이 조각, 1 = 별, 2 = 불꽃(선)
  final int kind;
}

class _Ring {
  _Ring(this.x, this.y, this.color, this.maxRadius);

  final double x, y, maxRadius;
  final Color color;
  double age = 0;
}

/// 프리셀/솔리테어를 끝냈을 때의 화려한 축하 연출.
/// 카드가 완성 칸에서 튀어나와 잔상을 남기며 튀고, 솟구쳐 터지고, 화면으로 날아와 부딪히며,
/// 색종이와 불꽃이 쏟아진다.
class WinCelebration {
  WinCelebration({
    required this.view,
    required this.cardSize,
    required List<Offset> foundationPositions,
    required int seed,
    double pixelRatio = 2,
  })  : _rng = Random(seed),
        // ignore: prefer_initializing_formals
        _pixelRatio = pixelRatio {
    _buildImages();
    _banner = _bannerPainters();
    var order = 0;
    for (var rank = 12; rank >= 0; rank--) {
      for (var suit = 0; suit < 4; suit++) {
        final p = foundationPositions[suit];
        // 대부분은 윈도우처럼 튀는 카드. 솟구쳐 터지는 카드는 가끔, 화면으로 날아오는 카드는 아주 드물게.
        final mode = switch (order) {
          6 || 19 || 32 || 45 => _Mode.zoom,
          _ when order % 6 == 3 => _Mode.burst,
          _ => _Mode.bounce,
        };
        final dir = _rng.nextBool() ? 1.0 : -1.0;
        final cw = cardSize.width, ch = cardSize.height;
        final flyer = _Flyer(
          card: rank * 4 + suit,
          x: p.dx,
          y: p.dy,
          vx: switch (mode) {
            _Mode.bounce => dir * cw * (1.0 + _rng.nextDouble() * 1.5),
            _Mode.burst => dir * cw * (0.3 + _rng.nextDouble() * 1.2),
            _Mode.zoom => 0,
          },
          vy: switch (mode) {
            _Mode.bounce => -ch * (1.0 + _rng.nextDouble() * 1.7),
            _Mode.burst => -ch * (3.0 + _rng.nextDouble() * 1.4),
            _Mode.zoom => 0,
          },
          launchAt: 0.3 + order * 0.28,
          mode: mode,
          spin: dir * (0.5 + _rng.nextDouble() * 2.5),
        );
        if (mode == _Mode.zoom) {
          // 정가운데만이 아니라 화면 어디든 (가장자리는 조금 피한다)
          flyer.tx = view.width * (0.16 + 0.68 * _rng.nextDouble());
          flyer.ty = view.height * (0.2 + 0.58 * _rng.nextDouble());
        }
        _flyers.add(flyer);
        order++;
      }
    }
  }

  final Size view;
  final Size cardSize;
  final double _pixelRatio;
  final Random _rng;
  final List<_Flyer> _flyers = [];
  final List<_Particle> _particles = [];
  final List<_Ring> _rings = [];
  final Map<int, ui.Image> _images = {};
  late final (TextPainter, TextPainter) _banner;

  double time = 0;
  double _flash = 0.6;

  /// 윈도우처럼 지워지지 않는 잔상: 튀는 카드를 지나간 자리마다 카드를 도장처럼 찍어 한 장의 그림에 쌓는다.
  ui.Image? _acc;
  bool _accOk = true;
  final List<(int, double, double)> _stamps = [];
  static const _accScale = 0.6;
  late final TextPainter _skipHint = TextPainter(
    text: const TextSpan(
      text: '화면을 누르면 계속해요',
      style: TextStyle(fontFamily: 'NanumGothic', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  static const _confettiColors = [
    Color(0xFFFFD84D),
    Color(0xFFFF5C7A),
    Color(0xFF5CC8FF),
    Color(0xFF7CFFB2),
    Color(0xFFFFFFFF),
    Color(0xFFFF9F43),
    Color(0xFFB388FF),
  ];

  /// 화면으로 날아오는 카드들이 부딪히는 자리들 (테스트용).
  List<Offset> get zoomTargets => [
        for (final f in _flyers)
          if (f.mode == _Mode.zoom) Offset(f.tx, f.ty),
      ];

  /// 연출이 끝났는가 (모든 카드와 잔상이 사라지고 시간이 충분히 지났다).
  bool get finished => time > 8 && _flyers.isEmpty && _particles.isEmpty;

  // ── 카드 그림을 미리 한 번씩만 그려 둔다 (잔상 때문에 매 프레임 많이 그리므로) ──

  void _buildImages() {
    final scale = min(_pixelRatio, 2.5) * 1.6;
    final w = (cardSize.width * scale).ceil(), h = (cardSize.height * scale).ceil();
    for (var card = 0; card < 52; card++) {
      try {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.scale(w / cardSize.width, h / cardSize.height);
        drawCard(canvas, card, cardSize);
        final picture = recorder.endRecording();
        _images[card] = picture.toImageSync(w, h);
        picture.dispose();
      } catch (_) {
        break; // 그림을 못 만들면 아래 paint에서 카드를 직접 그린다
      }
    }
  }

  void dispose() {
    _acc?.dispose();
    _acc = null;
    for (final i in _images.values) {
      i.dispose();
    }
    _images.clear();
  }

  (TextPainter, TextPainter) _bannerPainters() {
    final size = min(view.width * 0.2, view.height * 0.22);
    TextPainter make(Paint? foreground, Color? color) => TextPainter(
          text: TextSpan(
            text: '클리어!',
            style: TextStyle(
              fontFamily: 'NanumGothic',
              fontSize: size,
              fontWeight: FontWeight.w900,
              color: foreground == null ? color : null,
              foreground: foreground,
              letterSpacing: size * 0.04,
              shadows: foreground != null
                  ? [Shadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: size * 0.1, offset: Offset(0, size * 0.05))]
                  : null,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.12
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF7A3E00);
    return (make(stroke, null), make(null, const Color(0xFFFFD84D)));
  }

  // ── 진행 ──

  // ── 그리기 ──


}

class WinCelebrationPainter extends CustomPainter {
  WinCelebrationPainter(this.show, Listenable repaint) : super(repaint: repaint);

  final WinCelebration show;

  @override
  void paint(Canvas canvas, Size size) => show.paint(canvas, size);

  @override
  bool shouldRepaint(WinCelebrationPainter old) => true;
}
