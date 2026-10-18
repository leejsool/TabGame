import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/games/quoridor/core/quoridor_ai.dart';
import 'package:tabgame/games/quoridor/game/quoridor_controller.dart';

Future<void> until(bool Function() done, {int ms = 8000}) async {
  for (var waited = 0; waited < ms && !done(); waited += 40) {
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }
}

QuoridorController host4() => QuoridorController(mode: PlayMode.wifi, players: 4, humanSeat: 0, cpuHost: true, level: QLevel.easy);

void main() {
  test('나간 손님의 자리를 CPU가 맡으면 방장 기기에서 CPU가 두고, 그 수는 다른 기기들에도 알려진다', () async {
    final host = host4();
    final sent = <int>[];
    host.onLocalMove = sent.add;
    host.start();
    expect(host.tapCell(host.targets.first), isTrue); // 방장(0번)이 한 수
    expect(host.turn, 1);
    expect(host.runsCpu, isFalse, reason: 'CPU 자리가 없으면 방장도 CPU를 돌리지 않아요');

    host.coverSeat(1);
    expect(host.cpuSeats, {1});
    expect(host.runsCpu, isTrue);
    await until(() => host.turn != 1);
    expect(host.turn, 2, reason: 'CPU가 1번 자리의 수를 두었어야 해요');
    expect(sent.length, 2, reason: '방장 자신의 수와 CPU의 수가 모두 알려져야 해요');
    expect(host.moves.length, 2);
    host.dispose();
  });

  test('돌아온 손님은 판의 모습을 받아 같은 판에서 이어 둔다 (CPU 자리였어도)', () async {
    final host = host4();
    host.start();
    host.tapCell(host.targets.first);
    host.coverSeat(1);
    await until(() => host.turn != 1);
    host.uncoverSeat(1); // 1번 손님이 돌아왔다
    expect(host.cpuSeats, isEmpty);

    final snap = host.wifiSnapshot();
    final back = QuoridorControllerRejoin.fromWifiSnapshot(snap, humanSeat: 1);
    expect(back, isNotNull);
    expect(back!.online, isTrue);
    expect(back.humanSeat, 1);
    expect(back.moves, host.moves);
    expect(back.turn, host.turn);
    expect(back.state.pawn, host.state.pawn);
    expect(back.state.wallsLeft, host.state.wallsLeft);
    expect(back.cpuSeats, isEmpty);

    // 돌아온 쪽도 같은 규칙으로 이어서 받는다 (다음은 2번 손님 차례)
    final next = host.state.legalPawnMoves().first;
    expect(back.turn, 2);
    expect(back.receiveMove(next, index: back.moveCount), isTrue);
    back.dispose();
    host.dispose();
  });

  test('CPU가 생각하는 도중에 손님이 돌아오면 그 수는 버려지고 손님이 둔다', () async {
    final host = host4();
    host.start();
    host.tapCell(host.targets.first);
    host.coverSeat(1);
    expect(host.thinking, isTrue);
    host.uncoverSeat(1);
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    expect(host.moves.length, 1, reason: '돌아온 뒤에 CPU가 그 자리의 수를 두면 안 돼요');
    expect(host.turn, 1);
    host.dispose();
  });

  test('손님 쪽(방장이 아닌 기기)은 자리를 CPU로 바꿔 알고만 있고 직접 두지는 않는다', () async {
    final guest = QuoridorController(mode: PlayMode.wifi, players: 4, humanSeat: 2, level: QLevel.easy);
    guest.coverSeat(1);
    expect(guest.cpuSeats, {1});
    expect(guest.runsCpu, isFalse);
    guest.coverSeat(2); // 내 자리는 맡기지 않는다
    expect(guest.cpuSeats, {1});
    guest.uncoverSeat(1);
    expect(guest.cpuSeats, isEmpty);
    guest.dispose();
  });

  test('맞지 않는 판의 모습은 받지 않는다', () {
    expect(QuoridorControllerRejoin.fromWifiSnapshot({'players': 3}, humanSeat: 0), isNull);
    final c = host4();
    final snap = c.wifiSnapshot();
    expect(QuoridorControllerRejoin.fromWifiSnapshot(snap, humanSeat: 7), isNull);
    expect(QuoridorControllerRejoin.fromWifiSnapshot({...snap, 'moves': [999]}, humanSeat: 1), isNull);
    c.dispose();
  });
}
