import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/bgm.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/minesweeper/minesweeper_entry.dart';
import 'package:tabgame/games/stones/stones_entry.dart';
import 'package:tabgame/hub/settings_screen.dart';

void main() {
  late Settings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await Settings.load();
    Bgm.instance.setEnabled(true);
    Bgm.instance.setPaused(false);
  });

  Widget app(Widget child) => SettingsScope(settings: settings, child: MaterialApp(home: child));

  test('설정: 배경음악은 기본으로 켜져 있고, 끄면 저장된다', () async {
    expect(settings.bgm, isTrue);
    settings.bgm = false;
    final again = await Settings.load();
    expect(again.bgm, isFalse);
  });

  testWidgets('설정 화면에 "배경음악" 스위치가 있고 누르면 꺼진다', (tester) async {
    await tester.pumpWidget(app(SettingsScreen(settings: settings)));
    await tester.pump();
    expect(find.text('배경음악'), findsOneWidget);
    await tester.tap(find.text('배경음악'));
    await tester.pump();
    expect(settings.bgm, isFalse);
  });

  testWidgets('게임 화면이 열려 있는 동안만 곡이 흐르고, 스위치를 끄면 멈추고 켜면 다시 흐른다', (tester) async {
    expect(Bgm.instance.playing, isNull);
    await tester.pumpWidget(app(const GameBgm(asset: kBgmMed, child: SizedBox())));
    expect(Bgm.instance.playing, kBgmMed);
    settings.bgm = false;
    await tester.pump();
    expect(Bgm.instance.playing, isNull);
    settings.bgm = true;
    await tester.pump();
    expect(Bgm.instance.playing, kBgmMed);
    await tester.pumpWidget(const SizedBox()); // 화면이 닫힌다
    expect(Bgm.instance.playing, isNull);
  });

  testWidgets('꺼 둔 사람이 게임을 열어도 곡이 시작되지 않는다', (tester) async {
    settings.bgm = false;
    await tester.pumpWidget(app(const GameBgm(asset: kBgmMed, child: SizedBox())));
    expect(Bgm.instance.playing, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('같은 곡을 쓰는 화면이 겹쳐 쌓여도 곡은 하나로 이어지고, 마지막 화면이 닫혀야 멈춘다', (tester) async {
    await tester.pumpWidget(app(const GameBgm(asset: kBgmMed, child: GameBgm(asset: kBgmMed, child: SizedBox()))));
    expect(Bgm.instance.playing, kBgmMed);
    await tester.pumpWidget(app(const GameBgm(asset: kBgmMed, child: SizedBox()))); // 안쪽 화면만 닫힌다
    expect(Bgm.instance.playing, kBgmMed);
    await tester.pumpWidget(const SizedBox());
    expect(Bgm.instance.playing, isNull);
  });

  testWidgets('앱이 뒤로 가면 멈추고 돌아오면 이어서 흐른다', (tester) async {
    await tester.pumpWidget(app(const GameBgm(asset: kBgmMed, child: SizedBox())));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(Bgm.instance.playing, isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(Bgm.instance.playing, kBgmMed);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('바둑돌 옮기기와 지뢰찾기 진입 화면은 배경음악으로 감싸져 있다', (tester) async {
    await tester.pumpWidget(app(Builder(builder: (c) => buildStones(c, PlayMode.local2p))));
    await tester.pump();
    expect(Bgm.instance.playing, kBgmMed);
    await tester.pumpWidget(const SizedBox());
    expect(Bgm.instance.playing, isNull);
    await tester.pumpWidget(app(Builder(builder: (c) => buildMinesweeper(c, PlayMode.solo))));
    await tester.pump();
    expect(Bgm.instance.playing, kBgmMed);
    await tester.pumpWidget(const SizedBox());
    expect(Bgm.instance.playing, isNull);
  });
}
