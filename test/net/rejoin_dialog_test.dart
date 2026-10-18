import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/net/lan_rejoin_flow.dart';

Future<void> pumpAsk(WidgetTester tester, {required bool withTicket, required void Function(LanOffer) onResult}) async {
  SharedPreferences.setMockInitialValues({
    if (withTicket)
      'lan.rejoin': jsonEncode([
        {'game': 'rj', 'roomId': 'abc', 'token': 'tok', 'host': '127.0.0.1', 'port': 9, 'hostNick': '철수', 'savedAt': DateTime.now().millisecondsSinceEpoch},
      ]),
  });
  final settings = await Settings.load();
  await tester.pumpWidget(SettingsScope(
    settings: settings,
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async => onResult(await lanOfferRejoin(context, game: 'rj', build: (resume, conn) => null)),
              child: const Text('끊겼다'),
            ),
          ),
        ),
      ),
    ),
  ));
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  testWidgets('표가 없으면 묻지 않고 평소의 끊김 안내로 넘어가게 한다', (tester) async {
    LanOffer? result;
    await pumpAsk(tester, withTicket: false, onResult: (r) => result = r);
    await tester.tap(find.text('끊겼다'));
    await settle(tester);
    expect(result, LanOffer.unavailable);
    expect(find.text('다시 들어가기'), findsNothing);
  });

  testWidgets('표가 있으면 "다시 들어가기 / 나가기"를 묻고, 나가기를 고르면 표를 버린다', (tester) async {
    LanOffer? result;
    await pumpAsk(tester, withTicket: true, onResult: (r) => result = r);
    await tester.tap(find.text('끊겼다'));
    await settle(tester);
    expect(find.text('연결이 끊겼어요'), findsOneWidget);
    expect(find.text('다시 들어가기'), findsOneWidget);
    await tester.tap(find.text('나가기'));
    await settle(tester);
    expect(result, LanOffer.declined);
    expect(await tester.runAsync(() => RejoinTickets.of('rj')), isNull, reason: '일부러 나갔으니 "다시 들어가기" 표를 남기면 안 돼요');
  });
}
