import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../core/snake_body.dart';
import '../game/snake_controller.dart';
import 'snake_painter.dart';

/// 실시간 순위표: 상위 5마리와 내 순위·점수 (한 줄). 누르면 접혀서 1등과 나만 보인다.
class SnakeLeaderboard extends StatelessWidget {
  const SnakeLeaderboard({super.key, required this.ranked, required this.mySeat, this.width = 190, this.collapsed = false, this.onToggle, this.cpuLevel = 0});

  final List<SnakeBody> ranked;
  final int mySeat;
  final double width;
  final bool collapsed;
  final VoidCallback? onToggle;

  /// CPU 단계 (0이면 안 보인다).
  final int cpuLevel;

  @override
  Widget build(BuildContext context) {
    final myIndex = ranked.indexWhere((s) => s.seat == mySeat);
    final me = myIndex < 0 ? null : ranked[myIndex];
    TextStyle style(bool mine, {double size = 13}) => TextStyle(
          fontFamily: 'NanumGothic',
          fontSize: size,
          fontWeight: mine ? FontWeight.w900 : FontWeight.w700,
          color: mine ? const Color(0xFFFFE04A) : Colors.white,
        );
    Widget row(int rank, SnakeBody s) {
      final mine = s.seat == mySeat;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          children: [
            SizedBox(width: 22, child: Text('$rank', style: style(mine))),
            Container(width: 9, height: 9, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: snakeColors[s.color % snakeColors.length], shape: BoxShape.circle)),
            Expanded(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: style(mine))),
            Text('${s.score}', style: style(mine)),
          ],
        ),
      );
    }

    final shown = collapsed ? 1 : 5;
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.42), borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('순위', style: style(false, size: 12).copyWith(color: Colors.white60))),
                if (cpuLevel > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFFFF5A5F).withValues(alpha: 0.85), borderRadius: BorderRadius.circular(8)),
                    child: Text('CPU $cpuLevel단계', style: style(false, size: 11).copyWith(color: Colors.white)),
                  ),
                Icon(collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded, size: 18, color: Colors.white60),
              ],
            ),
            for (var i = 0; i < min(shown, ranked.length); i++) row(i + 1, ranked[i]),
            const Divider(color: Colors.white24, height: 10),
            if (me != null)
              Text('내 순위 ${myIndex + 1}등/${ranked.length} · ${me.score}점', maxLines: 1, overflow: TextOverflow.ellipsis, style: style(true, size: 13))
            else
              Text('다시 태어나기를 기다려요', style: style(false, size: 12.5).copyWith(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

/// 내 뱀이 죽었을 때 가운데에 뜨는 카드.
class SnakeDeathCard extends StatelessWidget {
  const SnakeDeathCard({super.key, required this.life, required this.onAgain, required this.onLeave});

  final SnakeLife? life;
  final VoidCallback onAgain, onLeave;

  @override
  Widget build(BuildContext context) {
    final l = life;
    final title = l == null ? '다시 해 볼까요?' : (l.killerName.isEmpty ? '벽에 부딪혔어요!' : '${l.killerName}에게 부딪혔어요!');
    return Center(
      child: Container(
        width: 320,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: const Color(0xEE1D2440),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'NanumGothic', fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
            if (l != null) ...[
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 18,
                runSpacing: 8,
                children: [
                  _stat('점수', '${l.score}'),
                  _stat('최고 순위', '${l.bestRank}등'),
                  _stat('잡은 지렁이', '${l.kills}'),
                  _stat('버틴 시간', formatTime(l.seconds)),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onLeave,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontFamily: 'NanumGothic', fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    child: const Text('나가기'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: onAgain,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('다시 하기'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2ED1A2),
                      foregroundColor: const Color(0xFF0B2A22),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontFamily: 'NanumGothic', fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontFamily: 'NanumGothic', fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFFFE04A))),
          Text(label, style: const TextStyle(fontFamily: 'NanumGothic', fontSize: 12, color: Colors.white70)),
        ],
      );
}

/// 조종기(누른 곳이 가운데)와 부스터 표시.
class SnakeTouchPainter extends CustomPainter {
  SnakeTouchPainter({required this.stickOrigin, required this.stickNow, required this.boosting, required this.boostAt});

  final Offset? stickOrigin, stickNow;
  final bool boosting;
  final Offset? boostAt;

  static const double reach = 56;

  @override
  void paint(Canvas canvas, Size size) {
    final o = stickOrigin;
    if (o != null) {
      canvas.drawCircle(o, reach, Paint()..color = Colors.white.withValues(alpha: 0.10));
      canvas.drawCircle(o, reach, Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      var d = (stickNow ?? o) - o;
      if (d.distance > reach) d = d / d.distance * reach;
      canvas.drawCircle(o + d, 24, Paint()..color = Colors.white.withValues(alpha: 0.55));
    }
    final b = boostAt;
    if (boosting && b != null) {
      canvas.drawCircle(b, 46, Paint()..color = const Color(0xFFFFA62B).withValues(alpha: 0.25));
      canvas.drawCircle(b, 46, Paint()
        ..color = const Color(0xFFFFA62B).withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
    }
  }

  @override
  bool shouldRepaint(SnakeTouchPainter old) =>
      old.stickOrigin != stickOrigin || old.stickNow != stickNow || old.boosting != boosting || old.boostAt != boostAt;
}

/// 처음 몇 초 동안 보여 주는 조종 안내.
class SnakeControlHint extends StatelessWidget {
  const SnakeControlHint({super.key, this.swapped = false});

  /// 부스터가 왼쪽인가.
  final bool swapped;

  @override
  Widget build(BuildContext context) {
    Widget side(IconData icon, String text) => Expanded(
          child: Center(
            heightFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 34),
                  const SizedBox(height: 6),
                  Text(text, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'NanumGothic', fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, height: 1.35)),
                ],
              ),
            ),
          ),
        );
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, 0.7),
        child: Row(
          children: [
            side(Icons.open_with_rounded, '왼쪽을 누르고 끌어서\n방향 바꾸기'),
            side(Icons.bolt_rounded, '오른쪽을 꾹 누르면\n부스터 (더 빠르게)'),
          ],
        ),
      ),
    );
  }
}
