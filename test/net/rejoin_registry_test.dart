import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/game_registry.dart';

void main() {
  test('같은 Wi‑Fi로 함께 하는 게임은 모두 "나갔다 다시 들어오기"를 지원한다 (새 게임도 빠뜨리지 않게)', () {
    final wifiGames = [for (final g in allGames) if (g.isReady && g.modes.contains(PlayMode.wifi)) g];
    expect(wifiGames, isNotEmpty);
    for (final g in wifiGames) {
      expect(g.lanGame, isNotNull, reason: '${g.title}: GameInfo.lanGame(같은 Wi‑Fi에서 쓰는 게임 이름)을 채워 주세요 (README 새 게임 체크리스트 5번)');
      expect(g.lanResume, isNotNull, reason: '${g.title}: GameInfo.lanResume(받은 판의 모습으로 화면 만들기)을 채워 주세요 (README 새 게임 체크리스트 5번)');
    }
    final names = [for (final g in wifiGames) g.lanGame];
    expect(names.toSet().length, names.length, reason: '같은 Wi‑Fi 게임 이름이 겹쳐요');
  });
}
