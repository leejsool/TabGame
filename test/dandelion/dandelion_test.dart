import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/dandelion/core/dandelion_ai.dart';
import 'package:tabgame/games/dandelion/core/dandelion_rules.dart';
import 'package:tabgame/games/dandelion/data/dandelion_history.dart';
import 'package:tabgame/games/dandelion/game/dandelion_controller.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_art.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_board.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_records_tab.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_screen.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_setup_screen.dart';

int cell(int r, int c) => r * kSize + c;
int dir(WindDir d) => d.index;

void main() {
  group('규칙', () {
    test('책의 그림: 꽃 하나에서 왼쪽으로 불면 왼쪽 두 칸이 씨앗이 된다', () {
      final s = DandState()..plant(cell(1, 2));
      expect(s.turn, Role.wind);
      final seeds = s.blow(WindDir.left);
      expect({for (final e in seeds) e.cell}, {cell(1, 0), cell(1, 1)});
      expect(s.cells[cell(1, 1)], kSeed);
      expect(s.cells[cell(1, 2)], kFlower);
      expect(s.cells[cell(1, 3)], kEmpty);
      expect(s.turn, Role.dandelion);
    });

    test('책의 그림: 꽃 둘에서 왼쪽 아래로 불면 비스듬히 씨앗이 날아간다', () {
      final s = DandState.fromMoves([cell(1, 2), dir(WindDir.left), cell(3, 4), dir(WindDir.downLeft)]);
      expect(s.cells[cell(2, 1)], kSeed);
      expect(s.cells[cell(3, 0)], kSeed);
      expect(s.cells[cell(4, 3)], kSeed);
      expect(s.cells[cell(1, 0)], kSeed);
      expect(s.cells[cell(1, 1)], kSeed);
      expect(s.cells.where((c) => c == kFlower).length, 2);
      expect(s.cells.where((c) => c == kSeed).length, 5);
    });

    test('씨앗에서는 씨앗이 나오지 않는다', () {
      final s = DandState.fromMoves([cell(2, 2), dir(WindDir.right), cell(0, 0), dir(WindDir.down)]);
      // 첫 바람으로 (2,3),(2,4)가 씨앗. 두 번째(아래)는 꽃 (2,2)·(0,0)에서만 → 씨앗 (2,3)에서는 안 나간다
      expect(s.cells[cell(3, 3)], kEmpty);
      expect(s.cells[cell(3, 2)], kSeed);
      expect(s.cells[cell(1, 0)], kSeed);
    });

    test('같은 방향은 두 번 못 불고, 꽃 위에는 꽃을 못 심는다. 씨앗 위에는 심을 수 있다', () {
      final s = DandState.fromMoves([cell(2, 2), dir(WindDir.right)]);
      expect(s.canPlant(cell(2, 2)), isFalse);
      expect(s.canPlant(cell(2, 3)), isTrue);
      s.plant(cell(2, 3));
      expect(s.cells[cell(2, 3)], kFlower);
      expect(s.canBlow(WindDir.right), isFalse);
      expect(s.canBlow(WindDir.left), isTrue);
    });

    test('차례가 아닐 때는 둘 수 없다', () {
      final s = DandState();
      expect(s.canBlow(WindDir.up), isFalse);
      s.plant(0);
      expect(s.canPlant(5), isFalse);
      expect(s.legalMoves().length, 8);
    });

    test('일곱 번째 바람이 지나면 끝: 빈칸이 있으면 바람 승리', () {
      final s = DandState();
      s.plant(cell(0, 0));
      for (var i = 0; i < kWindTurns; i++) {
        expect(s.isOver, isFalse);
        s.blow(WindDir.values[i]);
        if (i < kWindTurns - 1) s.plant(kSize * kSize - 1 - i);
      }
      expect(s.isOver, isTrue);
      expect(s.winner, Role.wind);
      expect(s.legalMoves(), isEmpty);
    });

    test('판이 가득 차면 바람이 남아 있어도 민들레 승리', () {
      final s = DandState();
      for (var i = 0; i < kSize * kSize - 1; i++) {
        s.cells[i] = kSeed;
      }
      s.plies = 2;
      expect(s.isOver, isFalse);
      s.plant(kSize * kSize - 1);
      expect(s.isOver, isTrue);
      expect(s.winner, Role.dandelion);
    });
  });

  group('CPU', () {
    test('쉬움·보통·어려움 모두 합법적인 수를 끝까지 둔다 (민들레/바람)', () {
      final rng = Random(1);
      for (final level in DandLevel.values) {
        final s = DandState();
        while (!s.isOver) {
          final m = DandAi.choose(s, level, rng);
          expect(s.legalMoves(), contains(m), reason: '${level.label} ${s.turn.label}');
          s.apply(m);
        }
        expect(s.winner, isNotNull);
      }
    }, tags: 'slow');

    test('빈칸이 하나 남았으면 꽃을 심어 메운다', () {
      final s = DandState();
      for (var i = 1; i < kSize * kSize; i++) {
        s.cells[i] = kSeed;
      }
      s.plies = 2;
      s.windCount = 1;
      s.usedWinds = 1;
      expect(DandAi.choose(s, DandLevel.hard, Random(3)), 0);
    });

    test('바람은 구석 꽃 앞에서 씨앗이 안 생기는 방향을 고른다 (어려움)', () {
      final s = DandState.fromMoves([cell(0, 0)]);
      final m = DandAi.choose(s, DandLevel.hard, Random(5));
      expect([WindDir.up.index, WindDir.left.index, WindDir.upLeft.index], contains(m));
    });
  });

  group('컨트롤러', () {
    test('둘이서: 꽃 심기와 바람이 번갈아 진행되고 되돌릴 수 있다', () {
      final c = DandelionController(mode: PlayMode.local2p);
      expect(c.blow(WindDir.up), isFalse); // 민들레 차례
      expect(c.plant(cell(2, 2)), isTrue);
      expect(c.plant(cell(0, 0)), isFalse); // 바람 차례
      expect(c.blow(WindDir.left), isTrue);
      expect(c.lastSeeds.length, 2);
      expect(c.canUndo, isTrue);
      c.undo();
      expect(c.moveCount, 1);
      expect(c.state.turn, Role.wind);
      c.dispose();
    });

    test('기권할 수 있는 건 한 수라도 둔 뒤', () {
      final c = DandelionController(mode: PlayMode.local2p);
      expect(c.canResign, isFalse);
      c.plant(0);
      expect(c.canResign, isTrue);
      expect(c.resigningRole, Role.wind);
      expect(c.resign(), isTrue);
      c.dispose();
    });
  });

  group('기록', () {
    test('기록이 저장되고 다시 읽힌다', () async {
      SharedPreferences.setMockInitialValues({});
      await DandelionHistory.add(const DandelionRecord(
        at: 1,
        vsCpu: true,
        winner: Role.wind,
        moves: 14,
        empties: 2,
        level: DandLevel.hard,
        human: Role.wind,
      ));
      final list = await DandelionHistory.load();
      expect(list.single.winner, Role.wind);
      expect(list.single.humanWon, isTrue);
      expect(list.single.level, DandLevel.hard);
    });
  });

  group('화면', () {
    Future<DandelionController> pump(
      WidgetTester tester,
      Size size, {
      PlayMode mode = PlayMode.local2p,
      Role human = Role.dandelion,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final settings = await Settings.load();
      final c = DandelionController(mode: mode, humanRole: human, level: DandLevel.easy);
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(theme: ThemeData(useMaterial3: true), home: DandelionScreen(controller: c)),
      ));
      await tester.pump();
      return c;
    }

    Offset cellPos(WidgetTester tester, int i) {
      final box = find.byType(DandelionBoard);
      final size = tester.getSize(box);
      final layout = DandLayout(size.shortestSide);
      return tester.getTopLeft(box) + layout.center(i);
    }

    for (final size in const [Size(390, 800), Size(1000, 600), Size(1280, 800)]) {
      testWidgets('${size.width.toInt()}×${size.height.toInt()}: 꽃을 심고 나침반으로 바람을 불 수 있다', (tester) async {
        final c = await pump(tester, size);
        await tester.tapAt(cellPos(tester, cell(1, 2)));
        await tester.pump(const Duration(milliseconds: 600));
        expect(c.state.cells[cell(1, 2)], kFlower);
        expect(c.state.turn, Role.wind);

        final compass = find.byType(DandelionCompass);
        final tl = tester.getTopLeft(compass);
        final r = tester.getSize(compass).width / 2;
        // 왼쪽 화살표
        await tester.tapAt(tl + Offset(r * 0.3, r));
        await tester.pump(const Duration(milliseconds: 200));
        expect(c.state.usedWinds, 1 << WindDir.left.index);
        expect(c.state.cells[cell(1, 0)], kSeed);
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('나침반 가운데를 잡고 끌었다 놓으면 그 방향으로 분다 (조이스틱)', (tester) async {
      final c = await pump(tester, const Size(390, 800));
      await tester.tapAt(cellPos(tester, cell(2, 2)));
      await tester.pump(const Duration(milliseconds: 600));
      final compass = find.byType(DandelionCompass);
      final center = tester.getCenter(compass);
      final r = tester.getSize(compass).width / 2;

      // 가운데에서 아래로 끌어 보기만 하고 가운데로 되돌려 놓으면 취소
      var g = await tester.startGesture(center);
      await g.moveTo(center + Offset(0, r * 0.8));
      await tester.pump();
      await g.moveTo(center);
      await g.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.state.windCount, 0);

      // 오른쪽 아래로 끌었다 놓으면 분다 (조금 벗어나도 가장 가까운 방향)
      g = await tester.startGesture(center);
      await g.moveTo(center + Offset(r * 0.6, r * 0.8));
      await tester.pump();
      await g.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.state.usedWinds, 1 << WindDir.downRight.index);
      expect(c.state.cells[cell(3, 3)], kSeed);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('이미 분 방향으로 끌어서 놓으면 아무 일도 없다', (tester) async {
      final c = await pump(tester, const Size(390, 800));
      c.plant(cell(2, 2));
      c.blow(WindDir.left);
      c.plant(cell(0, 0));
      await tester.pump(const Duration(seconds: 2));
      final compass = find.byType(DandelionCompass);
      final center = tester.getCenter(compass);
      final r = tester.getSize(compass).width / 2;
      final g = await tester.startGesture(center);
      await g.moveTo(center + Offset(-r * 0.8, 0));
      await tester.pump();
      await g.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.state.windCount, 1);
      expect(c.state.turn, Role.wind);
    });

    testWidgets('CPU가 민들레이면 먼저 꽃을 심는다', (tester) async {
      final c = await pump(tester, const Size(390, 800), mode: PlayMode.vsCpu, human: Role.wind);
      for (var i = 0; i < 20 && c.moveCount == 0; i++) {
        await tester.pump(const Duration(milliseconds: 400));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      }
      await tester.pump(const Duration(seconds: 2));
      expect(c.moveCount, 1);
      expect(c.state.flowerCount, 1);
      expect(c.humanCanAct, isTrue);
    });

    testWidgets('설정 화면과 기록 탭이 그려진다', (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: const MaterialApp(home: DandelionSetupScreen()),
      ));
      await tester.pump();
      expect(find.text('시작하기'), findsOneWidget);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: DandelionRecordsTab())));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('CPU와 대결'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
