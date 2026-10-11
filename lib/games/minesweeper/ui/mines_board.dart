import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/mines_controller.dart';
import 'mines_painter.dart';

/// 지뢰찾기 판: 탭=열기(숫자는 코드), 길게 누르기=깃발, 두 손가락으로 확대/이동.
class MinesBoardView extends StatefulWidget {
  const MinesBoardView({super.key, required this.controller});

  final MinesController controller;

  @override
  State<MinesBoardView> createState() => _MinesBoardState();
}

class _MinesBoardState extends State<MinesBoardView> with SingleTickerProviderStateMixin {
  MinesController get c => widget.controller;

  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<int> _frame = ValueNotifier(0);
  final TransformationController _zoom = TransformationController();

  @override
  void initState() {
    super.initState();
    c.addListener(_onController);
    _onController();
  }

  @override
  void dispose() {
    c.removeListener(_onController);
    _ticker.dispose();
    _frame.dispose();
    _zoom.dispose();
    super.dispose();
  }

  /// 애니메이션이 필요한 동안만 프레임을 돌린다.
  bool get _needsFrames => c.clockMs < c.animEndMs + 50 || c.hint != null || c.status == MinesStatus.won && c.clockMs - c.winAt < 5200;

  void _onController() {
    if (c.status == MinesStatus.ready && !_zoom.value.isIdentity()) _zoom.value = Matrix4.identity();
    if (_needsFrames && !_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration _) {
    _frame.value++;
    if (!_needsFrames) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final area = box.biggest;
        final layout = MinesLayout(area, c.board.rows, c.board.cols);
        final repaint = Listenable.merge([c, _frame]);
        return InteractiveViewer(
          transformationController: _zoom,
          minScale: 1,
          maxScale: 3.5,
          // 확대하지 않았을 때는 판이 화면 밖으로 끌려가지 않는다
          boundaryMargin: EdgeInsets.zero,
          child: SizedBox(
            width: area.width,
            height: area.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: RawGestureDetector(
                    behavior: HitTestBehavior.opaque,
                    gestures: {
                      TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                        TapGestureRecognizer.new,
                        (r) => r.onTapUp = (d) {
                          final i = layout.cellAt(d.localPosition);
                          if (i != null) c.tap(i);
                        },
                      ),
                      LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                        () => LongPressGestureRecognizer(duration: const Duration(milliseconds: 320)),
                        (r) => r.onLongPressStart = (d) {
                          final i = layout.cellAt(d.localPosition);
                          if (i != null) c.longPress(i);
                        },
                      ),
                    },
                    child: CustomPaint(painter: MinesPainter(c: c, layout: layout, repaint: repaint)),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(child: CustomPaint(painter: MinesConfettiPainter(c: c, repaint: repaint))),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
