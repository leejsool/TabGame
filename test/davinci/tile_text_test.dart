import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/davinci/core/davinci_rules.dart';
import 'package:tabgame/games/davinci/ui/davinci_tiles.dart';

void main() {
  testWidgets('두 자리 숫자(10, 11)는 어떤 타일 폭에서도 한 줄로 보인다 (날아가는 중의 작은 타일 포함)', (tester) async {
    for (final width in [18.0, 24.0, 30.0, 44.0, 60.0]) {
      for (final id in [dvTile(0, 11), dvTile(1, 10)]) {
        for (final lying in [false, true]) {
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'),
            home: Scaffold(
              body: Center(child: DvTile(id: id, width: width, faceUp: true, lying: lying)),
            ),
          ));
          final label = '${dvNumber(id)}';
          final text = find.text(label);
          expect(text, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(text);
          final fontSize = width * (lying ? 0.58 : 0.66);
          // 한 줄이면 높이가 글자 크기(줄 높이 1.0) 안팎이다. 두 줄로 꺾이면 그 두 배가 된다.
          expect(paragraph.size.height, lessThan(fontSize * 1.5), reason: '폭 $width, $label: 줄이 바뀌었어요');
          // 타일 밖으로 넘치지 않는다
          final box = tester.getRect(text);
          final tile = tester.getRect(find.byType(DvTile));
          expect(box.width, lessThanOrEqualTo(tile.width), reason: '폭 $width, $label: 타일보다 넓어요');
        }
      }
    }
  });
}
