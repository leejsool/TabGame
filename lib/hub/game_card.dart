import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/app_fonts.dart';
import '../core/dev_unlock.dart';
import '../core/game_info.dart';
import 'game_icons.dart';

/// 허브에 나오는 게임 카드. 누르면 살짝 눌리는 애니메이션이 있다.
class GameCard extends StatefulWidget {
  const GameCard({super.key, required this.game, required this.onTap, this.compact = false, this.favorite = false, this.onFavorite, this.lifted = false, this.dense = false});

  final GameInfo game;
  final VoidCallback onTap;

  /// 즐겨찾기한 게임인가 (별표가 채워진다).
  final bool favorite;

  /// 별표를 눌렀을 때. null이면 별표를 보이지 않는다.
  final VoidCallback? onFavorite;

  /// 폰에서 한 줄에 세 장씩 놓는 아주 작은 카드 (방식 칩은 글자 없이 그림만).
  final bool dense;

  /// 끌어 옮기는 중에 손가락을 따라다니는 모습인가 (공중에 뜬 것처럼 그림자가 깊어진다).
  final bool lifted;

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
    final showBeta = game.beta && game.isReady && !game.locked;
    final lifted = widget.lifted;
    final dense = widget.dense;

    final card = AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [game.color, dark],
          ),
          boxShadow: [
            BoxShadow(
              color: lifted ? Colors.black.withValues(alpha: 0.35) : game.color.withValues(alpha: _pressed ? 0.15 : 0.3),
              blurRadius: lifted ? 26 : (_pressed ? 5 : 10),
              offset: Offset(0, lifted ? 16 : (_pressed ? 2 : 5)),
            ),
          ],
        ),
        // 글씨 자리(아래쪽)만 살짝 어둡게 깐다 (밝은 카드에서만, [_scrimFor])
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
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
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onTap,
              onTapDown: (_) => _setPressed(true),
              onTapUp: (_) => _setPressed(false),
              onTapCancel: () => _setPressed(false),
              child: Padding(
                padding: dense ? const EdgeInsets.fromLTRB(8, 8, 8, 7) : EdgeInsets.fromLTRB(widget.compact ? 10 : 12, widget.compact ? 10 : 12, widget.compact ? 10 : 12, widget.compact ? 9 : 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(dense ? 4 : 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: GameIcon(game: game, size: dense ? 38 : (widget.compact ? 44 : 50)),
                        ),
                        // (좁은 카드에서는 "준비 중" 표시가 넘치지 않게 조금 줄인다)
                        Expanded(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: (!game.isReady || game.locked)
                                ? const FittedBox(fit: BoxFit.scaleDown, child: _SoonBadge())
                                : (widget.onFavorite != null ? _FavoriteStar(on: widget.favorite, onTap: widget.onFavorite!, title: game.title, size: dense ? 26 : 30) : null),
                          ),
                        ),
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
                          fontSize: dense ? 15 : (widget.compact ? 17 : 19),
                          fontFamily: kTitleFont,
                          fontFamilyFallback: kTitleFontFallback,
                          fontWeight: FontWeight.w800,
                          shadows: _textShadow,
                        ),
                      ),
                    ),
                    // (칩이 없는 카드도 아래 한 줄 자리는 비워 둬서, 게임 이름이 모든 카드에서 같은 높이에 온다)
                    ...[
                      SizedBox(height: dense ? 4 : 5),
                      // 아래 한 줄: 할 수 있는 방식 칩(+ beta), 오른쪽 끝에 교과학습 표시. 모자라면 칩을 조금 줄인다.
                      SizedBox(
                        height: 22,
                        child: Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!soloOnly)
                                      for (final mode in game.modes)
                                        if (!(mode == PlayMode.wifi && kIsWeb))
                                          Padding(padding: const EdgeInsets.only(right: 5), child: _ModeChip(mode: mode, text: dense ? null : game.modeChip(mode))),
                                    if (showBeta) const _SoonBadge(label: 'beta'),
                                  ],
                                ),
                              ),
                            ),
                            if (game.hasLesson) const Padding(padding: EdgeInsets.only(left: 4), child: _LessonBadge()),
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
    return game.isReady && !game.locked ? card : Opacity(opacity: 0.55, child: card);
  }

  @override
  void initState() {
    super.initState();
    if (widget.game.devOnly) DevUnlock.opened.addListener(_onUnlock);
  }

  @override
  void dispose() {
    DevUnlock.opened.removeListener(_onUnlock);
    super.dispose();
  }

  void _onUnlock() => setState(() {});
}

/// 교과학습이 있는 게임 카드의 학사모 표시.
class _LessonBadge extends StatelessWidget {
  const _LessonBadge();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '교과학습이 있어요',
      child: Semantics(
        label: '교과학습이 있어요',
        child: Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
          child: Icon(Icons.school_rounded, size: 15, color: Colors.black.withValues(alpha: 0.72)),
        ),
      ),
    );
  }
}

/// 카드 오른쪽 위의 즐겨찾기 별표: 빈 별을 누르면 채워지고 그 게임이 메인 화면 맨 위로 올라간다.
class _FavoriteStar extends StatelessWidget {
  const _FavoriteStar({required this.on, required this.onTap, required this.title, this.size = 30});

  final double size;

  final bool on;
  final VoidCallback onTap;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: on ? '$title 즐겨찾기 빼기' : '$title 즐겨찾기에 넣기',
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        // (별은 작게 보여도 누르는 자리는 넉넉하게)
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 0, 10),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
            child: Icon(
              on ? Icons.star_rounded : Icons.star_border_rounded,
              key: ValueKey(on),
              size: size,
              color: on ? const Color(0xFFFFD54F) : Colors.white.withValues(alpha: 0.9),
              shadows: const [Shadow(color: Color(0x59000000), blurRadius: 4, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge({this.label = '준비 중'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode, required this.text});

  final PlayMode mode;

  /// 칩의 글자 (null이면 그림만).
  final String? text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: text == null ? 6 : 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mode.icon, size: 14, color: Colors.white),
          if (text != null) ...[
            const SizedBox(width: 4),
            Text(text!, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
