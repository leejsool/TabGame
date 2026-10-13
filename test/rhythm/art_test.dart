import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/rhythm/ui/rhythm_art.dart';

void main() {
  testWidgets('그림 모음: 슬라임(파랑·빨강) 네 자세와 옆으로 휘두르는 검사 그림이 모두 불러와진다', (tester) async {
    final art = (await tester.runAsync(RhythmArt.load))!;
    for (final red in [false, true]) {
      for (final kind in ['idle', 'ready', 'attack', 'hit']) {
        final name = RhythmArt.slimeSprite(kind, red: red);
        expect(art.image(name), isNotNull, reason: name);
        final info = art.info(name);
        expect(info, isNotNull, reason: name);
        expect(info!.footY, greaterThan(0), reason: '$name 바닥 위치');
      }
    }
    // 빨간 슬라임은 같은 자세의 파란 슬라임과 크기·기준점이 같다 (색만 다르다)
    for (final kind in ['idle', 'ready', 'attack', 'hit']) {
      final blue = art.info(RhythmArt.slimeSprite(kind))!;
      final red = art.info(RhythmArt.slimeSprite(kind, red: true))!;
      expect((red.w, red.h, red.footX, red.footY), (blue.w, blue.h, blue.footX, blue.footY), reason: kind);
    }
    // 철검 그림(3·4코스): 원래(목검) 그림과 크기·발 위치가 같다
    for (var i = 0; i < 4; i++) {
      for (final kind in RhythmArt.ironKinds) {
        final iron = RhythmArt.actorSprite(i, kind, iron: true);
        expect(iron, endsWith('_iron'));
        expect(art.image(iron), isNotNull, reason: iron);
        final base = art.info(RhythmArt.actorSprite(i, kind))!;
        final info = art.info(iron)!;
        expect((info.w, info.h, info.footX, info.footY, info.scale), (base.w, base.h, base.footX, base.footY, base.scale), reason: iron);
      }
      // 옆으로 휘두르는 그림은 철검이 따로 없다 (처음부터 철검)
      expect(RhythmArt.actorSprite(i, 'side_swing', iron: true), RhythmArt.actorSprite(i, 'side_swing'));
    }
    expect(art.image('bg_forest'), isNotNull);
    for (var i = 0; i < 4; i++) {
      for (final kind in ['side_ready', 'side_swing']) {
        expect(art.image(RhythmArt.actorSprite(i, kind)), isNotNull, reason: '$i $kind');
        expect(art.info(RhythmArt.actorSprite(i, kind)), isNotNull);
      }
    }
  });
}
