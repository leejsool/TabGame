import 'package:flutter/material.dart';

import '../core/dot_levels.dart';
import '../data/dot_storage.dart';
import 'dot_menu_screen.dart';

/// 줄에서 지금 도전할 그림의 번호: 아직 못 깬 가장 앞 그림 (다 깼으면 마지막 그림).
int currentDotStage(List<DotLevel> levels, Map<String, DotStageStats> stats) {
  for (var i = 0; i < levels.length; i++) {
    if (!(stats[levels[i].id]?.cleared ?? false)) return i;
  }
  return levels.length - 1;
}

/// 그림을 옆으로 밀어 고르는 한 줄 (묶음 하나, 또는 내가 만든 그림).
///
/// 어느 그림이든 바로 할 수 있다. [numbered]이면 처음에 아직 못 깬 가장 앞 그림이 가운데에 오고 눈에 띄게 보인다.
class DotStageCarousel extends StatefulWidget {
  const DotStageCarousel({
    super.key,
    required this.levels,
    required this.stats,
    required this.onPlay,
    this.onLongPress,
    this.numbered = true,
    this.listKey = const ValueKey('dot-stage-list'),
  });

  final List<DotLevel> levels;
  final Map<String, DotStageStats> stats;
  final void Function(DotLevel level) onPlay;

  /// 카드를 길게 눌렀다 (내가 만든 그림 지우기).
  final void Function(DotLevel level)? onLongPress;

  /// 기본 그림 줄: 카드에 차례 번호를 붙이고, 아직 못 깬 가장 앞 그림부터 보여 준다.
  final bool numbered;

  final Key listKey;

  @override
  State<DotStageCarousel> createState() => _DotStageCarouselState();
}

class _DotStageCarouselState extends State<DotStageCarousel> {
  static const double _gap = 12;
  ScrollController? _controller;
  double _itemWidth = 0;
  double _viewport = 0;
  late int _current = _currentNow();

  int _currentNow() => widget.numbered ? currentDotStage(widget.levels, widget.stats) : 0;

  /// 카드 [index]가 가운데에 오는 스크롤 위치.
  double _offsetFor(int index) {
    final centered = index * (_itemWidth + _gap) - (_viewport - _itemWidth) / 2;
    final max = widget.levels.length * (_itemWidth + _gap) - _gap - _viewport;
    return centered.clamp(0.0, max < 0 ? 0.0 : max);
  }

  @override
  void didUpdateWidget(DotStageCarousel old) {
    super.didUpdateWidget(old);
    final now = _currentNow();
    if (now != _current) {
      // 방금 그림을 깼다: 다음 도전할 그림 쪽으로 부드럽게 옮겨 준다
      _current = now;
      final c = _controller;
      if (c != null && c.hasClients && widget.numbered) {
        c.animateTo(_offsetFor(now), duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth * 0.42).clamp(150.0, 200.0);
        if (_controller == null || width != _itemWidth || box.maxWidth != _viewport) {
          _itemWidth = width;
          _viewport = box.maxWidth;
          _controller?.dispose();
          _controller = ScrollController(initialScrollOffset: _offsetFor(_current));
        }
        final longPress = widget.onLongPress;
        return SizedBox(
          height: width + 100,
          child: ListView.separated(
            key: widget.listKey,
            controller: _controller,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: widget.levels.length,
            separatorBuilder: (_, _) => const SizedBox(width: _gap),
            itemBuilder: (context, i) {
              final l = widget.levels[i];
              return SizedBox(
                width: width,
                child: DotLevelCard(
                  key: ValueKey('dot-card-${l.id}'),
                  level: l,
                  stats: widget.stats[l.id],
                  number: widget.numbered ? i + 1 : null,
                  highlight: widget.numbered && i == _current && !(widget.stats[l.id]?.cleared ?? false),
                  onTap: () => widget.onPlay(l),
                  onLongPress: longPress == null ? null : () => longPress(l),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
