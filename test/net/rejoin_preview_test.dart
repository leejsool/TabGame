import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/hub/hub_screen.dart';
import 'package:tabgame/net/lan_connection.dart';
import 'package:tabgame/net/lan_stall_overlay.dart';

import '../support/preview_kit.dart';

/// 방 다시 들어가기 화면들을 PNG로 찍는다. `REJOIN_PREVIEW_DIR`이 정해져 있을 때만 파일을 만든다 (평소에는 화면이 깨지지 않는지만 본다).
///   $env:REJOIN_PREVIEW_DIR='F:\MyApp\tools\tmp\rejoin'; powershell -ExecutionPolicy Bypass -File tool/test.ps1 test/net/rejoin_preview_test.dart
void main() {
  final outDir = Platform.environment['REJOIN_PREVIEW_DIR'];

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
    if (outDir != null) Directory(outDir).createSync(recursive: true);
  });

  Future<void> shoot(WidgetTester tester, GlobalKey key, String name, Size size) async {
    if (outDir == null) return;
    await savePng(tester, await captureBoundary(tester, key), '$outDir/${name}_${size.width.toInt()}x${size.height.toInt()}.png');
  }

  for (final e in kPreviewSizes.entries) {
    testWidgets('허브의 "다시 들어가기" 카드 (${e.key})', (tester) async {
      final key = GlobalKey();
      SharedPreferences.setMockInitialValues({
        'lan.rejoin': jsonEncode([
          {'game': 'rummikub', 'roomId': 'a', 'token': 't', 'host': '192.168.0.10', 'port': 45822, 'hostNick': '철수', 'savedAt': DateTime.now().millisecondsSinceEpoch},
          {'game': 'quoridor', 'roomId': 'b', 'token': 't', 'host': '192.168.0.10', 'port': 45822, 'hostNick': '영희', 'savedAt': DateTime.now().millisecondsSinceEpoch},
        ]),
      });
      final settings = await Settings.load();
      tester.view.physicalSize = e.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: RepaintBoundary(key: key, child: MaterialApp(theme: previewTheme(Brightness.light), home: HubScreen(settings: settings))),
      ));
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(find.text('하던 루미큐브 방이 있어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await shoot(tester, key, 'hub_card', e.value);
    });

    testWidgets('기다림 안내: 기다리는 중 / 고르기(CPU 대신하기) / CPU가 대신하는 중 (${e.key})', (tester) async {
      tester.view.physicalSize = e.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final conns = <LanConnection>[];
      final raws = <Socket>[];
      late ServerSocket server;
      await tester.runAsync(() async {
        server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final incoming = server.asBroadcastStream();
        for (final nick in ['민수', '지아', '철수']) {
          final accepted = incoming.first;
          raws.add(await Socket.connect(InternetAddress.loopbackIPv4, server.port));
          final c = LanConnection(await accepted, heartbeat: const Duration(milliseconds: 30), timeout: const Duration(milliseconds: 300));
          c.peer = {'nick': nick};
          c.canResume = () => true;
          conns.add(c);
        }
        raws[0].destroy(); // 민수는 앱을 껐다 (나간 상태)
        await Future<void>.delayed(const Duration(milliseconds: 700)); // 지아는 조용하다 (응답 없음)
      });
      raws[2].write('{"t":"x"}\n'); // 철수는 신호가 계속 온다고 보지만 아래에서 CPU가 대신하는 중으로 바꾼다
      conns[2].onTakeOver = () {};
      conns[2].cpuCovered = true;
      conns[1].onTakeOver = () {};
      conns[0].onTakeOver = () {};

      Future<void> pumpOverlay(Duration decisionAfter) async {
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: previewTheme(Brightness.light),
            builder: (context, child) => LanStallOverlay(decisionAfter: decisionAfter, child: child!),
            home: const Scaffold(body: Center(child: Text('게임 화면'))),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        await shoot(tester, key, decisionAfter == Duration.zero ? 'stall_decide' : 'stall_wait', e.value);
      }

      await pumpOverlay(const Duration(hours: 1));
      expect(find.textContaining('님이 나갔어요'), findsOneWidget);
      expect(find.text('CPU가 대신하기'), findsNothing);
      await pumpOverlay(Duration.zero);
      expect(find.text('CPU가 대신하기'), findsWidgets);
      expect(find.textContaining('철수 자리는 CPU가 대신하고 있어요'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        for (final c in conns) {
          await c.close();
        }
        for (final r in raws) {
          r.destroy();
        }
        await server.close();
      });
    });
  }
}
