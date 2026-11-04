import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/keytap/core/kt_run.dart';
import 'package:tabgame/games/keytap/core/kt_songs.dart';
import 'package:tabgame/games/keytap/game/kt_race.dart';

void main() {
  final song = KtSong.byId('airplane')!;

  KtRace host() => KtRace(song: song, seed: 11, names: const ['방장', '친구', 'CPU 1'], mySeat: 0, isHost: true, cpuSeats: const {2});

  test('방장은 CPU 자리를 직접 치고, 판이 끝나면 등수를 정한다', () {
    final r = host()..run.started = true;
    final end = r.run.tempo.timeAt(r.run.lead + r.run.totalRows + 2);
    for (var t = 0.0; t <= end; t += 0.05) {
      r.tick(t);
    }
    expect(r.ended, isTrue);
    expect(r.scores[2].hits + r.scores[2].misses, r.run.totalRows);
    expect(r.scores[0].misses, r.run.totalRows); // 나는 하나도 안 쳤다
    r.setScore(1, const KtScore(30, 2));
    r.settle();
    expect(r.ranks![0], 2);
  });

  test('나간 사람 자리는 CPU가 지금 점수에서 이어 치고, 돌아오면 멈춘다', () {
    final r = host()..run.started = true;
    r.setScore(1, const KtScore(5, 1));
    r.tick(r.run.tempo.timeAt(r.run.lead + 6));
    r.cover(1);
    expect(r.isCpu(1), isTrue);
    r.tick(r.run.tempo.timeAt(r.run.lead + 20));
    final s = r.scores[1];
    expect(s.hits + s.misses, greaterThan(6 + 10));
    r.uncover(1);
    r.setScore(1, const KtScore(40, 0));
    expect(r.scores[1].hits, 40);
  });

  test('판의 모습을 받아 다시 들어오면 같은 시간·같은 점수에서 이어 간다', () {
    final r = host()..run.started = true;
    final t = r.run.tempo.timeAt(r.run.lead + 15.5);
    r.setScore(1, const KtScore(9, 4));
    r.tick(t);
    final back = KtRace.fromSnapshot(r.snapshot(t), 1)!;
    expect(back.elapsed, t);
    expect(back.race.run.hits, 9);
    expect(back.race.run.next, 15);
    expect(back.race.names, r.names);
    expect([for (var i = 0; i < 30; i++) back.race.run.lane(i)], [for (var i = 0; i < 30; i++) r.run.lane(i)]);
    expect(KtRace.fromSnapshot({'song': 'none'}, 1), isNull);
  });

  test('한 번 더: 점수가 지워지고 새 씨앗의 블록이 나온다', () {
    final r = host()..run.started = true;
    r.tick(5);
    r.again(99);
    expect(r.run.started, isFalse);
    expect(r.scores.every((s) => s.hits == 0 && s.misses == 0), isTrue);
    expect(r.ranks, isNull);
    expect(r.isCpu(2), isTrue);
  });
}
