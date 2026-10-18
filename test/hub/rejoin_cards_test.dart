import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/hub/hub_screen.dart';

Map<String, dynamic> ticket(String game, {String hostNick = '철수', Duration age = Duration.zero}) => {
      'game': game,
      'roomId': 'abc',
      'token': 'tok',
      'host': '192.168.0.10',
      'port': 45822,
      'hostNick': hostNick,
      'savedAt': DateTime.now().subtract(age).millisecondsSinceEpoch,
    };

Future<void> pumpHub(WidgetTester tester, List<Map<String, dynamic>> tickets) async {
  SharedPreferences.setMockInitialValues({if (tickets.isNotEmpty) 'lan.rejoin': jsonEncode(tickets)});
  final settings = await Settings.load();
  tester.view.physicalSize = const Size(800, 1280);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(SettingsScope(settings: settings, child: MaterialApp(home: HubScreen(settings: settings))));
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  testWidgets('받아 둔 표가 있으면 허브 맨 위에 "다시 들어가기" 카드가 뜨고, 잊기를 누르면 사라진다', (tester) async {
    await pumpHub(tester, [ticket('rummikub')]);
    expect(find.text('하던 루미큐브 방이 있어요'), findsOneWidget);
    expect(find.textContaining('철수 님이 연 방'), findsOneWidget);
    expect(find.text('다시 들어가기'), findsOneWidget);

    await tester.tap(find.byTooltip('이 방 잊기'));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(find.text('하던 루미큐브 방이 있어요'), findsNothing);
  });

  testWidgets('표가 없거나 너무 오래됐거나 다시 들어가기를 지원하지 않는 게임이면 카드가 없다', (tester) async {
    await pumpHub(tester, [ticket('rummikub', age: const Duration(hours: 13)), ticket('uttt_unknown')]);
    expect(find.textContaining('방이 있어요'), findsNothing);
    expect(find.text('다시 들어가기'), findsNothing);
  });

  testWidgets('여러 게임의 표가 있으면 카드도 게임마다 하나씩', (tester) async {
    await pumpHub(tester, [ticket('quoridor'), ticket('davinci_code', hostNick: '영희')]);
    expect(find.text('하던 쿼리도 방이 있어요'), findsOneWidget);
    expect(find.text('하던 다빈치 코드 방이 있어요'), findsOneWidget);
    expect(find.text('다시 들어가기'), findsNWidgets(2));
  });
}
