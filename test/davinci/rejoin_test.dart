import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/games/davinci/core/davinci_ai.dart';
import 'package:tabgame/games/davinci/game/davinci_controller.dart';

Future<void> until(bool Function() done, {int ms = 8000}) async {
  for (var waited = 0; waited < ms && !done(); waited += 20) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  test('방장 기기에서 나간 자리를 CPU가 맡으면 그 자리의 수를 두고, 사람 차례가 되면 멈춘다', () async {
    // 3명: 0번은 나간 손님, 1번이 이 방장, 2번은 다른 손님
    final host = DavinciController(mode: PlayMode.wifi, players: 3, humanSeat: 1, seed: 9, animate: false, cpuHost: true, level: DvLevel.easy)
      ..cpuStepDelay = const Duration(milliseconds: 5);
    final sent = <List<int>>[];
    host.onLocalMove = sent.add;
    expect(host.turn, 0);
    host.coverSeat(0);
    expect(host.cpuSeats, {0});
    await until(() => host.turn != 0);
    expect(host.turn, isNot(0), reason: 'CPU가 0번 자리의 차례를 두었어야 해요');
    expect(sent, isNotEmpty);
    expect(host.moves.length, sent.length);
    host.dispose();
  });

  test('돌아온 손님은 씨앗과 둔 수로 같은 판을 되살리고, 이어지는 수를 받는다', () {
    final rng = Random(3);
    final host = DavinciController(mode: PlayMode.wifi, players: 3, humanSeat: 2, seed: 21, animate: false);
    // 0번과 1번의 수를 AI가 정해 둔다 (이 기기는 2번이라 남의 수로 받는다)
    for (var i = 0; i < 9 && host.turn != 2; i++) {
      final move = DvAi.choose(host.state, DvLevel.normal, rng);
      expect(host.receiveMove(move), isTrue);
    }
    expect(host.moves, isNotEmpty);

    final snap = host.wifiSnapshot();
    final back = DavinciControllerRejoin.fromWifiSnapshot(snap, humanSeat: 2, animate: false);
    expect(back, isNotNull);
    expect(back!.online, isTrue);
    expect(back.moves, host.moves);
    expect(back.turn, host.turn);
    expect(back.state.rows, host.state.rows);
    expect(back.state.phase, host.state.phase);
    expect(back.drawnBy, host.drawnBy);

    // 둘 다 같은 다음 수를 받아도 같은 판이 된다
    if (host.turn != 2) {
      final move = DvAi.choose(host.state, DvLevel.normal, rng);
      expect(host.receiveMove(move, index: host.moveCount), isTrue);
      expect(back.receiveMove(move, index: back.moveCount), isTrue);
      expect(back.state.rows, host.state.rows);
    }
    back.dispose();
    host.dispose();
  });

  test('연출을 기다리며 줄 서 있던 수도 판의 모습에 담긴다', () {
    final rng = Random(5);
    final host = DavinciController(mode: PlayMode.wifi, players: 3, humanSeat: 2, seed: 4, animate: true);
    host.cpuStepDelay = const Duration(milliseconds: 400);
    final first = DvAi.choose(host.state, DvLevel.normal, rng);
    expect(host.receiveMove(first), isTrue); // 연출이 시작된다
    var queued = 0;
    for (var i = 0; i < 4 && host.turn != 2; i++) {
      final move = DvAi.choose(host.state, DvLevel.normal, rng);
      // (줄 서 있는 수까지 둔 모습으로 확인해야 하니 컨트롤러의 확인을 거친다)
      if (!host.receiveMove(move, index: host.moveCount + queued + 0)) break;
      queued++;
    }
    final snap = host.wifiSnapshot();
    final all = snap['moves'] as List;
    expect(all.length, host.moveCount + queued, reason: '줄 서 있는 수가 판의 모습에서 빠졌어요');
    final back = DavinciControllerRejoin.fromWifiSnapshot(snap, humanSeat: 2, animate: false);
    expect(back, isNotNull);
    expect(back!.moveCount, all.length);
    back.dispose();
    host.dispose();
  });

  test('손님 쪽은 자리를 CPU로 바꿔 알고만 있고, 맞지 않는 판의 모습은 받지 않는다', () {
    final guest = DavinciController(mode: PlayMode.wifi, players: 3, humanSeat: 2, seed: 1, animate: false);
    guest.coverSeat(0);
    expect(guest.cpuSeats, {0});
    expect(guest.runsCpu, isFalse);
    guest.coverSeat(2);
    expect(guest.cpuSeats, {0});
    guest.uncoverSeat(0);
    expect(guest.cpuSeats, isEmpty);
    final snap = guest.wifiSnapshot();
    expect(DavinciControllerRejoin.fromWifiSnapshot({...snap, 'players': 9}, humanSeat: 0), isNull);
    expect(DavinciControllerRejoin.fromWifiSnapshot({...snap, 'moves': [[9, 9, 9, 9]]}, humanSeat: 0), isNull);
    guest.dispose();
  });
}
