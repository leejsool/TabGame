import 'package:flutter/material.dart';

import '../core/game_info.dart';

/// 허브 게임 카드의 큰 그림 아이콘.
///
/// 머티리얼 아이콘 대신 게임 안에서 쓰는 그림 그대로(겟 컬러의 병, 솔리테어·프리셀의 카드, 리듬 검사단의
/// 검사 …)나 직접 그린 그림을 쓴다. 그림은 게임 등록(`GameInfo.iconPainter` / `iconImage`)에서 정하고,
/// 없는 게임은 [GameInfo.icon]을 보여 준다. 그림 함수 `paint…Icon`은 각 게임 폴더의 `ui/<게임>_icon.dart`에 있다 (공통 도구는 `icon_kit.dart`).
class GameIcon extends StatelessWidget {
  const GameIcon({super.key, required this.game, this.size = 56});

  final GameInfo game;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = game.iconImage;
    if (image != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          image,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => Icon(game.icon, size: size * 0.7, color: Colors.white),
        ),
      );
    }
    final paint = game.iconPainter;
    if (paint == null) return Icon(game.icon, size: size * 0.7, color: Colors.white);
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _IconPainter(paint)));
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.draw);

  final void Function(Canvas c, double s) draw;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width);
    draw(canvas, size.width);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter old) => false;
}
