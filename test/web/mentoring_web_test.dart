// 멘토링 웹판이 브라우저에서 도는지 확인하는 시험.
// 웹에서 돌리기: flutter test --platform chrome --dart-define=MENTORING_ONLY=true test/web
// (보통 테스트처럼 PC에서 돌려도 통과한다)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/app.dart';
import 'package:tabgame/core/game_filter.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/game_registry.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_lesson_screen.dart';
import 'package:tabgame/games/park/ui/park_lesson_screen.dart';
import 'package:tabgame/games/stones/ui/stones_lesson_screen.dart';
import 'package:tabgame/hub/game_card.dart';

void main() {
  late Settings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await Settings.load();
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SettingsScope(settings: settings, child: MaterialApp(home: home)));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('첫 화면: 멘토링 게임이 모두 보인다 (웹판이면 그 4개만)', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TabGameApp(settings: settings));
    await tester.pump(const Duration(milliseconds: 300));
    final ids = {for (final c in tester.widgetList<GameCard>(find.byType(GameCard, skipOffstage: false))) c.game.id};
    // (바둑돌 옮기기·공원 길찾기는 맨 밑 작은 아이콘이라 카드가 아니다)
    expect(ids.containsAll(GameFilter.mentoringGames.difference(GameFilter.mentoringOnlyGames)), isTrue);
    expect(find.byKey(const ValueKey('hub-mentoring-shelf'), skipOffstage: false), findsOneWidget);
    if (kMentoringOnly) expect(allGames.map((g) => g.id).toSet(), GameFilter.mentoringGames);
    expect(tester.takeException(), isNull);
  });

  for (final id in GameFilter.mentoringGames) {
    testWidgets('$id: CPU 대결(혼자 하기)로 시작해서 몇 수 진행된다', (tester) async {
      final game = allGames.firstWhere((g) => g.id == id);
      final mode = game.modes.contains(PlayMode.vsCpu) ? PlayMode.vsCpu : PlayMode.solo;
      await pump(tester, Builder(builder: (context) => game.builder!(context, mode)));
      for (final start in ['시작하기', '내가 갑(흰 돌)']) {
        final f = find.text(start);
        if (f.evaluate().isNotEmpty) {
          await tester.ensureVisible(f.first);
          await tester.tap(f.first);
          break;
        }
      }
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final (name, screen) in [
    ('바둑돌 옮기기', const StonesLessonScreen() as Widget),
    ('공원 길찾기', const ParkLessonScreen()),
    ('민들레', const DandelionLessonScreen()),
  ]) {
    testWidgets('$name 교과학습 첫 단원이 열린다', (tester) async {
      await pump(tester, screen);
      await tester.tap(find.textContaining('1. ').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
