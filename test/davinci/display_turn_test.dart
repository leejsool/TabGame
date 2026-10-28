import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/games/davinci/core/davinci_rules.dart';
import 'package:tabgame/games/davinci/game/davinci_controller.dart';

int w(int n) => dvTile(1, n);
int b(int n) => dvTile(0, n);

void main() {
  test('4명 대결: 상대가 틀리게 맞혀 차례가 넘어가도, 그 수를 보여 주는 동안은 맞힌 사람이 차례로 보인다', () async {
    final c = DavinciController(mode: PlayMode.wifi, players: 4, humanSeat: 0, seed: 5, animate: true)
      ..cpuStepDelay = const Duration(milliseconds: 40);
    c.state.rows[0]
      ..clear()
      ..addAll([b(1), w(4), b(6)]);
    c.state.rows[1]
      ..clear()
      ..addAll([b(2), w(7), b(10)]);
    c.state.revealed.clear();
    c.state.turn = 1;
    c.state.phase = DvPhase.guess;
    c.state.drawn = w(7);
    expect(c.displayTurn, 1);

    expect(c.receiveMove(DvMove.guess(0, 1, 9), index: 0), isTrue); // CPU1이 내 타일을 틀리게 맞힌다
    expect(c.state.turn, isNot(1), reason: '판은 바로 다음 사람으로 넘어간다');
    final next = c.state.turn;
    expect(c.effect, isNotNull);
    // 연출의 모든 단계(고르는 중 → 말하는 중 → 결과) 동안 차례 표시는 CPU1에 머문다
    final shown = <int>{};
    c.addListener(() {
      if (c.effect != null) shown.add(c.displayTurn);
    });
    expect(c.displayTurn, 1);
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(c.displayTurn, 1);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(c.effect?.stage, DvEffectStage.result);
    expect(c.displayTurn, 1);
    // 연출이 끝나면 비로소 다음 사람으로 넘어간다
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(c.effect, isNull);
    expect(c.displayTurn, next);
    expect(shown, {1});
    c.dispose();
  });

  test('상대가 맞히거나 틀린 소리는 ○ / ✕가 뜨는 순간에 난다 (고르는 중·말하는 중에는 안 난다)', () async {
    final c = DavinciController(mode: PlayMode.wifi, players: 4, humanSeat: 0, seed: 5, animate: true)
      ..cpuStepDelay = const Duration(milliseconds: 40);
    c.state.rows[0]
      ..clear()
      ..addAll([b(1), w(4), b(6)]);
    c.state.revealed.clear();
    c.state.turn = 1;
    c.state.phase = DvPhase.guess;
    c.state.drawn = w(7);
    final heard = <(String, DvEffectStage?)>[];
    c.onFeedback = (kind) {
      if (kind == 'right' || kind == 'wrong') heard.add((kind, c.effect?.stage));
    };
    expect(c.receiveMove(DvMove.guess(0, 1, 9), index: 0), isTrue); // 틀린 추측
    expect(heard, isEmpty, reason: '수를 받자마자 소리가 나면 ✕보다 먼저 들린다');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(heard, [('wrong', DvEffectStage.result)]);
    c.dispose();
  });
}
