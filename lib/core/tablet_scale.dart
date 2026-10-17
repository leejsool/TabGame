import 'dart:math';

import 'package:flutter/widgets.dart';

/// 이 기기를 태블릿으로 보는 화면의 짧은 쪽 길이 (논리 픽셀).
const double kTabletMinSide = 600;

/// 폰에 맞춰 짠 화면을 태블릿에서는 통째로 키워서 보여 준다. 글자·타일·버튼·누르는 자리가 모두 같은 비율로 커진다.
///
/// 화면을 [baseSize] 크기의 폰에 놓인 것처럼 짠 뒤, 실제 칸에 맞게 키운다. 가로·세로 중 더 빠듯한 쪽에 맞추므로
/// 아래나 옆이 잘리지 않는다 (태블릿 가로처럼 세로가 빠듯하면 거의 그대로다). 폰에서는 아무것도 하지 않는다.
/// 안에서 띄우는 대화상자·안내 창은 따로 뜨므로 커지지 않는다.
class TabletScale extends StatelessWidget {
  const TabletScale({super.key, required this.child, this.baseSize = const Size(400, 840), this.maxScale = 1.6});

  final Widget child;

  /// 화면을 짤 때 기준으로 삼는 폰 화면 크기 (위쪽 상태 줄을 뺀 크기).
  final Size baseSize;
  final double maxScale;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).shortestSide < kTabletMinSide) return child;
    return LayoutBuilder(
      builder: (context, box) {
        if (!box.hasBoundedWidth || !box.hasBoundedHeight) return child;
        // (태블릿에서는 배율이 1이어도 같은 모양의 위젯 트리를 써서, 화면을 돌려도 화면 상태가 그대로 남게 한다)
        final k = min(box.maxWidth / baseSize.width, box.maxHeight / baseSize.height).clamp(1.0, maxScale);
        return SizedBox.expand(
          child: FittedBox(
            alignment: Alignment.topCenter,
            child: SizedBox(width: box.maxWidth / k, height: box.maxHeight / k, child: child),
          ),
        );
      },
    );
  }
}
