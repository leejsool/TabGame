part of 'jigsaw_table.dart';

// 판 그림 (파일을 역할별로 나눈 것)

class _TablePainter extends CustomPainter {
  _TablePainter({
    required this.c,
    required this.pieces,
    required this.image,
    required this.slotLines,
    required this.getScale,
    required this.getOffset,
    required this.getDragLayer,
    required this.pop,
    required this.reveal,
    required this.pulse,
    required this.viewTick,
  }) : super(repaint: Listenable.merge([c, pop, reveal, pulse, viewTick]));

  final JigsawController c;
  final PieceImages pieces;
  final ui.Image image;
  final Path slotLines;
  final double Function() getScale;
  final Offset Function() getOffset;
  final _DragLayer? Function() getDragLayer;
  final Animation<double> pop;
  final Animation<double> reveal;
  final Animation<double> pulse;
  final Listenable viewTick;

  static const _outside = Color(0xFF244B57);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = getScale(), offset = getOffset();
    canvas.drawRect(Offset.zero & size, Paint()..color = _outside);
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    final table = c.tableSize;
    final tableRect = Offset.zero & table;
    canvas.drawRRect(
      RRect.fromRectAndRadius(tableRect, const Radius.circular(36)),
      Paint()
        ..shader = ui.Gradient.radial(
          tableRect.center,
          table.longestSide * 0.7,
          const [Color(0xFF4A8696), Color(0xFF2F5E6B)],
        ),
    );

    // 판(그림 자리)
    final board = c.boardRect;
    canvas.drawRect(board.inflate(6), Paint()..color = const Color(0x33000000));
    canvas.drawRect(board, Paint()..color = const Color(0x26FFFFFF));
    if (c.ghost && !c.completed) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        board,
        Paint()
          ..color = const Color(0x38FFFFFF)
          ..filterQuality = FilterQuality.medium,
      );
    }
    canvas.drawPath(
      slotLines,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / scale.clamp(0.2, 4)
        ..color = Color(c.ghost ? 0x40FFFFFF : 0x18FFFFFF),
    );
    canvas.drawRect(
      board,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 / scale.clamp(0.2, 4)
        ..color = const Color(0x66FFFFFF),
    );

    // 붙은 조각 → 안 붙은 조각 순서로 (order 가 이미 그 순서)
    final dragging = c.dragging;
    final dragSet = dragging == null ? const <int>{} : c.dragMembers.toSet();
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (final i in c.order) {
      if (dragSet.contains(i)) continue;
      canvas.drawImage(pieces.images[i], c.pos[i], paint);
    }

    // 방금 붙은 조각 반짝임
    if (c.lastPlaced.isNotEmpty && pop.value < 1 && !c.completed) {
      final t = pop.value;
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (6 + 10 * t) / scale.clamp(0.2, 4)
        ..color = Colors.white.withValues(alpha: (1 - t) * 0.9);
      for (final i in c.lastPlaced) {
        canvas.drawPath(c.geometry.paths[i].shift(c.pos[i]), glow);
      }
    }

    // 완성: 그림 전체가 이음매 없이 나타난다
    if (c.completed) {
      final t = Curves.easeInOut.transform(reveal.value);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        board,
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, t)
          ..filterQuality = FilterQuality.medium,
      );
      canvas.drawRect(
        board.inflate(4 + 10 * sin(reveal.value * pi)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 / scale.clamp(0.2, 4)
          ..color = const Color(0xFFFFE26B).withValues(alpha: 0.4 + 0.6 * sin(reveal.value * pi)),
      );
    }

    // 힌트: 그 조각과 제자리를 깜빡여 알려준다
    final hint = c.hintPiece;
    if (hint != null && !c.completed) {
      final glow = 0.45 + 0.55 * pulse.value;
      final w = (7 + 5 * pulse.value) / scale.clamp(0.2, 4);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = const Color(0xFFFFD84D).withValues(alpha: glow);
      canvas.drawPath(c.geometry.paths[hint].shift(c.targetPos(hint)), paint);
      canvas.drawPath(c.geometry.paths[hint].shift(c.pos[hint]), paint);
      canvas.drawPath(
        c.geometry.paths[hint].shift(c.targetPos(hint)),
        Paint()..color = const Color(0xFFFFD84D).withValues(alpha: 0.18 * glow),
      );
    }

    // 지금 끌고 있는 조각(덩어리)은 맨 위에, 그림자와 함께
    if (dragging != null) {
      final layer = getDragLayer();
      if (layer != null) {
        // 덩어리를 한 장으로 합쳐 둔 그림을 옮겨 그리기만 한다 (조각이 많아도 가볍다)
        layer.paint(canvas, c.pos[dragging]);
      } else {
        _paintDragSlow(canvas, dragging, c.dragMembers);
      }
    }
    canvas.restore();
  }

  /// 합친 그림을 못 만들었을 때의 예비 방법 (조각마다 그림자를 그린다).
  void _paintDragSlow(Canvas canvas, int dragging, List<int> dragMembers) {
    final shadow = Paint()
      ..colorFilter = const ColorFilter.mode(Color(0x66000000), BlendMode.srcIn)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    var bounds = c.pos[dragging] & c.geometry.boxes[dragging].size;
    for (final m in dragMembers) {
      bounds = bounds.expandToInclude(c.pos[m] & c.geometry.boxes[m].size);
      canvas.drawImage(pieces.images[m], c.pos[m] + const Offset(10, 14), shadow);
    }
    final center = bounds.center;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.04);
    canvas.translate(-center.dx, -center.dy);
    final members = dragMembers.toSet();
    for (final m in c.order) {
      if (!members.contains(m)) continue;
      canvas.drawImage(pieces.images[m], c.pos[m], Paint()..filterQuality = FilterQuality.medium);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TablePainter old) => true;
}

/// 끌고 있는 덩어리(조각 여러 개)와 그 그림자를 한 장의 이미지로 합쳐 둔 것.
///
/// 조각마다 흐린 그림자를 매 프레임 따로 그리면 큰 덩어리를 끌 때 랙이 생기므로,
/// 끌기 시작할 때 한 번만 합치고 그 뒤에는 이 한 장을 옮겨 그리기만 한다.
class _DragLayer {
  _DragLayer._(this._image, this._origin, this._startPos, this._center);

  /// 그림자 여백까지 포함해 합친 이미지.
  final ui.Image _image;

  /// 끌기 시작 때 이미지 왼쪽 위의 탁자 좌표.
  final Offset _origin;

  /// 끌기 시작 때 대표 조각의 위치 (얼마나 움직였는지 재는 기준) / 덩어리 중심.
  final Offset _startPos;
  final Offset _center;

  static const double _pad = 40;

  /// 지금 끌고 있는 덩어리로 만든다. 못 만들면(예: 이미지 생성 미지원 환경) null.
  static _DragLayer? build(JigsawController c, PieceImages pieces) {
    final leader = c.dragging;
    if (leader == null) return null;
    try {
      final members = c.dragMembers.toSet();
      var bounds = c.pos[leader] & c.geometry.boxes[leader].size;
      for (final m in members) {
        bounds = bounds.expandToInclude(c.pos[m] & c.geometry.boxes[m].size);
      }
      final origin = bounds.topLeft - const Offset(_pad, _pad);
      final w = (bounds.width + _pad * 2).ceil(), h = (bounds.height + _pad * 2).ceil();
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.translate(-origin.dx, -origin.dy);
      final ordered = [for (final i in c.order) if (members.contains(i)) i];
      // 그림자: 덩어리 전체를 한 번에 흐리게
      canvas.saveLayer(
        origin & Size(w.toDouble(), h.toDouble()),
        Paint()
          ..colorFilter = const ColorFilter.mode(Color(0x66000000), BlendMode.srcIn)
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      );
      for (final m in ordered) {
        canvas.drawImage(pieces.images[m], c.pos[m] + const Offset(10, 14), Paint());
      }
      canvas.restore();
      for (final m in ordered) {
        canvas.drawImage(pieces.images[m], c.pos[m], Paint()..filterQuality = FilterQuality.medium);
      }
      final picture = rec.endRecording();
      final image = picture.toImageSync(w, h);
      picture.dispose();
      return _DragLayer._(image, origin, c.pos[leader], bounds.center);
    } catch (_) {
      return null;
    }
  }

  void paint(Canvas canvas, Offset leaderPos) {
    final delta = leaderPos - _startPos;
    final center = _center + delta;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.04);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawImage(_image, _origin + delta, Paint()..filterQuality = FilterQuality.medium);
    canvas.restore();
  }

  void dispose() => _image.dispose();
}
