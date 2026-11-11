import 'dart:math';

import 'package:flutter/widgets.dart';

/// 전자칠판처럼 아주 큰 화면에서 야추 화면(과 팝업)을 통째로 키워 보여 준다.
///
/// 화면을 태블릿 크기(가로 1280×800, 세로 800×1280)에서 짠 모습 그대로 두고, 실제 칸에 맞게 같은 비율로 키운다.
/// 글자 · 점수판 · 주사위 · 단추 · 누르는 자리가 모두 같이 커지고 모양은 태블릿과 똑같다.
/// 짧은 쪽이 [minSide] 미만인 폰 · 일반 태블릿에서는 아무것도 하지 않는다.
/// 팝업(대화상자)은 화면 위에 따로 뜨므로 팝업마다 이 틀로 한 번 더 감싼다.
class YachtScaled extends StatelessWidget {
  const YachtScaled({super.key, required this.child});

  final Widget child;

  /// 이 크기(짧은 쪽, 논리 픽셀) 이상인 화면만 키운다.
  static const double minSide = 900;

  /// 가장 크게 키우는 배율 (4K 칠판도 이 정도면 충분하다).
  static const double maxScale = 2.4;

  /// 화면 크기 [size]에서 키우는 배율 (1이면 그대로).
  static double factor(Size size) {
    if (size.shortestSide < minSide) return 1;
    final base = size.width >= size.height ? const Size(1280, 800) : const Size(800, 1280);
    return min(size.width / base.width, size.height / base.height).clamp(1.0, maxScale).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (!box.hasBoundedWidth || !box.hasBoundedHeight) return child;
        final k = factor(Size(box.maxWidth, box.maxHeight));
        if (k <= 1.001) return child;
        return SizedBox.expand(
          child: FittedBox(
            child: SizedBox(width: box.maxWidth / k, height: box.maxHeight / k, child: child),
          ),
        );
      },
    );
  }
}
