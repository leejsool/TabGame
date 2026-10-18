import 'package:flutter/foundation.dart' show kIsWeb;
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

  /// 흰 글씨가 잘 읽히도록 카드 아래쪽(글씨 자리)에 깔 어둠의 진하기 (0~0.6).
  /// 어두운 카드는 0이라 그대로이고, 노랑·주황처럼 밝은 카드만 필요한 만큼 아래쪽이 어두워진다.
  /// 설명 글씨 자리에서 대비 4.5:1, 큰 제목 자리에서 3:1 이상이 되는 가장 옅은 값.
  static double _scrimFor(Color base, Color dark) {
    double contrastAt(double t, double y, double a) {
      final g = Color.lerp(base, dark, t)!;
      final bg = Color.lerp(g, Colors.black, ((y - 0.35) / 0.65).clamp(0.0, 1.0) * a)!;
      return 1.05 / (bg.computeLuminance() + 0.05);
    }

    for (var a = 0.0; a < 0.6; a += 0.05) {
      if (contrastAt(0.41, 0.72, a) >= 4.5 && contrastAt(0.35, 0.6, a) >= 3) return a;
    }
    return 0.6;
  }

  static const List<Shadow> _textShadow = [Shadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))];

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final hsl = HSLColor.fromColor(game.color);
    final dark = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    final scrim = _scrimFor(game.color, dark);
    // 혼자 놀기 카드는 이미 "혼자 놀기" 묶음 안에 있으니 "혼자" 칩을 따로 달지 않는다
    final soloOnly = game.modes.length == 1 && game.modes.first == PlayMode.solo;

    final card = AnimatedScale(
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
        // 글씨 자리(아래쪽)만 살짝 어둡게 깐다 (밝은 카드에서만, [_scrimFor])
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: scrim == 0
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.35, 1],
                    colors: [Colors.black.withValues(alpha: 0), Colors.black.withValues(alpha: scrim)],
                  ),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(widget.compact ? 6 : 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: GameIcon(game: game, size: widget.compact ? 48 : 54),
                        ),
                        // (Wi‑Fi는 아래 모드 칩에 이미 있어서 위에는 교과학습 표시만 단다)
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
                          shadows: _textShadow,
                        ),
                      ),
                    ),
                    SizedBox(height: widget.compact ? 2 : 4),
                    Text(
                      game.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: widget.compact ? 12.5 : 14,
                        height: widget.compact ? 1.25 : null,
                        shadows: _textShadow,
                      ),
                    ),
                    if (!soloOnly) ...[
                      SizedBox(height: widget.compact ? 8 : 12),
                      // 모드가 셋이어도 한 줄로 두고, 모자라면 칩을 조금 줄인다 (두 줄이 되어 카드 높이를 넘지 않게).
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final mode in game.modes)
                              if (!(mode == PlayMode.wifi && kIsWeb)) ...[
                                if (mode != game.modes.first) const SizedBox(width: 6),
                                _ModeChip(mode: mode),
                              ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // 준비 중인 게임은 흐리게 보여서 아직 할 수 없다는 걸 알린다
    return game.isReady ? card : Opacity(opacity: 0.55, child: card);
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
