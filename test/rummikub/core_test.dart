import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/rummikub/core/rummikub_ai.dart';
import 'package:tabgame/games/rummikub/core/rummikub_rules.dart';
import 'package:tabgame/games/rummikub/core/rummikub_split.dart';

int t(int color, int number, [int copy = 0]) => tileId(color, number, copy);

void main() {
  group('잘못 묶인 것 쪼개기', () {
    test('1-2-3-5-6-7은 1-2-3 과 5-6-7로 쪼개진다', () {
      final plan = splitIntoMelds([t(0, 1), t(0, 2), t(0, 3), t(0, 5), t(0, 6), t(0, 7)]);
      expect(plan, isNotNull);
      expect(plan!.leftover, isEmpty);
      final sets = [for (final m in plan.melds) ([...m]..sort())];
      expect(sets.length, 2);
      expect(sets, containsAll([
        [t(0, 1), t(0, 2), t(0, 3)],
        [t(0, 5), t(0, 6), t(0, 7)],
      ]));
    });

    test('쪼개도 안 되면 null, 낱개로 빼도 되는 타일은 빼고 나머지를 맞춘다', () {
      expect(splitIntoMelds([t(0, 1), t(0, 2), t(0, 3), t(0, 9)]), isNull);
      final plan = splitIntoMelds([t(0, 1), t(0, 2), t(0, 3), t(0, 9)], removable: {t(0, 9)});
      expect(plan!.leftover, [t(0, 9)]);
      expect(plan.melds.single.length, 3);
    });

    test('너무 많은 타일은 포기한다', () {
      expect(splitIntoMelds([for (var i = 1; i <= 13; i++) t(0, i), t(1, 1)]), isNull);
    });
  });

  group('묶음 판정', () {
    test('런: 같은 색 연속 3장 이상', () {
      expect(analyzeMeld([t(0, 3), t(0, 4), t(0, 5)])?.value, 12);
      expect(analyzeMeld([t(0, 5), t(0, 3), t(0, 4)])?.order, [t(0, 3), t(0, 4), t(0, 5)]);
      expect(isValidMeld([t(0, 3), t(0, 4)]), isFalse);
      expect(isValidMeld([t(0, 3), t(1, 4), t(0, 5)]), isFalse);
      expect(isValidMeld([t(0, 3), t(0, 3, 1), t(0, 4)]), isFalse);
      expect(isValidMeld([t(0, 12), t(0, 13), t(0, 1)]), isFalse); // 13 다음 1은 안 된다
    });

    test('그룹: 같은 숫자 서로 다른 색 3~4장', () {
      expect(analyzeMeld([t(0, 7), t(1, 7), t(2, 7)])?.value, 21);
      expect(analyzeMeld([t(0, 7), t(1, 7), t(2, 7), t(3, 7)])?.value, 28);
      expect(isValidMeld([t(0, 7), t(1, 7), t(1, 7, 1)]), isFalse); // 색이 겹친다
      expect(isValidMeld([t(0, 7), t(1, 7), t(2, 7), t(3, 7), kJokerA]), isFalse);
    });

    test('조커는 빈 자리를 메우고, 점수는 높은 쪽으로 센다', () {
      expect(analyzeMeld([t(0, 3), kJokerA, t(0, 5)])?.value, 12);
      expect(analyzeMeld([t(0, 3), kJokerA, t(0, 5)])?.order, [t(0, 3), kJokerA, t(0, 5)]);
      expect(analyzeMeld([kJokerA, t(0, 5), t(0, 6)])?.value, 18); // 7로 세는 게 이득
      expect(analyzeMeld([t(0, 12), t(0, 13), kJokerA])?.value, 36); // 11이어야만 한다
      expect(analyzeMeld([t(0, 12), t(0, 13), kJokerA])?.order, [kJokerA, t(0, 12), t(0, 13)]);
      expect(analyzeMeld([t(0, 4), t(1, 4), kJokerA])?.value, 12);
      expect(analyzeMeld([t(0, 4), t(1, 4), kJokerA, kJokerB])?.value, 16);
      expect(isValidMeld([t(0, 3), kJokerA, kJokerB, t(0, 8)]), isFalse); // 빈 자리가 조커보다 많다
      expect(isValidMeld([kJokerA, kJokerB, t(0, 3)]), isTrue);
      expect(isValidMeld([kJokerA, kJokerB]), isFalse);
    });
  });

  group('패 나누기', () {
    test('106장이 겹치지 않고, 씨앗이 같으면 같은 패', () {
      final s = RkState.deal(4, 5);
      final all = [for (final r in s.racks) ...r, ...s.pool];
      expect(all.toSet().length, kTileCount);
      expect(s.racks.every((r) => r.length == kRackSize), isTrue);
      expect(RkState.deal(4, 5).racks, s.racks);
      expect(RkState.deal(4, 6).racks, isNot(s.racks));
    });
  });

  group('차례 확인', () {
    RkState fixed({List<int>? rack}) {
      final s = RkState.deal(2, 1);
      s.racks[0]
        ..clear()
        ..addAll(rack ?? [t(0, 10), t(1, 10), t(2, 10), t(0, 1), t(1, 2), t(2, 3)]);
      return s;
    }

    test('처음에는 30점이 필요하다', () {
      final s = fixed(rack: [t(0, 10), t(1, 10), t(2, 10), t(0, 1)]);
      expect(s.checkPlay([[t(0, 10), t(1, 10), t(2, 10)]]), isNull);
      final s2 = fixed(rack: [t(0, 5), t(1, 5), t(2, 5), t(0, 1)]);
      expect(s2.checkPlay([[t(0, 5), t(1, 5), t(2, 5)]]), PlayError.needPoints);
    });

    test('아무것도 내지 않았거나 남의 타일을 쓰면 안 된다', () {
      final s = fixed();
      expect(s.checkPlay([]), PlayError.nothingPlaced);
      expect(s.checkPlay([[t(0, 10), t(1, 10), t(3, 10)]]), PlayError.tilesMismatch);
    });

    test('올바르지 않은 묶음이 있으면 안 된다', () {
      final s = fixed();
      expect(s.checkPlay([[t(0, 10), t(1, 10)]]), PlayError.badSet);
    });

    test('처음 내려놓은 뒤에는 판 위 묶음을 풀어 다시 맞출 수 있다', () {
      final s = fixed(rack: [t(0, 10), t(1, 10), t(2, 10), t(0, 11), t(0, 12), t(3, 1)]);
      s.applyPlay([[t(0, 10), t(1, 10), t(2, 10)]]);
      expect(s.turn, 1);
      expect(s.melded[0], isTrue);
      // 상대 차례를 넘기고 다시 내 차례
      s.applyDraw();
      expect(s.turn, 0);
      // 그룹의 빨강 10(t(2,10))을 빼서 검정 런 10-11-12를 만들면 그룹이 2장이 되어 안 된다
      expect(s.checkPlay([[t(1, 10), t(2, 10)], [t(0, 10), t(0, 11), t(0, 12)]]), PlayError.badSet);
      // 같은 숫자 다른 복사본이 있다면 가능: 검정 10을 런에 쓰려면 다른 10이 필요
      s.racks[0].addAll([t(3, 10)]);
      expect(s.checkPlay([[t(0, 10), t(1, 10), t(2, 10), t(3, 10)], [t(0, 11), t(0, 12)]]), PlayError.badSet);
    });

    test('손이 비면 이긴다, 더미가 비고 모두 넘기면 벌점이 낮은 사람이 이긴다', () {
      final s = fixed(rack: [t(0, 10), t(1, 10), t(2, 10)]);
      s.applyPlay([[t(0, 10), t(1, 10), t(2, 10)]]);
      expect(s.over, isTrue);
      expect(s.winner, 0);

      final b = RkState.deal(2, 3);
      b.pool.clear();
      b.racks[0]
        ..clear()
        ..add(t(0, 2));
      b.racks[1]
        ..clear()
        ..add(t(0, 9));
      b.applyDraw();
      expect(b.over, isFalse);
      b.applyDraw();
      expect(b.over, isTrue);
      expect(b.winner, 0);
    });
  });

  group('CPU', () {
    test('내 타일로만 30점을 만들면 낸다', () {
      final rack = [t(0, 10), t(1, 10), t(2, 10), t(0, 1), t(1, 5)];
      final p = RkAi.plan(rack: rack, table: [], melded: false, level: RkLevel.hard, rng: Random(1));
      expect(p, isNotNull);
      expect(p!.expand((s) => s).toSet(), {t(0, 10), t(1, 10), t(2, 10)});
    });

    test('30점이 안 되면 뽑는다', () {
      final rack = [t(0, 3), t(1, 3), t(2, 3), t(0, 9)];
      expect(RkAi.plan(rack: rack, table: [], melded: false, level: RkLevel.hard, rng: Random(1)), isNull);
    });

    test('판 위 묶음을 풀어서 낸다', () {
      // 판: 검정 3-4-5-6, 내 손: 빨강 6, 파랑 6 + 검정 6을 떼어 그룹을 만들 수 있다
      final table = [[t(0, 3), t(0, 4), t(0, 5), t(0, 6)]];
      final rack = [t(1, 6), t(2, 6)];
      final p = RkAi.plan(rack: rack, table: table, melded: true, level: RkLevel.hard, rng: Random(1));
      expect(p, isNotNull);
      final s = RkState.deal(2, 1);
      s.table.addAll(table);
      s.racks[0]
        ..clear()
        ..addAll(rack);
      s.melded[0] = true;
      expect(s.checkPlay(p!), isNull);
      expect(s.racks[0].every((x) => p.expand((e) => e).contains(x)), isTrue);
    });

    test('CPU끼리 한 판을 끝까지 두면 모든 수가 규칙에 맞는다', () {
      for (final level in RkLevel.values) {
        for (var seed = 0; seed < 6; seed++) {
          final s = RkState.deal(2 + seed % 3, seed);
          final rng = Random(seed);
          var turns = 0;
          while (!s.over && turns < 400) {
            turns++;
            final plan = RkAi.plan(rack: s.currentRack, table: s.table, melded: s.melded[s.turn], level: level, rng: rng);
            if (plan == null) {
              s.applyDraw();
            } else {
              expect(s.checkPlay(plan), isNull, reason: '$level seed $seed turn $turns');
              s.applyPlay(plan);
            }
            final all = [for (final r in s.racks) ...r, ...s.pool, ...s.tableTiles];
            expect(all.toSet().length, kTileCount);
            expect(all.length, kTileCount);
          }
          expect(s.over, isTrue, reason: '$level seed $seed 끝나지 않았어요');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 4)));
  });
}
