import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/net/lan_rejoin_flow.dart';
import 'package:tabgame/net/lan_screens.dart';

/// 방 찾기 화면의 "하던 방이 있어요" 카드: 이미 시작한 방은 방 목록에 안 보이니, 받아 둔 표가 있으면 여기서 바로 다시 들어가게 한다.
void main() {
  Future<void> pumpJoin(WidgetTester tester, String game) async {
    final settings = await Settings.load();
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(
        home: LanJoinScreen(
          game: game,
          color: Colors.brown,
          roomTitle: (r) => '방',
          roomSubtitle: (r) => '',
          discoveryPort: 46391,
          buildGame: (m, conn) => null,
        ),
      ),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  RejoinTicket ticket(String game) => RejoinTicket(
        game: game,
        roomId: 'abcd',
        token: 'ef01',
        host: '192.168.0.37',
        port: 45822,
        hostNick: '방장',
        savedAt: DateTime.now().millisecondsSinceEpoch,
      );

  testWidgets('하던 방의 표가 있으면 방 찾기 화면 맨 위에 "다시 들어가기" 카드가 방 번호와 함께 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => RejoinTickets.save(ticket('rummikub')));
    await pumpJoin(tester, 'rummikub');
    expect(find.byKey(const ValueKey('rejoin-room')), findsOneWidget);
    expect(find.text('하던 방이 있어요'), findsOneWidget);
    expect(find.textContaining('37번'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '다시 들어가기'), findsOneWidget);
  });

  testWidgets('표가 없거나 다른 게임의 표면 카드가 없다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => RejoinTickets.save(ticket('quoridor')));
    await pumpJoin(tester, 'rummikub');
    expect(find.byKey(const ValueKey('rejoin-room')), findsNothing);
  });
}
