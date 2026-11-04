import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/keytap/core/kt_run.dart';
import 'package:tabgame/games/keytap/core/kt_songs.dart';

void main() {
  final twinkle = KtSong.byId('twinkle')!;

  test('곡의 음은 모두 소리 파일 범위 안에 있다', () {
    for (final s in KtSong.all) {
      expect(s.notes.every((n) => n >= kLowNote && n <= kHighNote), isTrue, reason: s.title);
      expect(s.notes.length, greaterThan(20), reason: s.title);
    }
    expect({for (final s in KtSong.all) s.id}.length, KtSong.all.length);
  });

  test('바로 앞 줄과 같은 칸에는 블록이 나오지 않고, 같은 씨앗이면 같은 판', () {
    final a = KtRun(kind: KtKind.song, song: twinkle, seed: 5);
    final b = KtRun(kind: KtKind.song, song: twinkle, seed: 5);
    for (var i = 1; i < 200; i++) {
      expect(a.lane(i), isNot(a.lane(i - 1)));
      expect(a.lane(i), inInclusiveRange(0, 3));
    }
    expect([for (var i = 0; i < 50; i++) b.lane(i)], [for (var i = 0; i < 50; i++) a.lane(i)]);
  });

  test('속도 표: 시간과 줄 수는 서로 되돌릴 수 있고 바퀴마다 빨라진다', () {
    final tempo = KtTempo.song(twinkle);
    for (final p in [0.5, 10.0, 41.9, 42.0, 60.0, 130.0]) {
      expect(tempo.posAt(tempo.timeAt(p)), closeTo(p, 1e-9));
    }
    expect(tempo.speedOf(1), greaterThan(tempo.speedOf(0)));
  });

  test('곡 완주: 시작 블록을 누르면 시작하고, 흰 칸을 누르면 끝난다', () {
    final r = KtRun(kind: KtKind.song, song: twinkle, seed: 1);
    expect(r.tap((r.lane(0) + 1) % 4, 0.5), KtTap.ignored); // 시작 전 흰 칸은 괜찮다
    expect(r.started, isFalse);
    expect(r.tap(r.lane(0), 0.5), KtTap.hit);
    expect(r.started, isTrue);
    expect(r.hits, 1);
    expect(r.tap(r.lane(2), 2.5), KtTap.ignored); // 차례가 아닌 검은 블록은 무시
    final wrong = [0, 1, 2, 3].firstWhere((l) => l != r.lane(1));
    expect(r.tap(wrong, 1.5), KtTap.wrong);
    expect(r.over, isTrue);
    expect(r.failRow, 1);
    expect(r.stars, 0);
  });

  test('곡 완주: 블록을 놓치면 끝나고, 다 치면 별 3개', () {
    final r = KtRun(kind: KtKind.song, song: twinkle, seed: 2);
    r.tap(r.lane(0), 0.5);
    r.tick(r.tempo.timeAt(3.2));
    expect(r.over, isTrue);
    expect(r.failRow, 1);

    final w = KtRun(kind: KtKind.song, song: twinkle, seed: 2);
    var now = 0.0;
    while (!w.done) {
      final i = w.next;
      w.tick(now);
      expect(w.tap(w.lane(i), i + 0.5), KtTap.hit);
      now = w.tempo.timeAt(i + 0.6);
    }
    expect(w.finished, isTrue);
    expect(w.hits, twinkle.length * 3);
    expect(w.stars, 3);
  });

  test('경주: 놓쳐도 계속되고 흰 칸을 누르면 잠깐 못 누른다', () {
    final r = KtRun(kind: KtKind.race, song: twinkle, seed: 3)..start();
    r.tick(r.tempo.timeAt(r.lead + 3.0));
    expect(r.over, isFalse);
    expect(r.misses, 2);
    expect(r.next, 2);
    final wrong = [0, 1, 2, 3].firstWhere((l) => l != r.lane(2) && l != r.lane(3));
    expect(r.tap(wrong, 2.5), KtTap.wrong);
    expect(r.tap(r.lane(2), 2.5), KtTap.ignored); // 잠깐 멈춤
    r.tick(r.t + KtRun.stunTime + 0.01);
    expect(r.tap(r.lane(r.next), r.next + 0.5), KtTap.hit);
  });

  test('경주: 다시 들어오면 그 시간의 줄로 건너뛴다', () {
    final r = KtRun(kind: KtKind.race, song: twinkle, seed: 3);
    r.jumpTo(r.tempo.timeAt(r.lead + 20.3), hits: 15, misses: 3);
    expect(r.next, 20);
    expect(r.hits, 15);
  });

  test('CPU는 솜씨만큼 맞히고, 등수는 많이 맞힌 순', () {
    final cpu = KtCpu(level: KtCpuLevel.hard, seed: 9);
    cpu.advanceTo(1000, 400);
    expect(cpu.hits + cpu.misses, 400);
    expect(cpu.hits, greaterThan(360));
    expect(ktRanks(const [KtScore(10, 2), KtScore(12, 5), KtScore(10, 2), KtScore(10, 1)]), [2, 0, 2, 1]);
  });

  test('무한: 음이 끝없이 이어지고 점점 빨라진다', () {
    final r = KtRun(kind: KtKind.endless, seed: 4);
    expect(r.note(500), inInclusiveRange(kLowNote, kHighNote));
    expect(r.tempo.speedOf(10), greaterThan(r.tempo.speedOf(0)));
  });
}
