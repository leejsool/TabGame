import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/games/rummikub/core/rummikub_ai.dart';
import 'package:tabgame/games/rummikub/game/rummikub_controller.dart';

Future<void> until(bool Function() done, {int ms = 10000}) async {
  for (var waited = 0; waited < ms && !done(); waited += 20) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

RummikubController host3({bool animate = true}) =>
    RummikubController(animate: animate, mode: PlayMode.wifi, players: 3, humanSeat: 0, seed: 17, cpuHost: true, level: RkLevel.easy)
      ..stepDelay = const Duration(milliseconds: 4);

void main() {
  test('나간 손님의 자리를 CPU가 맡으면 방장 기기에서 CPU가 두고, 그 수는 다른 기기들에도 알려진다', () async {
    final host = host3();
    final sent = <Map<String, dynamic>>[];
    host.onLocalMove = sent.add;
    host.draw(); // 방장(0번)이 한 차례 (타일을 뽑는다)
    expect(host.turn, 1);
    host.coverSeat(1);
    expect(host.cpuSeats, {1});
    expect(host.runsCpu, isTrue);
    await until(() => host.moveCount >= 2 && !host.animating && !host.thinking);
    expect(host.moveCount, 2);
    expect(host.turn, 2, reason: 'CPU가 1번 자리의 차례를 마쳤어야 해요');
    expect(sent.length, 2, reason: '방장 자신의 수와 CPU의 수가 모두 알려져야 해요');
    host.dispose();
  });

  test('돌아온 손님은 판 상태를 통째로 받아 같은 판에서 이어 둔다 (CPU 자리였어도, 자기 패를 그대로)', () async {
    final host = host3();
    host.draw();
    host.coverSeat(1);
    await until(() => host.moveCount >= 2 && !host.animating && !host.thinking);
    host.uncoverSeat(1); // 1번 손님이 돌아왔다
    expect(host.cpuSeats, isEmpty);

    final snap = host.wifiSnapshot();
    final back = RummikubControllerRejoin.fromWifiSnapshot(snap, humanSeat: 1, animate: false);
    expect(back, isNotNull);
    expect(back!.online, isTrue);
    expect(back.humanSeat, 1);
    expect(back.moveCount, host.moveCount);
    expect(back.turn, host.turn);
    expect(back.state.table, host.state.table);
    for (var p = 0; p < 3; p++) {
      expect(back.state.racks[p].toSet(), host.state.racks[p].toSet());
    }
    expect(back.hand.toSet(), host.state.racks[1].toSet(), reason: '돌아온 사람의 손에 자기 타일이 있어야 해요');
    expect(back.cpuSeats, isEmpty);

    // 다음은 2번 손님 차례
    expect(back.turn, 2);
    back.dispose();
    host.dispose();
  });

  test('상대의 수를 한 장씩 보여 주는 중에 판의 모습을 만들어도 그 수가 빠지지 않는다', () async {
    final host = host3();
    host.stepDelay = const Duration(milliseconds: 300);
    host.draw(); // 0번
    final g1 = RummikubController(animate: false, mode: PlayMode.wifi, players: 3, humanSeat: 1, seed: 17);
    g1.receiveMove({'i': 0, 'draw': 1});
    Map<String, dynamic>? msg;
    g1.onLocalMove = (m) => msg = m;
    g1.draw(); // 1번 손님이 뽑는다
    expect(msg, isNotNull);
    expect(host.receiveMove({'t': 'move', ...msg!}, fromSeat: 1), isTrue);
    expect(host.animating, isTrue, reason: '아직 보여 주는 중이어야 이 시험이 뜻이 있어요');
    expect(host.moveCount, 1); // 판에는 아직 반영 전

    final snap = host.wifiSnapshot();
    expect((snap['pending'] as List).length, 1);
    final back = RummikubControllerRejoin.fromWifiSnapshot(snap, humanSeat: 1, animate: false);
    expect(back, isNotNull);
    expect(back!.moveCount, 2, reason: '보여 주던 수까지 반영돼야 해요 (내 자리의 수일 수도 있어요)');
    expect(back.turn, 2);

    await until(() => !host.animating);
    expect(host.moveCount, 2);
    expect(back.state.racks[1].toSet(), host.state.racks[1].toSet());
    expect(back.state.pool.length, host.state.pool.length);
    expect(back.hand.toSet(), host.state.racks[1].toSet());
    back.dispose();
    g1.dispose();
    host.dispose();
  });

  test('손님 쪽은 자리를 CPU로 바꿔 알고만 있고, 맞지 않는 판의 모습은 받지 않는다', () {
    final guest = RummikubController(animate: false, mode: PlayMode.wifi, players: 3, humanSeat: 2, seed: 17);
    guest.coverSeat(1);
    expect(guest.cpuSeats, {1});
    expect(guest.runsCpu, isFalse);
    guest.coverSeat(2);
    expect(guest.cpuSeats, {1});
    guest.uncoverSeat(1);
    expect(guest.cpuSeats, isEmpty);
    final snap = guest.wifiSnapshot();
    expect(RummikubControllerRejoin.fromWifiSnapshot({...snap, 'players': 9}, humanSeat: 0), isNull);
    expect(RummikubControllerRejoin.fromWifiSnapshot(snap, humanSeat: 5), isNull);
    expect(
      RummikubControllerRejoin.fromWifiSnapshot({
        ...snap,
        'pending': [
          {'i': 5, 'draw': 1},
        ],
      }, humanSeat: 0),
      isNull,
      reason: '순서가 맞지 않는 수는 받지 않아요',
    );
    guest.dispose();
  });
}
