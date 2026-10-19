import 'package:flutter/material.dart';

import '../core/dot_levels.dart';
import '../data/dot_storage.dart';
import 'dot_menu_screen.dart';

/// 지금 도전할 기본 그림의 번호: 아직 못 깬 가장 앞 그림 (다 깼으면 마지막 그림).
int currentDotStage(List<DotLevel> levels, Map<String, DotStageStats> stats) {
  for (var i = 0; i < levels.length; i++) {
    if (!(stats[levels[i].id]?.cleared ?? false)) return i;
  }
  return levels.length - 1;
}

/// 기본 그림을 옆으로 밀어 고르는 줄.
///
/// 처음에는 지금 도전할 그림(아직 못 깬 가장 앞 그림)이 가운데에 오고, 왼쪽으로 밀면 이미 깬 그림을 다시 고를 수 있다.
/// 오른쪽에는 아직 잠긴 그림이 이어진다.
class DotStageCarousel extends StatefulWidget {
  const DotStageCarousel({super.key, required this.levels, required this.stats, required this.onPlay, required this.onLocked, this.unlockAll = false});

  final List<DotLevel> levels;
  final Map<String, DotStageStats> stats;
  final void Function(DotLevel level) onPlay;

  /// 잠긴 그림을 눌렀다 (앞 그림 번호).
  final void Function(int index) onLocked;

  /// 개발자용: 앞 그림을 안 깨도 모두 연다.
  final bool unlockAll;

  @override
  State<DotStageCarousel> createState() => _DotStageCarouselState();
}

class _DotStageCarouselState extends State<DotStageCarousel> {
  static const double _gap = 12;
  ScrollController? _controller;
  double _itemWidth = 0;
  double _viewport = 0;
  late int _current = currentDotStage(widget.levels, widget.stats);

  /// 카드 [index]가 가운데에 오는 스크롤 위치.
  double _offsetFor(int index) {
    final centered = index * (_itemWidth + _gap) - (_viewport - _itemWidth) / 2;
    final max = widget.levels.length * (_itemWidth + _gap) - _gap - _viewport;
    return centered.clamp(0.0, max < 0 ? 0.0 : max);
  }

  @override
  void didUpdateWidget(DotStageCarousel old) {
    super.didUpdateWidget(old);
    final now = currentDotStage(widget.levels, widget.stats);
    if (now != _current) {
      // 방금 깬 그림 다음 그림이 열렸다: 그쪽으로 부드럽게 옮겨 준다
      _current = now;
      final c = _controller;
      if (c != null && c.hasClients) {
        c.animateTo(_offsetFor(now), duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  bool _isLocked(int i) => !widget.unlockAll && i > 0 && !(widget.stats[widget.levels[i - 1].id]?.cleared ?? false);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth * 0.5).clamp(160.0, 230.0);
        if (_controller == null || width != _itemWidth || box.maxWidth != _viewport) {
          _itemWidth = width;
          _viewport = box.maxWidth;
          _controller?.dispose();
          _controller = ScrollController(initialScrollOffset: _offsetFor(_current));
        }
        return SizedBox(
          height: width + 100,
          child: ListView.separated(
            key: const ValueKey('dot-stage-list'),
            controller: _controller,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: widget.levels.length,
            separatorBuilder: (_, _) => const SizedBox(width: _gap),
            itemBuilder: (context, i) {
              final l = widget.levels[i];
              final locked = _isLocked(i);
              return SizedBox(
                width: width,
                child: DotLevelCard(
                  key: ValueKey('dot-card-${l.id}'),
                  level: l,
                  stats: widget.stats[l.id],
                  number: i + 1,
                  locked: locked,
                  highlight: i == _current && !locked,
                  onTap: locked ? () => widget.onLocked(i - 1) : () => widget.onPlay(l),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
