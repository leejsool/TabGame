import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/game_registry.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/sprouts/core/sprouts_board.dart';
import 'package:tabgame/games/sprouts/core/sprouts_geometry.dart';
import 'package:tabgame/games/sprouts/core/sprouts_planner.dart';
import 'package:tabgame/games/sprouts/data/sprouts_history.dart';
import 'package:tabgame/games/sprouts/game/sprouts_controller.dart';
import 'package:tabgame/games/sprouts/sprouts_entry.dart';
import 'package:tabgame/games/sprouts/ui/sprouts_painter.dart';
import 'package:tabgame/games/sprouts/ui/sprouts_records_tab.dart';
import 'package:tabgame/games/sprouts/ui/sprouts_screen.dart';
import 'package:tabgame/games/sprouts/ui/sprouts_setup_screen.dart';
import 'package:tabgame/games/sprouts/ui/sprouts_wifi_screen.dart';
import 'package:tabgame/net/lan_connection.dart';

Future<Widget> app(Widget home) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  return SettingsScope(
    settings: settings,
    child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: home),
  );
}

Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<(LanConnection, LanConnection)> connectionPair() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final accepted = server.first;
  final client = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
  final srv = await accepted;
  await server.close();
  return (LanConnection(client), LanConnection(srv));
}

SproutsBoard copyOf(SproutsBoard b) => SproutsBoard.fromData(b.toData());

SproutsController wifiController(SproutsBoard board, int side) =>
    SproutsController(mode: PlayMode.wifi, dotCount: board.dots.length, humanSide: side, board: copyOf(board));

/// 두 기기의 컨트롤러를 서로 이어 준다 (네트워크 대신 직접).
(SproutsController, SproutsController) wiredPair(SproutsBoard board) {
  final a = wifiController(board, 0), b = wifiController(board, 1);
  a.onSync = (s) => expect(b.receiveSync(s), isTrue, reason: 'b가 a의 판을 받지 못했어요 (${s.kind} ${s.moveCount})');
  b.onSync = (s) => expect(a.receiveSync(s), isTrue, reason: 'a가 b의 판을 받지 못했어요 (${s.kind} ${s.moveCount})');
  return (a, b);
}

/// 지금 차례인 컨트롤러가 둘 수 있는 수 하나를 (손으로 긋듯) 둔다. 둘 수 없으면 false.
bool playOne(SproutsController c, Random rng) {
  final moves = findMoves(c.board, allowRelax: false)..shuffle(rng);
  for (final m in moves.take(6)) {
    if (c.tryStroke(m.path)) return true;
  }
  return false;
}

/// 점 두 개를 구불구불한 선 하나로 잇는다 (선 정리하기가 펼 수 있게).
List<P> wiggle(P a, P c) {
  return [
    for (var i = 0; i <= 120; i++)
      P(a.x + (c.x - a.x) * i / 120, a.y + (c.y - a.y) * i / 120 + 40 * sin(pi * i / 120) * sin(i / 4.5)),
  ];
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('NanumGothic');
    for (final f in ['Regular', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
    }
    await loader.load();
  });

  group('Wi‑Fi 대결 판 맞추기', () {
    test('두 기기가 번갈아 두며 판을 주고받아 끝까지 가면 판·차례·결과가 늘 똑같다', () {
      for (var seed = 1; seed <= 4; seed++) {
        final rng = Random(seed);
        final (a, b) = wiredPair(SproutsBoard.initial(2 + seed % 3, rng));
        var moves = 0;
        while (!a.isOver && moves < 40) {
          final mover = a.turn == 0 ? a : b;
          final other = identical(mover, a) ? b : a;
          expect(mover.humanCanAct, isTrue);
          expect(other.humanCanAct, isFalse, reason: '상대 차례에는 못 긋는다');
          if (!playOne(mover, rng)) break;
          moves++;
          expect(other.board.toData(), mover.board.toData(), reason: 'seed=$seed 수=$moves 판이 달라요');
          expect((other.turn, other.moveCount, other.winner), (mover.turn, mover.moveCount, mover.winner));
          expect(other.lastRemote, isTrue);
          expect(other.lastByHuman, isFalse);
          expect(mover.lastRemote, isFalse);
        }
        expect(a.isOver, isTrue, reason: 'seed=$seed: 판이 끝나야 해요');
        expect(b.isOver, isTrue);
        expect(a.winner, b.winner);
        expect(a.moveCount, b.moveCount);
      }
    });

    test('차례가 아니거나 수가 안 맞거나 선이 가로지르는 판은 받지 않는다', () {
      final rng = Random(3);
      final base = SproutsBoard.initial(3, rng);
      final (a, b) = wiredPair(base);
      expect(playOne(a, rng), isTrue);
      final good = SproutsSync(kind: 'move', moveCount: 1, data: a.board.toData());

      // 내 차례(b)에 보낸 판은 받지 않는다 (같은 판을 한 번 더 보내면 이미 받았으니 어긋난 것)
      expect(b.receiveSync(good), isFalse);
      // a가 자기 차례가 아닌데 받는 일도 없다
      final fresh = wifiController(base, 0);
      expect(fresh.receiveSync(good), isFalse, reason: '내 차례(0)에 상대의 판이 오면 어긋난 것');
      // 새 컨트롤러(b 역할)로 하나씩 점검
      SproutsController other() => wifiController(base, 1)..turn = 0;
      expect(other().receiveSync(SproutsSync(kind: 'move', moveCount: 2, data: good.data)), isFalse, reason: '수 번호가 건너뜀');
      expect(other().receiveSync(SproutsSync(kind: 'bogus', moveCount: 1, data: good.data)), isFalse);
      expect(other().receiveSync(const SproutsSync(kind: 'move', moveCount: 1, data: [])), isFalse, reason: '깨진 판');
      expect(other().receiveSync(const SproutsSync(kind: 'move', moveCount: 1, data: [1, 2, 3])), isFalse, reason: '깨진 판');
      expect(other().receiveSync(good), isTrue); // 제대로 된 판은 받는다
      // 선이 가로지르는 판: 새 곡선을 다른 선 위로 뻗은 것으로 바꿔친다
      final crossing = copyOf(a.board);
      final last = crossing.curves.last;
      crossing.curves[crossing.curves.length - 1] =
          Curve(from: last.from, to: last.to, mid: last.mid, owner: last.owner, pts: [for (final p in last.pts) P(p.x, p.y), const P(1, 1)]);
      final tampered = copyOf(a.board);
      tampered.dots.add(Dot(const P(5, 5), 1)); // 점 수가 어긋난 판
      expect(other().receiveSync(SproutsSync(kind: 'move', moveCount: 1, data: tampered.toData())), isFalse);
      // 곡선의 주인이 틀린 판 (상대가 아니라 내가 그은 것으로 되어 있다)
      final wrongOwner = copyOf(a.board);
      final lc = wrongOwner.curves.last;
      wrongOwner.curves[wrongOwner.curves.length - 1] = Curve(from: lc.from, to: lc.to, mid: lc.mid, owner: 1, pts: lc.pts);
      expect(other().receiveSync(SproutsSync(kind: 'move', moveCount: 1, data: wrongOwner.toData())), isFalse);
    });

    test('되돌리기는 없고, 기권하면 상대의 승리로 끝난다', () {
      final rng = Random(5);
      final (a, b) = wiredPair(SproutsBoard.initial(3, rng));
      expect(playOne(a, rng), isTrue);
      expect(a.canUndo, isFalse);
      expect(b.canUndo, isFalse);
      expect(b.canResign, isTrue);
      expect(b.resign(), isTrue);
      expect(b.winner, 0); // 기권한 b가 졌다
      expect(b.resigned, isTrue);
      a.opponentResigned();
      expect(a.winner, 0);
      expect(a.resigned, isTrue);
      expect(a.isOver, isTrue);
    });

    test('선 정리하기는 내 차례에만 하고, 정리한 판이 상대에게도 가서 같아진다 (옮겨 가는 모습으로)', () async {
      final base = SproutsBoard([Dot(const P(60, 200), 3), Dot(const P(340, 200), 3), Dot(const P(200, 400), 3)], []);
      final (a, b) = wiredPair(base);
      expect(a.canTidy, isFalse, reason: '그은 선이 아직 없다');
      expect(a.tryStroke(wiggle(const P(60, 200), const P(340, 200))), isTrue);
      expect(a.canTidy, isFalse, reason: '이제 b 차례라 a는 정리할 수 없다');
      expect(b.canTidy, isTrue);
      expect(await b.tidy(), isTrue);
      expect(a.board.toData(), b.board.toData());
      expect(a.lastWasTidy, isTrue);
      expect(a.lastRemote, isTrue);
      expect(a.morphFrom, isNotNull); // 옮겨 가는 모습을 보여 줄 수 있다
      expect(a.moveCount, 1);
      expect(a.turn, b.turn);
      expect(a.notice, contains('정리'));
    });
  });

  group('상대가 그은 선을 보여 주는 연출', () {
    SproutsBoard oneCurve() {
      final b = SproutsBoard([Dot(const P(60, 200), 3), Dot(const P(340, 200), 3)], []);
      final r = b.validate(0, 1, wiggle(const P(60, 200), const P(340, 200)));
      b.apply(0, 1, r, 0);
      return b;
    }

    test('펜 끝·출발 점 물결·도착 점 물결을 포함해 그리는 도중에도 오류 없이 그려진다', () {
      final b = oneCurve();
      for (final (t, pop) in const [(0.0, 0.0), (0.1, 0.0), (0.5, 0.0), (0.99, 0.0), (1.0, 0.0), (1.0, 0.4), (1.0, 1.0)]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        SproutsPainter(board: b, remoteCue: true, lastCurveT: t, popT: pop).paint(canvas, const Size(360, 400));
        recorder.endRecording();
      }
    });

    test('연출을 켜면 펜 끝이 그려지고 끄면 안 그려진다 (그리는 도중 그림이 다르다)', () async {
      final b = oneCurve();
      Future<List<int>> shot(bool cue) async {
        final recorder = ui.PictureRecorder();
        SproutsPainter(board: b, remoteCue: cue, lastCurveT: 0.5, popT: 0).paint(Canvas(recorder), const Size(360, 400));
        final img = await recorder.endRecording().toImage(360, 400);
        return (await img.toByteData())!.buffer.asUint8List();
      }

      final on = (await shot(true)), off = (await shot(false));
      expect(on, isNot(off));
    });
  });

  group('Wi‑Fi 대결 화면', () {
    testWidgets('내 선은 판 전체로 상대에게 가고, 상대의 판이 오면 내 판이 바뀌며 내 차례가 된다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final rng = Random(8);
      final base = SproutsBoard.initial(3, rng);
      final received = <Map<String, dynamic>>[];
      theirs.messages.listen(received.add);
      final c = wifiController(base, 0);
      // 상대 기기의 컨트롤러 (같은 처음 판)
      final mirror = wifiController(base, 1);
      mirror.onSync = (s) => theirs.send({'t': 'board', 'k': s.kind, 'n': s.moveCount, 'd': s.data});
      await tester.pumpWidget(await app(SproutsScreen(mode: PlayMode.wifi, dotCount: 3, humanSide: 0, controller: c, link: mine, initialBoard: base)));
      await settle(tester, rounds: 2);
      expect(find.textContaining('나 차례'), findsOneWidget);

      expect(playOne(c, rng), isTrue);
      await settle(tester, rounds: 3);
      final msg = received.single;
      expect((msg['t'], msg['k'], msg['n']), ('board', 'move', 1));
      expect((msg['d'] as List).length, c.board.toData().length); // 판 전체가 간다
      expect(find.textContaining('상대가 선을 긋는 중'), findsOneWidget);
      expect(c.humanCanAct, isFalse);

      // 상대 기기가 같은 판을 받아 자기 선을 긋는다
      expect(mirror.receiveSync(SproutsSync(kind: 'move', moveCount: 1, data: [for (final v in msg['d'] as List) (v as num).toDouble()])), isTrue);
      expect(playOne(mirror, rng), isTrue);
      await settle(tester, rounds: 3);
      expect(c.moveCount, 2);
      expect(c.turn, 0);
      expect(c.lastRemote, isTrue);
      expect(find.textContaining('나 차례'), findsOneWidget);
      // 상대의 선이 천천히 그려지는 동안과 끝난 뒤 모두 오류가 없다
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull);
      expect(find.text('되돌리기'), findsNothing);
      expect(find.text('새 판'), findsNothing);
      expect(find.text('기권'), findsOneWidget);
      expect(find.text('선 정리하기'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });

    testWidgets('어긋난 판이 오면 알리고 나간다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final base = SproutsBoard.initial(3, Random(2));
      final c = wifiController(base, 0);
      await tester.pumpWidget(await app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => SproutsScreen(mode: PlayMode.wifi, dotCount: 3, humanSide: 0, controller: c, link: mine, initialBoard: base),
              )),
              child: const Text('열기'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('열기'));
      await settle(tester, rounds: 3);
      theirs.send({'t': 'board', 'k': 'move', 'n': 1, 'd': base.toData()}); // 내 차례에 온 판
      await settle(tester, rounds: 4);
      expect(find.text('판이 서로 어긋났어요'), findsOneWidget);
      await tester.tap(find.text('나가기'));
      await settle(tester, rounds: 3);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(SproutsScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });

    testWidgets('상대가 기권하면 내 승리로 기록되고, 연결이 끊기면 알리고 기록하지 않는다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      for (final resign in [true, false]) {
        final (mine, theirs) = (await tester.runAsync(connectionPair))!;
        final rng = Random(4);
        final base = SproutsBoard.initial(3, rng);
        final c = wifiController(base, 0);
        await tester.pumpWidget(await app(SproutsScreen(mode: PlayMode.wifi, dotCount: 3, humanSide: 0, controller: c, link: mine, initialBoard: base)));
        await settle(tester, rounds: 2);
        expect(playOne(c, rng), isTrue);
        await settle(tester, rounds: 2);
        if (resign) {
          theirs.send(const {'t': 'resign'});
          await settle(tester, rounds: 4);
          expect(c.isOver, isTrue);
          expect(c.winner, 0);
          expect(find.textContaining('기권'), findsWidgets);
          final h = (await tester.runAsync(SproutsHistory.load))!;
          expect(h.length, 1);
          expect((h.single.online, h.single.resigned, h.single.winner, h.single.human), (true, true, 0, 0));
        } else {
          await tester.runAsync(theirs.close);
          await settle(tester, rounds: 6);
          expect(find.text('상대와 연결이 끊겼어요'), findsWidgets);
          expect(find.text('나가기'), findsOneWidget);
          expect((await tester.runAsync(SproutsHistory.load))!, isEmpty);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(theirs.close);
        await settle(tester, rounds: 1);
      }
    });

    testWidgets('한 판 더: 방을 연 쪽이 새 처음 판을 보내고, 두 기기가 같은 판에서 먼저/나중을 바꿔 시작한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      for (final host in [true, false]) {
        final (mine, theirs) = (await tester.runAsync(connectionPair))!;
        final rng = Random(6);
        final base = SproutsBoard.initial(3, rng);
        final received = <Map<String, dynamic>>[];
        theirs.messages.listen(received.add);
        final c = wifiController(base, 0);
        await tester.pumpWidget(await app(SproutsScreen(mode: PlayMode.wifi, dotCount: 3, humanSide: 0, controller: c, link: mine, isHost: host, initialBoard: base)));
        await settle(tester, rounds: 2);
        expect(playOne(c, rng), isTrue);
        theirs.send(const {'t': 'resign'}); // 상대 기권으로 판을 끝낸다
        await settle(tester, rounds: 4);
        expect(c.isOver, isTrue);

        await tester.tap(find.widgetWithText(FilledButton, '한 판 더'));
        await settle(tester, rounds: 3);
        expect(find.text('상대를 기다려요…'), findsOneWidget);
        expect(received.where((m) => m['t'] == 'again').length, 1);

        if (host) {
          theirs.send(const {'t': 'again'}); // 상대도 원한다 → 방을 연 쪽이 새 판을 보낸다
          await settle(tester, rounds: 4);
          final nb = received.firstWhere((m) => m['t'] == 'newboard');
          expect((nb['d'] as List).length, greaterThan(10));
        } else {
          // 새 판은 방을 연 쪽에서 온다
          final fresh = SproutsBoard.initial(3, Random(77));
          theirs.send({'t': 'newboard', 'd': fresh.toData()});
          await settle(tester, rounds: 4);
        }
        final state = tester.state(find.byType(SproutsScreen));
        expect(state, isNotNull);
        expect(find.textContaining('상대가 선을 긋는 중'), findsOneWidget, reason: 'host=$host: 먼저/나중이 바뀌어 이번에는 상대가 먼저예요');
        expect(find.text('기권'), findsOneWidget);
        expect(find.text('한 판 더'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(theirs.close);
        await settle(tester, rounds: 1);
      }
    });
  });

  group('Wi‑Fi 대결 기록', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('Wi‑Fi 대결 표시와 내 쪽이 저장되고, 이겼는지는 내 쪽으로 판단한다', () async {
      await SproutsHistory.add(const SproutsRecord(at: 1, vsCpu: false, online: true, winner: 0, moves: 9, dots: 3, human: 1));
      final list = await SproutsHistory.load();
      expect(list.single.online, isTrue);
      expect(list.single.onlineWon, isFalse);
      expect(list.single.humanWon, isNull);
      expect(const SproutsRecord(at: 2, vsCpu: false, winner: 0, moves: 3, dots: 3).online, isFalse);
    });

    testWidgets('기록 보드에 Wi‑Fi 대결 결과가 이겼어요/졌어요로 보이고, 플레이어 1·2 승 요약과 따로 센다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final recs = [
        const SproutsRecord(at: 1760000000000, vsCpu: false, online: true, winner: 0, moves: 9, dots: 3, human: 0),
        const SproutsRecord(at: 1760000100000, vsCpu: false, online: true, winner: 0, moves: 11, dots: 4, human: 1),
        const SproutsRecord(at: 1760000200000, vsCpu: false, winner: 1, moves: 7, dots: 3),
      ];
      SharedPreferences.setMockInitialValues({'sprouts.history': jsonEncode([for (final r in recs.reversed) r.toJson()])});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: const Scaffold(body: SproutsRecordsTab())),
      ));
      await settle(tester, rounds: 4);
      expect(find.text('이겼어요 · Wi‑Fi 대결'), findsOneWidget);
      expect(find.text('졌어요 · Wi‑Fi 대결'), findsOneWidget);
      expect(find.text('Wi‑Fi 대결 승'), findsOneWidget);
      expect(find.text('플레이어 2 승'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('방 만들기·찾기 화면', () {
    test('등록: 콩나물에 Wi‑Fi 모드가 있다', () {
      final g = allGames.firstWhere((g) => g.id == 'sprouts');
      expect(g.modes, contains(PlayMode.wifi));
    });

    testWidgets('첫 화면에서 방 만들기를 누르면 점의 수와 내 쪽을 고르고 "방 열기"로 진행한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(await app(Builder(builder: (context) => buildSprouts(context, PlayMode.wifi))));
      await settle(tester, rounds: 2);
      expect(find.byType(SproutsWifiScreen), findsOneWidget);
      await tester.tap(find.text('방 만들기'));
      await settle(tester, rounds: 3);
      expect(find.byType(SproutsHostSetupScreen), findsOneWidget);
      expect(find.text('방 열기'), findsOneWidget);
      expect(find.text('처음 점의 수'), findsOneWidget);
      expect(find.text('무작위'), findsOneWidget);
      expect(find.text('CPU 난이도'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('방을 열면 기다리는 화면이 뜨고, 방 찾기에서 들어가면 두 화면이 똑같은 처음 판에서 서로 다른 쪽으로 시작한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      const discovery = 45971;
      final navKey = GlobalKey<NavigatorState>();
      SharedPreferences.setMockInitialValues({});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(
          navigatorKey: navKey,
          theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'),
          home: const Scaffold(body: SizedBox()),
        ),
      ));
      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const SproutsHostScreen(dots: 4, hostSide: 1, gamePort: 0, discoveryPort: discovery),
      )));
      await settle(tester, rounds: 4);
      expect(find.text('방이 열렸어요'), findsOneWidget);
      expect(find.text('처음 점 4개'), findsOneWidget);
      expect(find.text('내가 나중에 시작 (분홍 선)'), findsOneWidget);
      expect(find.text('우리 방 이름 (내 별명)'), findsOneWidget);

      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const SproutsJoinScreen(discoveryPort: discovery, extraTargets: ['127.0.0.1']),
      )));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await settle(tester, rounds: 6);
      expect(find.text('처음 점 4개'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, '들어가기').first);
      await settle(tester, rounds: 12);
      final screens = tester.widgetList<SproutsScreen>(find.byType(SproutsScreen, skipOffstage: false)).toList();
      expect(screens.length, 2);
      expect(screens.map((s) => s.humanSide).toSet(), {0, 1});
      expect(screens.map((s) => s.isHost).toSet(), {true, false});
      expect(screens.every((s) => s.mode == PlayMode.wifi && s.dotCount == 4), isTrue);
      // 두 화면의 처음 판이 한 점 어긋남 없이 같다
      expect(screens[0].initialBoard!.toData(), screens[1].initialBoard!.toData());
      expect(screens[0].initialBoard!.dots.length, 4);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await settle(tester, rounds: 3);
    });
  });
}
