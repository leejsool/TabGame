import 'dart:math';

import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/tutorial.dart';
import '../core/sprouts_board.dart';
import '../core/sprouts_geometry.dart';
import '../core/sprouts_planner.dart';
import '../ui/sprouts_painter.dart';

const Color _sproutsColorAccent = Color(0xFF2E9E5B);

/// 콩나물 게임 방법.
GameTutorial sproutsTutorial() => GameTutorial(
      title: '콩나물',
      color: _sproutsColorAccent,
      steps: [
        TutorialStep(
          title: '점에서 점으로 곡선을 그어요',
          body: '점이 몇 개 놓여 있어요. 내 차례에 손가락으로 점에서 점으로 곡선을 그어요.\n'
              '곡선은 꼬불꼬불해도, 짧아도, 길어도 괜찮아요. 한 점에서 출발해 그 점으로 돌아오는 고리도 돼요.',
          art: (context, accent) => _art(
            board: _before(),
            hint: _arc(_dots[0], _dots[1], 60),
          ),
        ),
        TutorialStep(
          title: '선 위에 새 점이 생겨요',
          body: '곡선을 그으면 그 선 위에 새 점이 저절로 하나 찍혀요. 점과 곡선을 그어 새 점까지 찍는 것이 한 수예요.\n'
              '다음 사람은 새 점까지 포함해서 이어요.',
          art: (context, accent) {
            final b = _after();
            return _art(board: b, highlight: {b.dots.length - 1});
          },
        ),
        TutorialStep(
          title: '점마다 선은 3개까지',
          body: '점 하나에는 선을 3개까지만 이을 수 있어요. 점 안의 숫자는 앞으로 더 이을 수 있는 선의 수예요.\n'
              '선이 3개가 된 점(회색)에는 더 이을 수 없어요. 새 점은 선이 이미 2개 이어진 셈이라 숫자가 1이에요.',
          art: (context, accent) => _art(board: _full()),
        ),
        TutorialStep(
          title: '선은 서로 만나면 안 돼요',
          body: '새로 긋는 선은 다른 선이나 자기 자신과 만날 수 없어요. 다른 점 위를 지나가도 안 돼요.\n'
              '빨간 선처럼 가로지르면 안 되고, 돌아서 가야 해요.',
          art: (context, accent) {
            final b = _crossBoard();
            return _art(board: b, rejected: [for (var i = 0; i <= 40; i++) P(250, 40 + 340 * i / 40)]);
          },
        ),
        TutorialStep(
          title: '마지막에 두는 사람이 이겨요',
          body: '아무도 더 이을 수 없게 되면 게임이 끝나요. 마지막으로 수를 둔 사람이 이겨요!\n'
              '남은 자리를 잘 살피면서, 상대가 더 이을 곳이 없게 만들어 보세요.',
          icon: Icons.emoji_events_rounded,
          art: (context, accent) => _art(board: _ended()),
        ),
      ],
    );

const List<P> _dots = [P(90, 110), P(310, 90), P(120, 330), P(300, 340)];

Widget _art({
  required SproutsBoard board,
  List<P>? hint,
  List<P> rejected = const [],
  Set<int> highlight = const {},
}) {
  return ArtCanvas(
    width: 340,
    height: 391,
    child: CustomPaint(
      painter: SproutsPainter(
        board: board,
        hint: hint,
        rejected: rejected,
        rejectedFade: rejected.isEmpty ? 0 : 1,
        highlightDots: highlight,
        showGrid: true,
      ),
    ),
  );
}

/// [a]에서 [b]로 가는 활 모양 곡선 ([bend]만큼 가운데가 휘어 있다).
List<P> _arc(P a, P b, double bend, {int n = 40}) {
  final mid = P((a.x + b.x) / 2, (a.y + b.y) / 2);
  final d = b - a;
  final len = sqrt(d.x * d.x + d.y * d.y);
  final normal = P(-d.y / len, d.x / len);
  final ctrl = P(mid.x + normal.x * bend * 2, mid.y + normal.y * bend * 2);
  return [
    for (var i = 0; i <= n; i++)
      () {
        final t = i / n;
        final u = 1 - t;
        return P(u * u * a.x + 2 * u * t * ctrl.x + t * t * b.x, u * u * a.y + 2 * u * t * ctrl.y + t * t * b.y);
      }(),
  ];
}

/// 점 [from]→[to] 활 모양 곡선으로 한 수를 둔다 (그림용).
void _play(SproutsBoard b, int from, int to, double bend, int owner) {
  final path = _arc(b.dots[from].pos, b.dots[to].pos, bend);
  final r = b.validate(from, to, path.sublist(1, path.length - 1));
  assert(r.ok, r.reason);
  if (r.ok) b.apply(from, to, r, owner);
}

SproutsBoard _before() => SproutsBoard([for (final p in _dots.take(3)) Dot(p, 3)], []);

SproutsBoard _after() {
  final b = _before();
  _play(b, 0, 1, 60, 0);
  return b;
}

/// 점 0에 선이 3개: 숫자가 0이 되어 회색이다.
SproutsBoard _full() {
  final b = SproutsBoard([
    Dot(const P(60, 200), 3),
    Dot(const P(220, 50), 3),
    Dot(const P(340, 200), 3),
    Dot(const P(220, 350), 3),
  ], []);
  _play(b, 0, 1, 0, 0);
  _play(b, 0, 2, 0, 1);
  _play(b, 0, 3, 0, 0);
  return b;
}

/// 가운데를 지나는 선이 하나 있는 판 (가로지르면 안 된다는 그림용).
SproutsBoard _crossBoard() {
  final b = SproutsBoard([
    Dot(const P(70, 200), 3),
    Dot(const P(330, 200), 3),
    Dot(const P(250, 40), 3),
    Dot(const P(250, 380), 3),
  ], []);
  _play(b, 0, 1, 25, 0);
  return b;
}

/// 점 2개로 시작해서 끝까지 둔, 더 이을 곳이 없는 판 (그림용, 항상 같은 모양).
SproutsBoard _ended() {
  final rng = Random(4);
  final b = SproutsBoard.initial(2, rng);
  var turn = 0;
  while (true) {
    final ms = findMoves(b);
    if (ms.isEmpty) break;
    b.apply(ms.first.s, ms.first.e, ms.first.result, turn);
    turn = 1 - turn;
  }
  return b;
}
