import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/game_registry.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/yacht/core/yacht_advisor.dart';
import 'package:tabgame/games/yacht/core/yacht_cpu.dart';
import 'package:tabgame/games/yacht/core/yacht_values.dart';
import 'package:tabgame/games/yacht/data/yacht_history.dart';
import 'package:tabgame/games/yacht/game/yacht_controller.dart';
import 'package:tabgame/games/yacht/ui/yacht_party_picker.dart';
import 'package:tabgame/games/yacht/ui/yacht_screen.dart';
import 'package:tabgame/games/yacht/ui/yacht_setup_screen.dart';

import '../support/preview_kit.dart';

final advisor = YachtAdvisor(YachtValues.fromBytes(File('assets/yacht/values.bin').readAsBytesSync()));

Future<void> pumpSetup(WidgetTester tester, {Size size = const Size(400, 860)}) async {
  await loadAppFonts();
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(SettingsScope(
    settings: settings,
    child: MaterialApp(theme: previewTheme(Brightness.light), home: const YachtSetupScreen()),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

String total(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('yacht-party-total'))).data!;
String count(WidgetTester tester, String id) => tester.widget<Text>(find.byKey(ValueKey('yacht-$id-count'))).data!;

Future<void> tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  test('야추는 한 기기에서 사람과 봇을 섞어 정하니 "CPU와 대결" 방식이 따로 없다', () {
    final yacht = allGames.firstWhere((g) => g.id == 'yacht');
    expect(yacht.modes, [PlayMode.local2p, PlayMode.wifi]);
    expect(yacht.modeLabel(PlayMode.local2p), '로컬 플레이 (한 기기)');
    expect(yacht.modeChip(PlayMode.local2p), '로컬');
    expect(yacht.modeInSetup, isTrue, reason: '허브에서 로컬/Wi‑Fi를 묻지 않고 설정 화면으로 바로 (Wi‑Fi는 설정 화면 칩에서)');
  });

  test('+/− 규칙: 꽉 찼을 때 늘리거나 최소일 때 줄이면 봇과 로컬이 한 자리를 맞바꾼다', () {
    (int, int)? s(int h, int b, {int hd = 0, int bd = 0}) => YachtPartyPicker.step(h, b, humanDelta: hd, botDelta: bd);
    // (사람, 봇)
    expect(s(1, 1, hd: 1), (2, 1));
    expect(s(3, 1, hd: 1), (4, 0), reason: '봇1 로컬3에서 로컬+ → 봇0 로컬4');
    expect(s(4, 0, hd: 1), isNull, reason: '사람만 4명이면 더 못 늘린다');
    expect(s(1, 1, bd: -1), (2, 0), reason: '봇1 로컬1에서 봇− → 봇0 로컬2');
    expect(s(2, 0, hd: -1), (1, 1), reason: '봇0 로컬2에서 로컬− → 봇1 로컬1');
    expect(s(1, 1, hd: -1), isNull, reason: '사람은 적어도 한 명');
    expect(s(2, 0, bd: -1), isNull, reason: '봇이 없으면 봇−는 없다');
    expect(s(2, 2, bd: 1), (1, 3), reason: '꽉 찼을 때 봇+ → 사람 한 명이 봇으로');
    expect(s(1, 3, bd: 1), isNull, reason: '사람 1 + 봇 3이면 더 못 바꾼다');
    expect(s(2, 2, bd: -1), (2, 1));
    expect(s(3, 1, hd: -1), (2, 1));
  });

  testWidgets('설정: 봇과 로컬 플레이어를 + / − 로 정한다 (합쳐서 2~4명, 끝에서는 맞바꾼다)', (tester) async {
    await pumpSetup(tester);
    expect(total(tester), '2/4');
    expect(count(tester, 'bots'), '1');
    expect(count(tester, 'humans'), '1');
    expect(find.text('나'), findsOneWidget);
    expect(find.text('CPU'), findsOneWidget);
    expect(find.textContaining('봇은 CPU가 대신 굴려요'), findsNothing, reason: '안내 문구는 없앴다');

    await tap(tester, 'yacht-humans-plus');
    await tap(tester, 'yacht-humans-plus');
    expect((count(tester, 'humans'), count(tester, 'bots'), total(tester)), ('3', '1', '4/4'));
    // 꽉 찬 채로 로컬+ → 봇이 빠지고 로컬 4명
    await tap(tester, 'yacht-humans-plus');
    expect((count(tester, 'humans'), count(tester, 'bots'), total(tester)), ('4', '0', '4/4'));
    expect(find.text('플레이어 4'), findsOneWidget);
    expect(find.text('봇 난이도'), findsNothing, reason: '봇이 없으면 난이도 고르기도 없다');

    // 로컬을 2명까지 줄인 뒤 로컬− → 봇1 로컬1
    await tap(tester, 'yacht-humans-minus');
    await tap(tester, 'yacht-humans-minus');
    expect((count(tester, 'humans'), count(tester, 'bots')), ('2', '0'));
    await tap(tester, 'yacht-humans-minus');
    expect((count(tester, 'humans'), count(tester, 'bots'), total(tester)), ('1', '1', '2/4'));
    expect(find.text('나'), findsOneWidget);

    // 봇1 로컬1에서 봇− → 봇0 로컬2
    await tap(tester, 'yacht-bots-minus');
    expect((count(tester, 'humans'), count(tester, 'bots'), total(tester)), ('2', '0', '2/4'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('설정: 시작하면 사람은 앞자리, 봇은 뒷자리에 앉고 쓰리카드 옵션이 따라간다', (tester) async {
    await pumpSetup(tester);
    await tap(tester, 'yacht-humans-plus'); // 사람 2 + 봇 1
    await tap(tester, 'yacht-three-kind');
    await tester.scrollUntilVisible(find.text('시작하기'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(find.text('시작하기'));
    for (var i = 0; i < 6; i++) {
      // (이어하던 판이 있는지 보관함을 읽는다)
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
    final screen = tester.widget<YachtScreen>(find.byType(YachtScreen));
    expect(screen.players, 3);
    expect(screen.cpuSeats, [2]);
    expect(screen.threeKind, isTrue);
    expect(screen.mode, PlayMode.local2p);
    expect(screen.turnSeconds, kYachtTurnSeconds, reason: '시간 무제한을 켜지 않으면 한 턴 60초');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  group('사람 + 봇 컨트롤러', () {
    test('사람 2 + 봇 1: 이름 · 차례 · 저장', () {
      final c = YachtController(mode: PlayMode.local2p, players: 3, cpuSeats: [2], advisor: advisor, rng: Random(2));
      expect(c.vsCpu, isFalse, reason: '사람이 둘이니 CPU와 대결이 아니라 로컬 판');
      expect(c.isCpu(2), isTrue);
      expect(c.isCpu(0), isFalse);
      expect(c.name(0), '플레이어 1');
      expect(c.name(2), 'CPU');
      expect(c.shortName(0), '1번');
      expect(c.shortName(2), 'CPU');
      expect(c.humans, 2);
      expect(c.humanTurn, isTrue);
      c.game.turn = 2;
      expect(c.humanTurn, isFalse, reason: '봇 차례에는 누를 수 없다');
      final back = YachtController.fromJson(c.toJson())!;
      expect(back.cpuSeats, {2});
      expect(back.isCpu(2), isTrue);
    });

    test('사람 1 + 봇 2는 옛 CPU 대결과 같다 (이름 "나" · "CPU 1/2")', () {
      final c = YachtController(mode: PlayMode.local2p, players: 3, cpuSeats: [1, 2], level: YachtLevel.hard, advisor: advisor);
      expect(c.vsCpu, isTrue);
      expect(c.name(0), '나');
      expect(c.name(1), 'CPU 1');
      expect(c.name(2), 'CPU 2');
    });

    test('옛 CPU와 대결 보관본도 그대로 읽는다', () {
      final old = YachtController(mode: PlayMode.vsCpu, players: 3, advisor: advisor);
      expect(old.cpuSeats, {1, 2});
      expect(old.vsCpu, isTrue);
      final json = old.toJson()..remove('cpu');
      final back = YachtController.fromJson(json)!;
      expect(back.cpuSeats, {1, 2});
      expect(back.name(2), 'CPU 2');
    });

    test('봇은 자기 차례를 스스로 끝내고 사람에게 넘긴다', () async {
      final c = YachtController(mode: PlayMode.local2p, players: 3, cpuSeats: [2], level: YachtLevel.hard, advisor: advisor, rng: Random(5), first: 2);
      await c.start();
      for (var i = 0; i < 80 && c.game.turn == 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(c.game.turn, 0, reason: '봇(2번 자리)이 한 차례를 끝내고 0번 사람에게 넘어간다');
      expect(c.game.cards[2].filledCount, 1);
      c.dispose();
    });
  });

  test('기록: 봇이 낀 판은 사람 자리 수와 봇 승리를 따로 센다', () {
    final r = YachtRecord(at: 1, vsCpu: false, scores: [100, 90, 150], bots: 1, level: YachtLevel.normal);
    expect(r.humans, 2);
    expect(r.winners, [2]);
    final back = YachtRecord.fromJson(r.toJson());
    expect(back.bots, 1);
    expect(back.level, YachtLevel.normal);
    expect(YachtRecord.fromJson({'at': 1, 'cpu': false, 's': [1, 2], 'lv': null}).bots, 0, reason: '옛 기록');
  });
}
