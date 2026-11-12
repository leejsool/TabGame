import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/games/yacht/core/yacht_advisor.dart';
import 'package:tabgame/games/yacht/core/yacht_cpu.dart';
import 'package:tabgame/games/yacht/core/yacht_daesung.dart';
import 'package:tabgame/games/yacht/core/yacht_daesung_advisor.dart';
import 'package:tabgame/games/yacht/core/yacht_daesung_values.dart';
import 'package:tabgame/games/yacht/core/yacht_rules.dart';
import 'package:tabgame/games/yacht/core/yacht_values.dart';
import 'package:tabgame/games/yacht/game/yacht_controller.dart';

final advisor = YachtAdvisor(YachtValues.fromBytes(File('assets/yacht/values.bin').readAsBytesSync()));

Future<void> until(bool Function() done, {int ms = 15000}) async {
  for (var waited = 0; waited < ms && !done(); waited += 40) {
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }
}

YachtController seat(int me, {int players = 2, bool host = false, int first = 0, int seed = 1}) => YachtController(
      mode: PlayMode.wifi,
      players: players,
      humanSeat: me,
      cpuHost: host,
      first: first,
      level: YachtLevel.easy,
      advisor: advisor,
      rng: Random(seed),
    );

void main() {
  test('굴리고 · 잡고 · 적은 것이 상대 기기에 그대로 전해진다', () async {
    final a = seat(0, host: true), b = seat(1);
    a.onLocalAction = (m) => expect(b.receive(m), isTrue, reason: '$m');
    b.onLocalAction = (m) => expect(a.receive(m), isTrue, reason: '$m');
    expect(a.humanTurn, isTrue);
    expect(b.humanTurn, isFalse, reason: '상대 차례에는 누를 수 없어요');

    a.roll();
    expect(b.rolling, isTrue, reason: '상대 화면에서도 주사위가 굴러요');
    await until(() => !a.rolling && !b.rolling);
    expect(b.game.dice, a.game.dice);
    expect(b.game.rollsUsed, 1);

    a.toggleHold(2);
    expect(b.game.held, a.game.held);
    b.toggleHold(0); // 내 차례가 아니면 아무 일도 없다
    expect(a.game.held[0], isFalse);

    a.roll();
    await until(() => !a.rolling && !b.rolling);
    expect(b.game.dice, a.game.dice);
    expect(b.game.dice[2], a.game.dice[2]);

    a.choose(YachtCategory.choice);
    a.confirm();
    expect(a.game.turn, 1);
    expect(b.game.turn, 1);
    expect(b.game.cards[0].total, a.game.cards[0].total);
    expect(b.lastCategory, YachtCategory.choice);
    expect(b.humanTurn, isTrue);

    // 이제 손님 차례: 방장 기기가 받는다
    b.roll();
    await until(() => !a.rolling && !b.rolling);
    expect(a.game.dice, b.game.dice);
    expect(a.actions, b.actions);
    a.dispose();
    b.dispose();
  });

  test('대성One Rule 방: 두 기기 모두 대성One 판이고, 적은 점수가 만능 규칙대로 같다', () async {
    final dsAdvisor = YachtDaesungAdvisor(YachtDaesungValues.fromBytes(File('assets/yacht/values_ds.bin').readAsBytesSync()));
    YachtController ds(int me, {bool host = false}) =>
        YachtController(mode: PlayMode.wifi, players: 2, humanSeat: me, cpuHost: host, level: YachtLevel.easy, advisor: dsAdvisor, daesung: true, rng: Random(5));
    final a = ds(0, host: true), b = ds(1);
    a.onLocalAction = (m) => expect(b.receive(m), isTrue, reason: '$m');
    b.onLocalAction = (m) => expect(a.receive(m), isTrue, reason: '$m');
    expect(a.game.daesung && b.game.daesung, isTrue);
    a.roll();
    await until(() => !a.rolling && !b.rolling);
    expect(b.game.dice, a.game.dice);
    final want = daesungScore(YachtCategory.choice, a.game.dice);
    a.choose(YachtCategory.choice);
    a.confirm();
    expect(a.game.cards[0].scores[YachtCategory.choice.index], want);
    expect(b.game.cards[0].scores[YachtCategory.choice.index], want);
    // 나갔다 들어올 때 받는 판의 모습에도 대성One Rule이 남는다
    final back = YachtControllerRejoin.fromWifiSnapshot(a.wifiSnapshot(), humanSeat: 1)!;
    expect(back.daesung, isTrue);
    expect(back.game.daesung, isTrue);
    a.dispose();
    b.dispose();
    back.dispose();
  });

  test('구르는 도중에 다음 소식이 와도 판이 어긋나지 않는다', () {
    final b = seat(1);
    expect(b.receive({'t': 'roll', 'd': [1, 2, 3, 4, 5], 'i': 0}), isTrue);
    expect(b.rolling, isTrue);
    expect(b.receive({'t': 'hold', 'h': [true, false, false, false, false], 'i': 1}), isTrue);
    expect(b.rolling, isFalse);
    expect(b.game.dice, [1, 2, 3, 4, 5]);
    expect(b.receive({'t': 'roll', 'd': [6, 2, 3, 4, 5], 'i': 1}), isFalse, reason: '잡은 주사위는 바뀔 수 없어요');
    expect(b.receive({'t': 'score', 'c': YachtCategory.choice.index, 'i': 7}), isFalse, reason: '순서가 안 맞는 소식');
    expect(b.receive({'t': 'score', 'c': YachtCategory.choice.index, 'i': 1}), isTrue);
    expect(b.game.cards[0].total, 15);
    expect(b.receive({'t': 'roll', 'd': [1, 1, 1, 1, 1], 'i': 2}), isFalse, reason: '내 차례의 소식을 남이 보낼 수 없어요');
    b.dispose();
  });

  test('나간 손님의 자리를 CPU가 맡으면 방장 기기에서 CPU가 굴리고 적으며, 다른 기기에도 알려진다', () async {
    final host = seat(0, players: 3, host: true, first: 1);
    final other = seat(2, players: 3, first: 1);
    final sent = <Map<String, dynamic>>[];
    host.onLocalAction = (m) {
      sent.add(m);
      expect(other.receive(m), isTrue, reason: '$m');
    };
    await host.start();
    expect(host.runsCpu, isFalse);
    expect(host.game.turn, 1);

    other.coverSeat(1);
    host.coverSeat(1);
    expect(host.runsCpu, isTrue);
    expect(other.runsCpu, isFalse, reason: '손님 기기는 CPU를 돌리지 않아요');
    await until(() => host.game.turn != 1);
    expect(host.game.turn, 2);
    expect(sent.first['t'], 'roll');
    expect(sent.last['t'], 'score');
    await until(() => other.game.turn == 2);
    expect(other.game.cards[1].total, host.game.cards[1].total);
    expect(other.humanTurn, isTrue);
    host.dispose();
    other.dispose();
  });

  test('CPU가 굴리는 도중에 손님이 돌아오면 굴린 것까지만 남고 손님이 이어 한다', () async {
    final host = seat(0, players: 2, host: true, first: 1);
    final sent = <Map<String, dynamic>>[];
    host.onLocalAction = sent.add;
    await host.start();
    host.coverSeat(1);
    await until(() => host.rolling);
    expect(host.rolling, isTrue);

    host.uncoverSeat(1);
    expect(host.rolling, isFalse);
    expect(host.game.rollsUsed, 1, reason: '이미 알린 굴리기는 적용돼 있어야 해요');
    final snap = host.wifiSnapshot();
    final back = YachtControllerRejoin.fromWifiSnapshot(snap, humanSeat: 1)!;
    expect(back.game.dice, host.game.dice);
    expect(back.actions, host.actions);
    expect(back.humanTurn, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 2500));
    expect(sent.length, 1, reason: '돌아온 뒤에 CPU가 그 자리에서 더 하면 안 돼요');
    expect(host.game.turn, 1);

    // 돌아온 손님이 이어서 적는다
    back.onLocalAction = (m) => expect(host.receive(m), isTrue, reason: '$m');
    back.choose(YachtCategory.choice);
    back.confirm();
    expect(host.game.turn, 0);
    expect(host.game.cards[1].total, back.game.cards[1].total);
    host.dispose();
    back.dispose();
  });

  test('구르는 중에 만든 판의 모습은 멈춘 뒤의 모습이다', () async {
    final host = seat(0, players: 3, host: true);
    host.roll();
    expect(host.rolling, isTrue);
    final snap = host.wifiSnapshot();
    final back = YachtControllerRejoin.fromWifiSnapshot(snap, humanSeat: 2)!;
    expect(back.players, 3);
    expect(back.game.rollsUsed, 1);
    expect(back.game.dice, host.rollTarget);
    expect(back.actions, 1);
    await until(() => !host.rolling);
    expect(host.game.dice, back.game.dice);
    expect(host.actions, back.actions);
    host.dispose();
    back.dispose();
  });

  test('맞지 않는 판의 모습은 받지 않는다', () {
    final c = seat(0, players: 3, host: true);
    final snap = c.wifiSnapshot();
    expect(YachtControllerRejoin.fromWifiSnapshot(snap, humanSeat: 1), isNotNull);
    expect(YachtControllerRejoin.fromWifiSnapshot(snap, humanSeat: 7), isNull);
    expect(YachtControllerRejoin.fromWifiSnapshot({'level': 0}, humanSeat: 0), isNull);
    expect(YachtControllerRejoin.fromWifiSnapshot({...snap, 'level': 99}, humanSeat: 1), isNull);
    final game = {...snap['game'] as Map<String, dynamic>, 'turn': 5};
    expect(YachtControllerRejoin.fromWifiSnapshot({...snap, 'game': game}, humanSeat: 1), isNull);
    c.dispose();
  });
}
