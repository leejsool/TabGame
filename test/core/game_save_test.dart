import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/game_save.dart';
import 'package:tabgame/core/leave_guard.dart';
import 'package:tabgame/core/resume_gate.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/dandelion/core/dandelion_rules.dart';
import 'package:tabgame/games/dandelion/game/dandelion_controller.dart';
import 'package:tabgame/games/davinci/game/davinci_controller.dart';
import 'package:tabgame/games/goblet/core/goblet_rules.dart';
import 'package:tabgame/games/goblet/game/goblet_controller.dart';
import 'package:tabgame/games/prophecy/game/prophecy_controller.dart';
import 'package:tabgame/games/quoridor/core/quoridor_rules.dart';
import 'package:tabgame/games/quoridor/game/quoridor_controller.dart';
import 'package:tabgame/games/quoridor/ui/quoridor_screen.dart';
import 'package:tabgame/games/quoridor/ui/quoridor_setup_screen.dart';
import 'package:tabgame/games/rummikub/game/rummikub_controller.dart';
import 'package:tabgame/games/sprouts/core/sprouts_planner.dart';
import 'package:tabgame/games/sprouts/game/sprouts_controller.dart';
import 'package:tabgame/games/uttt/game/uttt_controller.dart';

/// JSON을 거쳐 저장했다 읽은 것처럼 만든다 (SharedPreferences에 문자열로 들어가니까).
Map<String, dynamic> viaJson(Map<String, dynamic> j) => jsonDecode(jsonEncode(j)) as Map<String, dynamic>;

Future<Widget> app(Widget home) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  return SettingsScope(
    settings: settings,
    child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: home),
  );
}

/// 비동기 저장소 작업이 끝나도록 진짜 시간을 조금 흘린다.
Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

int cell(int r, int c) => r * kBoard + c;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('GameSave', () {
    test('게임마다 따로 쓰고, 읽고, 지운다', () async {
      expect(await GameSave.load('a'), isNull);
      await GameSave.write('a', {'x': 1});
      await GameSave.write('b', {'x': 2});
      expect((await GameSave.load('a'))!['x'], 1);
      expect((await GameSave.load('b'))!['x'], 2);
      await GameSave.clear('a');
      expect(await GameSave.load('a'), isNull);
      expect(await GameSave.load('b'), isNotNull);
    });

    test('깨진 저장은 버린다', () async {
      SharedPreferences.setMockInitialValues({'save.a': '{깨진'});
      expect(await GameSave.load('a'), isNull);
    });

    test('바뀔 때마다 알린다', () async {
      final before = GameSave.changes.value;
      await GameSave.write('a', {});
      expect(GameSave.changes.value, before + 1);
      await GameSave.clear('a');
      expect(GameSave.changes.value, before + 2);
      await GameSave.clear('a'); // (지울 것이 없으면 알리지 않는다)
      expect(GameSave.changes.value, before + 2);
    });
  });

  group('GameSaver', () {
    test('보관할 것이 없으면 묻지 않고, 저장하면 보관되고, 끝나면 지워진다', () async {
      Map<String, dynamic>? snap;
      final saver = GameSaver(gameId: 'g', snapshot: () => snap);
      expect(saver.active, isFalse);
      snap = {'moves': 3};
      expect(saver.active, isTrue);
      await saver.save();
      expect((await GameSave.load('g'))!['moves'], 3);
      await saver.finish();
      expect(await GameSave.load('g'), isNull);
      // 끝난 뒤에는 다시 보관하지 않는다 (새 판이 시작되면 rearm)
      await saver.save();
      expect(await GameSave.load('g'), isNull);
      saver.rearm();
      await saver.save();
      expect(await GameSave.load('g'), isNotNull);
    });

    test('저장 안 하고 나가기는 지우고, 그 뒤로 보관하지 않는다', () async {
      final saver = GameSaver(gameId: 'g', snapshot: () => {'a': 1});
      await saver.save();
      await saver.discard();
      expect(await GameSave.load('g'), isNull);
      expect(saver.active, isFalse);
      await saver.save();
      expect(await GameSave.load('g'), isNull);
    });
  });

  group('판 저장·복원', () {
    test('쿼리도 (한 기기)', () {
      final c = QuoridorController(mode: PlayMode.local2p);
      expect(c.savable, isFalse);
      expect(c.tapCell(cell(7, 4)), isTrue);
      expect(c.tapCell(cell(1, 4)), isTrue);
      expect(c.savable, isTrue);
      final r = QuoridorController.fromJson(viaJson(c.toJson()))!;
      expect(r.mode, PlayMode.local2p);
      expect(r.moves, c.moves);
      expect(r.state.pawn, c.state.pawn);
      expect(r.turn, c.turn);
      c.dispose();
      r.dispose();
    });

    test('쿼리도: 깨진 저장은 null', () {
      final c = QuoridorController(mode: PlayMode.local2p)..tapCell(cell(7, 4));
      final j = viaJson(c.toJson());
      j['moves'] = [9999];
      expect(QuoridorController.fromJson(j), isNull);
      expect(QuoridorController.fromJson({'mode': 'wifi'}), isNull);
      c.dispose();
    });

    test('궁극 틱택토', () {
      final c = UtttController(mode: PlayMode.local2p);
      c.play(40);
      c.play(c.state.legalMoves().first);
      expect(c.savable, isTrue);
      final r = UtttController.fromJson(viaJson(c.toJson()))!;
      expect(r.moves, c.moves);
      expect(r.state.turn, c.state.turn);
      expect(r.state.next, c.state.next);
      c.dispose();
      r.dispose();
    });

    test('고블렛 고블러스', () {
      final c = GobbletController(mode: PlayMode.local2p);
      expect(c.dropPiece(pieceId(Team.red, 3, 0), 4), isTrue);
      expect(c.dropPiece(pieceId(Team.blue, 3, 0), 0), isTrue);
      expect(c.savable, isTrue);
      final r = GobbletController.fromJson(viaJson(c.toJson()))!;
      expect(r.board.owners, c.board.owners);
      expect(r.board.turn, c.board.turn);
      expect(r.loc, c.loc);
      expect(r.moveCount, 2);
      r.undo(); // 되돌리기에 쓰는 지난 모습도 되살아난다
      expect(r.moveCount, 1);
      c.dispose();
      r.dispose();
    });

    test('콩나물', () {
      final c = SproutsController(mode: PlayMode.local2p, dotCount: 3, rng: Random(5));
      final m = findMoves(c.board).firstWhere((m) => !m.isLoop);
      expect(c.tryStroke(m.path), isTrue);
      expect(c.savable, isTrue);
      final r = SproutsController.fromJson(viaJson(c.toJson()))!;
      expect(r.turn, c.turn);
      expect(r.moveCount, 1);
      expect(r.board.dots.length, c.board.dots.length);
      expect(r.board.curves.length, c.board.curves.length);
      expect(r.canUndo, isTrue);
      c.dispose();
      r.dispose();
    });

    test('예언', () {
      final c = ProphecyController(mode: PlayMode.local2p, rows: 4, cols: 4);
      c.select(0);
      expect(c.write(1), isTrue);
      expect(c.savable, isTrue);
      final r = ProphecyController.fromJson(viaJson(c.toJson()))!;
      expect(r.rows, 4);
      expect(r.moves, c.moves);
      expect(r.state.cells, c.state.cells);
      c.dispose();
      r.dispose();
    });

    test('민들레', () {
      final c = DandelionController(mode: PlayMode.local2p);
      expect(c.plant(0), isTrue);
      expect(c.blow(WindDir.values.first), isTrue);
      expect(c.savable, isTrue);
      final r = DandelionController.fromJson(viaJson(c.toJson()))!;
      expect(r.moves, c.moves);
      expect(r.state.cells, c.state.cells);
      expect(r.state.turn, c.state.turn);
      c.dispose();
      r.dispose();
    });

    test('민들레: 둘 수 없는 수가 낀 저장은 null', () {
      final j = viaJson(DandelionController(mode: PlayMode.local2p).toJson());
      j['moves'] = [0, 99]; // (99번 바람 방향은 없다)
      expect(DandelionController.fromJson(j), isNull);
    });

    test('다빈치 코드 (CPU 대결)', () {
      final c = DavinciController(mode: PlayMode.vsCpu, players: 2, humanSeat: 0, seed: 4, animate: false)..cpuStepDelay = Duration.zero;
      expect(c.draw(0), isTrue);
      expect(c.savable, isTrue);
      final r = DavinciController.fromJson(viaJson(c.toJson()), animate: false)!;
      expect(r.seed, c.seed);
      expect(r.moves, c.moves);
      expect(r.state.turn, c.state.turn);
      expect(r.state.phase, c.state.phase);
      expect(r.state.rows, c.state.rows);
      expect(r.drawnBy, c.drawnBy);
      c.dispose();
      r.dispose();
    });

    test('루미큐브 (CPU 대결): 내 손과 판, 더미가 그대로 돌아온다', () {
      final c = RummikubController(animate: false, mode: PlayMode.vsCpu, players: 2, humanSeat: 0, seed: 3);
      expect(c.savable, isFalse); // 아직 한 차례도 안 지났다
      c.draw();
      expect(c.savable, isTrue);
      final r = RummikubController.fromJson(viaJson(c.toJson()), animate: false)!;
      expect(r.seed, c.seed);
      expect(r.moveCount, c.moveCount);
      expect(r.state.racks, c.state.racks);
      expect(r.state.pool, c.state.pool);
      expect(r.state.table, c.state.table);
      expect(r.state.turn, c.state.turn);
      expect(r.hand, c.hand);
      c.dispose();
      r.dispose();
    });

    test('루미큐브: 맞지 않는 저장은 null', () {
      final c = RummikubController(animate: false, mode: PlayMode.vsCpu, players: 2, humanSeat: 0, seed: 3)..draw();
      final j = viaJson(c.toJson());
      (j['state'] as Map<String, dynamic>)['pool'] = <int>[];
      expect(RummikubController.fromJson(j), isNull);
      c.dispose();
    });
  });

  group('SaveLeaveGuard', () {
    Future<List<String>> pumpGuard(WidgetTester tester, {required bool active}) async {
      final log = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => SaveLeaveGuard(
                    active: () => active,
                    onSave: () async => log.add('save'),
                    onDiscard: () async => log.add('discard'),
                    child: const Scaffold(body: Text('게임 화면')),
                  ),
                )),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.text('게임 화면'), findsOneWidget);
      return log;
    }

    testWidgets('아직 아무것도 안 한 판은 묻지 않고 바로 나간다', (tester) async {
      final log = await pumpGuard(tester, active: false);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('게임 화면'), findsNothing);
      expect(find.text('게임에서 나갈까요?'), findsNothing);
      expect(log, isEmpty);
    });

    testWidgets('계속하기를 고르면 그대로 남는다', (tester) async {
      final log = await pumpGuard(tester, active: true);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('게임에서 나갈까요?'), findsOneWidget);
      await tester.tap(find.text('계속하기'));
      await tester.pumpAndSettle();
      expect(find.text('게임 화면'), findsOneWidget);
      expect(log, isEmpty);
    });

    testWidgets('저장하고 나가기', (tester) async {
      final log = await pumpGuard(tester, active: true);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장하고 나가기'));
      await tester.pumpAndSettle();
      expect(find.text('게임 화면'), findsNothing);
      expect(log, ['save']);
    });

    testWidgets('저장 안 하고 나가기', (tester) async {
      final log = await pumpGuard(tester, active: true);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장 안 하고 나가기'));
      await tester.pumpAndSettle();
      expect(find.text('게임 화면'), findsNothing);
      expect(log, ['discard']);
    });
  });

  group('쿼리도 화면: 뒤로가기', () {
    Future<QuoridorController> pumpGame(WidgetTester tester) async {
      final c = QuoridorController(mode: PlayMode.local2p);
      await tester.binding.setSurfaceSize(const Size(800, 1280));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(await app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => QuoridorScreen(mode: PlayMode.local2p, controller: c)),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('열기'));
      await tester.pump(const Duration(milliseconds: 500));
      return c;
    }

    testWidgets('한 수도 안 뒀으면 묻지 않는다', (tester) async {
      await pumpGame(tester);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('게임에서 나갈까요?'), findsNothing);
      expect(find.text('열기'), findsOneWidget);
    });

    testWidgets('저장하고 나가면 이어하기용으로 남는다', (tester) async {
      final c = await pumpGame(tester);
      c.tapCell(cell(7, 4));
      await settle(tester);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('게임에서 나갈까요?'), findsOneWidget);
      await tester.tap(find.text('저장하고 나가기'));
      await settle(tester);
      expect(find.text('열기'), findsOneWidget);
      final saved = await tester.runAsync(() => GameSave.load('quoridor'));
      expect(saved, isNotNull);
      expect(QuoridorController.fromJson(saved!)!.moves, [c.lastMove]);
    });

    testWidgets('저장 안 하고 나가면 이어하기용 보관이 지워진다', (tester) async {
      final c = await pumpGame(tester);
      c.tapCell(cell(7, 4));
      await settle(tester);
      expect(await tester.runAsync(() => GameSave.load('quoridor')), isNotNull); // (한 수마다 알아서 보관된다)
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('저장 안 하고 나가기'));
      await settle(tester);
      expect(find.text('열기'), findsOneWidget);
      expect(await tester.runAsync(() => GameSave.load('quoridor')), isNull);
    });

    testWidgets('하던 판 도중에 새 판을 누르면 먼저 묻는다', (tester) async {
      final c = await pumpGame(tester);
      c.tapCell(cell(7, 4));
      await settle(tester);
      await tester.tap(find.text('새 판'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('새 판을 시작할까요?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.moveCount, 1);
      await tester.tap(find.text('새 판'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('새 판')));
      await settle(tester);
      expect(c.moveCount, 0);
      expect(await tester.runAsync(() => GameSave.load('quoridor')), isNull);
    });
  });

  group('설정 화면: 이어하기', () {
    testWidgets('이어하던 판이 있으면 카드가 보이고, 새로 시작하려면 먼저 묻는다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1280));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final c = QuoridorController(mode: PlayMode.vsCpu, humanSeat: 0)..tapCell(cell(7, 4));
      await tester.pumpWidget(await app(const QuoridorSetupScreen(mode: PlayMode.vsCpu)));
      await tester.runAsync(() => GameSave.write('quoridor', c.toJson()));
      await settle(tester);
      expect(find.text('이어하기'), findsOneWidget);

      // 새로 시작: 이어하던 판이 사라진다고 묻는다 — 취소하면 그대로
      await tester.tap(find.text('시작하기'));
      await settle(tester);
      expect(find.text('이어하던 판이 있어요'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await settle(tester);
      expect(find.text('이어하기'), findsOneWidget);
      expect(await tester.runAsync(() => GameSave.load('quoridor')), isNotNull);

      // 새로 시작을 고르면 보관된 판이 지워지고 새 판 화면으로 간다
      await tester.tap(find.text('시작하기'));
      await settle(tester);
      await tester.tap(find.text('새로 시작'));
      await settle(tester);
      expect(find.byType(QuoridorScreen), findsOneWidget);
      expect(await tester.runAsync(() => GameSave.load('quoridor')), isNull);
      c.dispose();
    });

    testWidgets('이어하기 카드를 누르면 저장된 판이 열린다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1280));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final c = QuoridorController(mode: PlayMode.local2p)..tapCell(cell(7, 4)); // (한 기기 판도 CPU 설정 화면에서 이어진다)
      await tester.pumpWidget(await app(const QuoridorSetupScreen(mode: PlayMode.vsCpu)));
      await tester.runAsync(() => GameSave.write('quoridor', c.toJson()));
      await settle(tester);
      await tester.tap(find.text('이어하기'));
      await settle(tester);
      final screen = tester.widget<QuoridorScreen>(find.byType(QuoridorScreen));
      expect(screen.controller!.moves, c.moves);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });

    testWidgets('보관된 판이 없으면 카드도 묻는 창도 없다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1280));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(await app(const QuoridorSetupScreen(mode: PlayMode.vsCpu)));
      await settle(tester);
      expect(find.text('이어하기'), findsNothing);
      await tester.tap(find.text('시작하기'));
      await settle(tester);
      expect(find.text('이어하던 판이 있어요'), findsNothing);
      expect(find.byType(QuoridorScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('ResumeGate', () {
    Widget gate() => ResumeGate(
          gameId: 'g',
          gameName: '시험 게임',
          fresh: (_) => const Scaffold(body: Text('새 판 화면')),
          resumeBuilder: (saved) => saved['bad'] == true ? null : Scaffold(body: Text('이어한 판 ${saved['n']}')),
          describe: (saved) => '${saved['n']}수째',
        );

    testWidgets('저장이 없으면 바로 새 판', (tester) async {
      await tester.pumpWidget(await app(gate()));
      await settle(tester);
      expect(find.text('새 판 화면'), findsOneWidget);
    });

    testWidgets('저장이 있으면 이어하기를 고를 수 있다', (tester) async {
      await tester.pumpWidget(await app(gate()));
      await tester.runAsync(() => GameSave.write('g', {'n': 7}));
      // (이미 새 판으로 정해졌을 수 있으니 처음부터 다시 연다)
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: gate()));
      await settle(tester);
      expect(find.text('7수째'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('gate-resume')));
      await settle(tester);
      expect(find.text('이어한 판 7'), findsOneWidget);
    });

    testWidgets('새로 시작하면 보관된 판이 지워진다', (tester) async {
      await tester.runAsync(() => GameSave.write('g', {'n': 7}));
      await tester.pumpWidget(MaterialApp(home: gate()));
      await settle(tester);
      expect(find.textContaining('새로 시작하면 이어하던 시험 게임 판은 사라져요'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('gate-fresh')));
      await settle(tester);
      expect(find.text('새 판 화면'), findsOneWidget);
      expect(await tester.runAsync(() => GameSave.load('g')), isNull);
    });

    testWidgets('되살릴 수 없는 저장은 버리고 새 판으로 간다', (tester) async {
      await tester.runAsync(() => GameSave.write('g', {'n': 1, 'bad': true}));
      await tester.pumpWidget(MaterialApp(home: gate()));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('gate-resume')));
      await settle(tester);
      expect(find.text('새 판 화면'), findsOneWidget);
      expect(await tester.runAsync(() => GameSave.load('g')), isNull);
    });
  });
}
