import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_info.dart';
import '../core/settings.dart';
import 'game_card.dart';

/// 끌려가는 카드가 무엇인지 (어느 묶음의 어느 게임인지).
class _HubDrag {
  const _HubDrag(this.section, this.id);
  final String section;
  final String id;
}

/// 허브의 게임 카드 묶음 한 칸 (즐겨찾기 / 혼자 놀기 / 함께 놀기 …).
///
/// 카드를 꾹 눌렀다가 끌면 카드가 살짝 떠서 손가락을 따라오고, 다른 카드 위로 가져가면 그 자리로 끼어들어 순서가 바뀐다
/// (같은 묶음 안에서만). 별표를 누르면 즐겨찾기에 넣거나 뺀다.
class HubGameGrid extends StatefulWidget {
  const HubGameGrid({
    super.key,
    required this.section,
    required this.games,
    required this.settings,
    required this.compact,
    required this.onOpen,
    required this.onMove,
    this.scroll,
  });

  /// 묶음 이름표 (다른 묶음의 카드는 받지 않는다).
  final String section;
  final List<GameInfo> games;
  final Settings settings;

  /// 좁은 폰 화면 (한 줄에 세 장).
  final bool compact;
  final void Function(GameInfo game) onOpen;

  /// 끌어 온 게임 [id]를 [targetId] 카드가 있던 자리로 옮긴다.
  final void Function(String id, String targetId) onMove;

  /// 허브 화면의 스크롤 (끌다가 화면 위·아래 끝에 가면 저절로 넘긴다).
  final ScrollController? scroll;

  /// 카드 한 장의 높이 (폰 / 태블릿).
  static const double compactExtent = 110, wideExtent = 140;

  @override
  State<HubGameGrid> createState() => _HubGameGridState();
}

class _HubGameGridState extends State<HubGameGrid> {
  Timer? _autoScroll;
  double _scrollSpeed = 0;

  @override
  void dispose() {
    _autoScroll?.cancel();
    super.dispose();
  }

  void _dragStarted() {
    HapticFeedback.mediumImpact();
    _scrollSpeed = 0;
    _autoScroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final s = widget.scroll;
      if (_scrollSpeed == 0 || s == null || !s.hasClients) return;
      final p = s.position;
      s.jumpTo((p.pixels + _scrollSpeed).clamp(p.minScrollExtent, p.maxScrollExtent));
    });
  }

  /// 손가락이 화면 위·아래 끝 가까이 가면 그쪽으로 천천히 넘긴다.
  void _dragMoved(DragUpdateDetails d) {
    final h = MediaQuery.sizeOf(context).height;
    final y = d.globalPosition.dy;
    const edge = 90.0;
    _scrollSpeed = y < edge ? -((edge - y) / edge).clamp(0.0, 1.0) * 14 : (y > h - edge ? ((y - (h - edge)) / edge).clamp(0.0, 1.0) * 14 : 0);
  }

  void _dragEnded() {
    _autoScroll?.cancel();
    _autoScroll = null;
    _scrollSpeed = 0;
  }

  Widget _item(GameInfo g) {
    final s = widget.settings;
    Widget card({bool lifted = false}) => GameCard(
          game: g,
          compact: widget.compact,
          dense: widget.compact,
          favorite: s.isFavorite(g.id),
          onFavorite: () => s.toggleFavorite(g.id),
          lifted: lifted,
          onTap: () => widget.onOpen(g),
        );
    return LayoutBuilder(
      key: ValueKey('hub-${widget.section}-${g.id}'),
      builder: (context, box) => DragTarget<_HubDrag>(
        // 끌려온 카드가 이 카드 위에 들어오면 바로 자리를 바꿔 보여 준다 (손을 떼면 그대로 정해진다)
        onWillAcceptWithDetails: (d) {
          if (d.data.section != widget.section) return false;
          if (d.data.id != g.id) widget.onMove(d.data.id, g.id);
          return true;
        },
        builder: (context, _, _) => LongPressDraggable<_HubDrag>(
          data: _HubDrag(widget.section, g.id),
          delay: const Duration(milliseconds: 350),
          hapticFeedbackOnStart: false,
          onDragStarted: _dragStarted,
          onDragUpdate: _dragMoved,
          onDragEnd: (_) => _dragEnded(),
          // 공중에 뜬 모습: 조금 커지고 살짝 기울고 그림자가 깊어진다
          feedback: SizedBox(
            width: box.maxWidth,
            height: box.maxHeight,
            child: Transform.rotate(angle: -0.03, child: Transform.scale(scale: 1.07, child: IgnorePointer(child: card(lifted: true)))),
          ),
          // 떠난 자리는 흐리게 남겨서 놓일 곳을 보여 준다
          childWhenDragging: Opacity(opacity: 0.28, child: IgnorePointer(child: card())),
          child: card(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final games = widget.games;
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 12 : 24),
      sliver: SliverGrid.builder(
        // 폰처럼 좁은 화면에서는 한 줄에 세 장, 넓으면 폭에 맞춰 여러 장
        gridDelegate: widget.compact
            ? const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, mainAxisExtent: HubGameGrid.compactExtent)
            : const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 210, mainAxisSpacing: 14, crossAxisSpacing: 14, mainAxisExtent: HubGameGrid.wideExtent),
        itemCount: games.length,
        // (순서가 바뀌어도 카드가 새로 만들어지지 않게 — 끌던 손을 놓치지 않는다)
        findChildIndexCallback: (key) {
          final i = games.indexWhere((g) => key == ValueKey('hub-${widget.section}-${g.id}'));
          return i < 0 ? null : i;
        },
        itemBuilder: (context, i) => _item(games[i]),
      ),
    );
  }
}
