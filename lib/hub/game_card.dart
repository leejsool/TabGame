import 'package:flutter/material.dart';

import '../core/game_info.dart';
import 'game_icons.dart';

/// 허브에 나오는 게임 카드. 누르면 살짝 눌리는 애니메이션이 있다.
class GameCard extends StatefulWidget {
  const GameCard({super.key, required this.game, required this.onTap, this.compact = false});

  final GameInfo game;
  final VoidCallback onTap;

  /// 좁은 폰 화면에서 한 줄에 두 장씩 놓을 때의 작은 카드.
  final bool compact;

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final hsl = HSLColor.fromColor(game.color);
    final dark = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [game.color, dark],
          ),
          boxShadow: [
            BoxShadow(
              color: game.color.withValues(alpha: _pressed ? 0.15 : 0.35),
              blurRadius: _pressed ? 6 : 16,
              offset: Offset(0, _pressed ? 2 : 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: widget.onTap,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            child: Padding(
              padding: EdgeInsets.all(widget.compact ? 12 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.all(widget.compact ? 6 : 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: GameIcon(game: game, size: widget.compact ? 40 : 50),
                      ),
                      if (!game.isReady)
                        const _SoonBadge()
                      else if (game.hasLesson)
                        _LessonBadge(compact: widget.compact),
                    ],
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      game.title,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.compact ? 18 : 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(height: widget.compact ? 2 : 4),
                  Text(
                    game.tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: widget.compact ? 12 : 14,
                      height: widget.compact ? 1.25 : null,
                    ),
                  ),
                  SizedBox(height: widget.compact ? 8 : 12),
                  // 모드가 셋이어도 한 줄로 두고, 모자라면 칩을 조금 줄인다 (두 줄이 되어 카드 높이를 넘지 않게).
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < game.modes.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          _ModeChip(mode: game.modes[i]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 교과학습이 있는 게임 카드의 학사모 표시.
class _LessonBadge extends StatelessWidget {
  const _LessonBadge({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '교과학습이 있어요',
      child: Semantics(
        label: '교과학습이 있어요',
        child: Container(
          padding: EdgeInsets.all(compact ? 6 : 8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
          child: Icon(Icons.school_rounded, size: compact ? 18 : 22, color: Colors.black.withValues(alpha: 0.72)),
        ),
      ),
    );
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        '준비 중',
        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode});

  final PlayMode mode;

  String get _short => switch (mode) {
        PlayMode.solo => '혼자',
        PlayMode.local2p => '2인',
        PlayMode.vsCpu => 'CPU',
        PlayMode.wifi => 'Wi‑Fi',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mode.icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(_short, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
