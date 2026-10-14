import 'package:flutter/material.dart';

import '../core/dandelion_rules.dart';
import '../game/dandelion_controller.dart';
import 'dandelion_art.dart';

/// 5×5 초원. 칸을 누르면 [onPlant]로 알리고, 꽃을 심거나 바람이 불 때 움직임을 보여 준다.
class DandelionBoard extends StatefulWidget {
  const DandelionBoard({super.key, required this.controller, required this.onPlant});

  final DandelionController controller;
  final void Function(int cell) onPlant;

  @override
  State<DandelionBoard> createState() => _DandelionBoardState();
}

class _DandelionBoardState extends State<DandelionBoard> with TickerProviderStateMixin {
  DandelionController get c => widget.controller;

  late final AnimationController _plant = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 1,
  );
  late final AnimationController _blow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
    value: 1,
  );
  late final AnimationController _end = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  int _serial = 0;
  bool _wasOver = false;

  @override
  void initState() {
    super.initState();
    _serial = c.moveSerial;
    _wasOver = c.isOver;
    if (_wasOver) _end.value = 1;
    c.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(DandelionBoard old) {
    super.didUpdateWidget(old);
    if (old.controller != c) {
      old.controller.removeListener(_onChanged);
      c.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    c.removeListener(_onChanged);
    _plant.dispose();
    _blow.dispose();
    _end.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (c.moveSerial != _serial) {
      _serial = c.moveSerial;
      if (c.lastPlanted >= 0) {
        _plant.forward(from: 0);
      } else if (c.lastWind != null) {
        _blow.forward(from: 0);
      } else {
        _plant.value = 1;
        _blow.value = 1;
      }
    }
    if (c.isOver && !_wasOver) {
      _wasOver = true;
      // 마지막 바람이 다 불고 난 뒤에 끝 효과가 나오게 잠깐 기다린다
      final wait = Duration(milliseconds: c.lastWind != null ? 1400 : 300);
      Future<void>.delayed(wait, () {
        if (mounted && c.isOver) _end.forward(from: 0);
      });
    } else if (!c.isOver && _wasOver) {
      _wasOver = false;
      _end.value = 0;
    }
  }

  /// 바람이 부는 동안 날아가는 중인 씨앗들.
  Map<int, ({int from, double t})> _flying() {
    if (c.lastWind == null || !_blow.isAnimating) return const {};
    final t = _blow.value;
    return {
      for (final s in c.lastSeeds)
        s.cell: (from: s.from, t: ((t - (0.1 + (s.dist - 1) * 0.07)) / 0.45).clamp(0.0, 1.0)),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          final side = box.biggest.shortestSide;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final cell = DandLayout(side).hit(d.localPosition);
              if (cell != null) widget.onPlant(cell);
            },
            child: AnimatedBuilder(
              animation: Listenable.merge([c, _plant, _blow, _end]),
              builder: (context, _) => CustomPaint(
                size: Size(side, side),
                painter: DandScenePainter(
                  cells: c.state.cells,
                  flying: _flying(),
                  plantCell: c.lastPlanted,
                  plantT: _plant.value,
                  windDir: _blow.isAnimating ? c.lastWind : null,
                  windT: _blow.value,
                  endT: c.isOver && _blow.isCompleted ? _end.value : 0,
                  endWon: c.winner == Role.dandelion,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
