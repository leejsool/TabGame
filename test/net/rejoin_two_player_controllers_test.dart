import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/games/dandelion/core/dandelion_rules.dart';
import 'package:tabgame/games/dandelion/game/dandelion_controller.dart';
import 'package:tabgame/games/goblet/core/goblet_rules.dart';
import 'package:tabgame/games/goblet/game/goblet_controller.dart';
import 'package:tabgame/games/prophecy/game/prophecy_controller.dart';
import 'package:tabgame/games/sprouts/game/sprouts_controller.dart';
import 'package:tabgame/games/uttt/core/uttt_rules.dart';
import 'package:tabgame/games/uttt/game/uttt_controller.dart';

Future<void> until(bool Function() done, {int ms = 10000}) async {
  for (var waited = 0; waited < ms && !done(); waited += 20) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

// (콩나물은 이 기능이 extension 안에 있어서, dynamic 으로는 부를 수 없다 — 형을 정해서 부른다)
void start(dynamic c) => c is SproutsController ? c.start() : c.start();
void cover(dynamic c) => c is SproutsController ? c.coverOpponent() : c.coverOpponent();
void uncover(dynamic c) => c is SproutsController ? c.uncoverOpponent() : c.uncoverOpponent();
Map<String, dynamic> snapshotOf(dynamic c) => c is SproutsController ? c.wifiSnapshot() : c.wifiSnapshot() as Map<String, dynamic>;

/// 게임마다 달라지는 것만 모아 둔다. 방장은 "나중에 두는 쪽"이라서, 나간 상대(먼저 두는 쪽) 차례에서 시작한다.
class _G {
  const _G({
    required this.name,
    required this.make,
    required this.restore,
    required this.sameAs,
  });

  final String name;

  /// 방장 쪽 컨트롤러 (상대 차례에서 시작).
  final dynamic Function() make;

  /// 돌아온 상대 쪽 컨트롤러를 판의 모습에서 만든다.
  final dynamic Function(Map<String, dynamic> snap) restore;

  /// 두 컨트롤러의 판이 같은가.
  final void Function(dynamic host, dynamic back) sameAs;
}

final games = <_G>[
  _G(
    name: '궁극 틱택토',
    make: () => UtttController(mode: PlayMode.wifi, humanSide: kO),
    restore: (s) => UtttController.fromWifiSnapshot(s),
    sameAs: (h, b) {
      expect(b.moves, h.moves);
      expect(b.humanSide, 1 - h.humanSide);
      expect(b.state.turn, h.state.turn);
    },
  ),
  _G(
    name: '민들레',
    make: () => DandelionController(mode: PlayMode.wifi, humanRole: Role.wind),
    restore: (s) => DandelionController.fromWifiSnapshot(s),
    sameAs: (h, b) {
      expect(b.moves, h.moves);
      expect(b.humanRole, h.humanRole.other);
      expect(b.state.turn, h.state.turn);
    },
  ),
  _G(
    name: '예언',
    make: () => ProphecyController(mode: PlayMode.wifi, humanSide: 1),
    restore: (s) => ProphecyController.fromWifiSnapshot(s),
    sameAs: (h, b) {
      expect(b.moves, h.moves);
      expect(b.humanSide, 1 - h.humanSide);
      expect(b.state.turn, h.state.turn);
    },
  ),
  _G(
    name: '고블렛 고블러스',
    make: () => GobbletController(mode: PlayMode.wifi, humanTeam: Team.blue, startingTeam: Team.red),
    restore: (s) => GobbletController.fromWifiSnapshot(s),
    sameAs: (h, b) {
      expect(b.board.owners, h.board.owners);
      expect(b.humanTeam, h.humanTeam.other);
      expect(b.turn, h.turn);
      expect(b.moveCount, h.moveCount);
    },
  ),
  _G(
    name: '콩나물',
    make: () => SproutsController(mode: PlayMode.wifi, dotCount: 3, humanSide: 1),
    restore: (s) => ScRejoin.fromWifiSnapshot(s),
    sameAs: (h, b) {
      expect(b.moveCount, h.moveCount);
      expect(b.turn, h.turn);
      expect(b.humanSide, 1 - h.humanSide);
      expect(b.board.dots.length, h.board.dots.length);
      expect(b.board.curves.length, h.board.curves.length);
    },
  ),
];

void main() {
  for (final g in games) {
    group(g.name, () {
      test('나간 상대 자리를 CPU가 맡으면 방장 기기에서 CPU가 두고, 돌아온 상대는 같은 판을 받아 이어 둔다', () async {
        final host = g.make();
        expect(host.online, isTrue);
        start(host);
        expect(host.thinking, isFalse, reason: 'CPU 자리가 아니면 CPU가 두지 않아요');
        expect(host.moveCount, 0);

        cover(host); // 상대(먼저 두는 쪽)가 나갔고, 방장이 CPU에게 맡겼다
        expect(host.cpuCover, isTrue);
        await until(() => host.moveCount >= 1 && !host.thinking);
        expect(host.moveCount, greaterThanOrEqualTo(1), reason: 'CPU가 상대 자리의 수를 두지 않았어요');

        uncover(host); // 상대가 돌아왔다
        expect(host.cpuCover, isFalse);
        final snap = snapshotOf(host);
        final back = g.restore(snap);
        expect(back, isNotNull, reason: '받은 판의 모습으로 판을 되살리지 못했어요');
        expect(back.online, isTrue);
        g.sameAs(host, back);
        back.dispose();
        host.dispose();
      });

      test('CPU가 수를 고르는 중에 상대가 돌아오면 그 수는 버려진다', () async {
        final host = g.make();
        start(host);
        cover(host);
        expect(host.thinking, isTrue);
        uncover(host);
        await Future<void>.delayed(const Duration(milliseconds: 2500));
        expect(host.moveCount, 0, reason: '돌아온 뒤에 CPU가 그 자리의 수를 두면 안 돼요');
        host.dispose();
      });

      test('맞지 않는 판의 모습은 받지 않는다', () {
        final host = g.make();
        final snap = snapshotOf(host);
        expect(g.restore({...snap, 'moves': [999999], 'history': [], 'level': 99}), isNull);
        host.dispose();
      });
    });
  }
}
