import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/sudoku/tutorial/technique_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/app.dart';
import 'package:tabgame/core/game_registry.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/tutorial/tutorial_progress.dart';
import 'package:tabgame/tutorial/tutorial_screen.dart';

Future<Settings> _start(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  final settings = await Settings.load();
  await tester.pumpWidget(TabGameApp(settings: settings));
  await tester.pumpAndSettle();
  return settings;
}

void main() {
  // 앱과 같은 글꼴로 그려야 글자 줄바꿈이 실제와 같다.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('NanumGothic');
    for (final f in ['Regular', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
    }
    await loader.load();
  });

  group('준비된 모든 게임에는 게임 방법이 있다', () {
    test('허브에 오른 게임마다 튜토리얼이 연결돼 있다', () {
      for (final g in allGames.where((g) => g.isReady)) {
        final t = g.tutorial?.call();
        expect(t, isNotNull, reason: '${g.title}에 튜토리얼이 없어요');
        // 슬라이드형이면 한 장 이상, 직접 만든 화면이면 builder가 있어야 한다
        expect(t!.steps.isNotEmpty || t.builder != null, isTrue, reason: g.title);
      }
    });

    for (final g in allGames.where((g) => g.isReady && g.tutorial != null)) {
      final t = g.tutorial!();
      if (t.builder != null) continue;
      testWidgets('${g.title} 튜토리얼 슬라이드가 끝까지 넘어간다 (폰 세로·가로)', (tester) async {
        for (final (size, scale) in const [
          (Size(360, 740), 1.0),
          (Size(360, 640), 1.6), // 작은 폰 + 큰 글자
          (Size(900, 420), 1.0),
          (Size(1280, 800), 1.0),
        ]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: TutorialScreen(tutorial: t, firstTime: true),
            ),
          );
          for (var i = 0; i < t.steps.length; i++) {
            expect(find.text(t.steps[i].title), findsOneWidget, reason: '${g.title} $size x$scale ${i + 1}장');
            expect(tester.takeException(), isNull, reason: '${g.title} $size x$scale ${i + 1}장');
            if (i < t.steps.length - 1) {
              await tester.tap(find.text('다음'));
              // 그림에 끝없이 반복되는 애니메이션이 있어서 pumpAndSettle은 쓰지 않는다
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 400));
            }
          }
          expect(find.text('게임 시작하기'), findsOneWidget);
          expect(find.text('건너뛰기'), findsNothing, reason: '마지막 장에서는 건너뛰기가 필요 없어요');
        }
      });
    }
  });

  group('처음 열 때 안내', () {
    testWidgets('처음 한 번만 뜨고, 건너뛰면 게임으로 들어간다', (tester) async {
      await _start(tester);
      await tester.tap(find.text('솔리테어'));
      await tester.pumpAndSettle();
      expect(find.text('솔리테어 게임 방법'), findsOneWidget);
      expect(find.text('건너뛰기'), findsOneWidget);

      await tester.tap(find.text('건너뛰기'));
      await tester.pumpAndSettle();
      expect(find.text('솔리테어 게임 방법'), findsNothing);
      expect(find.byTooltip('게임 방법'), findsOneWidget, reason: '메뉴에서 다시 볼 수 있어야 해요');
      expect(await TutorialProgress.isSeen('solitaire'), isTrue);

      // 허브로 돌아가 다시 열면 이번엔 바로 메뉴
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('솔리테어'));
      await tester.pumpAndSettle();
      expect(find.text('솔리테어 게임 방법'), findsNothing);
      expect(find.byTooltip('게임 방법'), findsOneWidget);
    });

    testWidgets('끝까지 보면 "게임 시작하기"로 게임으로 들어간다', (tester) async {
      await _start(tester);
      await tester.tap(find.text('프리셀'));
      await tester.pumpAndSettle();
      final t = allGames.firstWhere((g) => g.id == 'freecell').tutorial!();
      for (var i = 0; i < t.steps.length - 1; i++) {
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('게임 시작하기'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('게임 방법'), findsOneWidget);
    });

    testWidgets('설정에서 끄면 뜨지 않는다', (tester) async {
      await _start(tester, prefs: {'showTutorials': false});
      await tester.tap(find.text('지뢰찾기'));
      await tester.pumpAndSettle();
      expect(find.text('지뢰찾기 게임 방법'), findsNothing);
      expect(find.byTooltip('게임 방법'), findsOneWidget);
    });

    testWidgets('이미 본 게임은 뜨지 않고, 초기화하면 다시 뜬다', (tester) async {
      await _start(tester, prefs: {
        'tutorialSeen': ['jigsaw'],
      });
      await tester.tap(find.text('직소퍼즐'));
      await tester.pumpAndSettle();
      expect(find.text('직소퍼즐 게임 방법'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await TutorialProgress.resetSeen();
      await tester.tap(find.text('직소퍼즐'));
      await tester.pumpAndSettle();
      expect(find.text('직소퍼즐 게임 방법'), findsOneWidget);
    });

    testWidgets('스도쿠는 처음 열면 기본 규칙 튜토리얼(직접 해 보기)이 뜬다', (tester) async {
      await _start(tester);
      await tester.tap(find.text('스도쿠'));
      await tester.pumpAndSettle();
      expect(find.text('스도쿠 기본 규칙'), findsOneWidget);
      expect(find.text('스도쿠는 이런 퍼즐이에요'), findsOneWidget);
      await tester.tap(find.text('건너뛰기'));
      await tester.pumpAndSettle();
      // 메뉴에는 난이도와 함께 배우기 항목이 보인다
      expect(find.text('새 게임'), findsOneWidget);
      expect(find.text('배우기'), findsOneWidget);
      expect(find.text('기본 규칙 배우기'), findsOneWidget);
      expect(find.text('심화 기술 연습'), findsOneWidget);
    });

    testWidgets('스도쿠 메뉴에서 심화 기술 연습 목록을 열 수 있다', (tester) async {
      await _start(tester, prefs: {
        'tutorialSeen': ['sudoku'],
      });
      await tester.tap(find.text('스도쿠'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('심화 기술 연습'));
      await tester.tap(find.text('심화 기술 연습'));
      await tester.pumpAndSettle();
      expect(find.text('네이키드 싱글'), findsOneWidget);
      expect(find.text('Lv.1 기본 기술 (쉬움)'), findsOneWidget);
    });

    testWidgets('스도쿠 메뉴의 배우기 카드에 마친 항목은 체크가 붙는다', (tester) async {
      await _start(tester, prefs: {
        'tutorialSeen': ['sudoku'],
        'tutorialDone': ['sudoku_basic', 'sudoku_xWing', 'sudoku_pointing'],
      });
      await tester.tap(find.text('스도쿠'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('심화 기술 연습'));
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget, reason: '기본 규칙을 마쳤어요');
      expect(find.textContaining('2 / ${kTechniqueInfos.length} 완료'), findsOneWidget);
    });

    testWidgets('설정 화면의 스위치와 다시 받기 버튼', (tester) async {
      final settings = await _start(tester, prefs: {
        'tutorialSeen': ['jigsaw', 'freecell'],
      });
      await tester.tap(find.byTooltip('설정'));
      await tester.pumpAndSettle();
      expect(find.text('게임 방법 안내'), findsOneWidget);
      await tester.tap(find.text('게임 방법 안내'));
      await tester.pumpAndSettle();
      expect(settings.showTutorials, isFalse);
      await tester.tap(find.text('게임 방법 안내 다시 받기'));
      await tester.pumpAndSettle();
      expect(await TutorialProgress.isSeen('jigsaw'), isFalse);
      expect(await TutorialProgress.isSeen('freecell'), isFalse);
    });
  });
}
