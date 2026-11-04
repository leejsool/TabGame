import 'dart:math';

import '../core/kt_run.dart';
import '../core/kt_songs.dart';

/// Wi‑Fi 경주 한 판의 상태 (화면·연결 없이 시험할 수 있다).
///
/// 모든 기기가 같은 곡·같은 씨앗으로 같은 블록을 보고, 시작 신호부터 같은 시계로 내려온다. 내 판([run])은 내가 치고,
/// 다른 자리의 점수는 방장이 모아 알려 준다. 방장 기기는 CPU 자리(처음부터 CPU이거나, 나간 사람을 맡은 CPU)를 직접 흉내 낸다.
class KtRace {
  KtRace({
    required this.song,
    required this.seed,
    required this.names,
    required this.mySeat,
    required this.isHost,
    Set<int> cpuSeats = const {},
    this.level = KtCpuLevel.normal,
  })  : run = KtRun(kind: KtKind.race, song: song, seed: seed),
        scores = List.filled(names.length, const KtScore(0, 0)) {
    if (isHost) {
      for (final s in cpuSeats) {
        _cpus[s] = KtCpu(level: level, seed: seed * 31 + s);
      }
    }
  }

  final KtSong song;
  int seed;
  final List<String> names;
  final int mySeat;
  final bool isHost;
  final KtCpuLevel level;
  KtRun run;

  /// 자리마다의 점수 (내 자리는 [run]에서 바로 채운다).
  final List<KtScore> scores;

  /// (방장) CPU가 치는 자리들.
  final Map<int, KtCpu> _cpus = {};

  /// 결과가 정해졌으면 등수 (0 = 1등). 아직이면 null.
  List<int>? ranks;

  int get players => names.length;

  bool isCpu(int seat) => _cpus.containsKey(seat);
  Iterable<int> get cpuSeats => _cpus.keys;

  /// 시작 신호 뒤 [t]초. 내 점수와 (방장이면) CPU 점수를 고친다.
  void tick(double t) {
    run.tick(t);
    scores[mySeat] = KtScore(run.hits, run.misses);
    if (!isHost) return;
    final p = run.started ? run.pos : -run.lead;
    _cpus.forEach((seat, cpu) {
      cpu.advanceTo(p, run.totalRows);
      scores[seat] = KtScore(cpu.hits, cpu.misses);
    });
  }

  /// 블록이 다 내려왔는가 (이제 결과만 남았다).
  bool get ended => run.finished;

  /// (방장) 나간 사람의 자리를 CPU가 지금 줄부터 이어서 친다.
  void cover(int seat) {
    if (seat == mySeat || _cpus.containsKey(seat)) return;
    final s = scores[seat];
    _cpus[seat] = KtCpu(level: level, seed: seed * 31 + seat + 7, fromRow: max(0, run.pos.ceil()), hits: s.hits, misses: s.misses);
  }

  /// (방장) 돌아온 사람에게 자리를 돌려준다. 점수는 CPU가 쌓은 그대로 이어 간다.
  void uncover(int seat) => _cpus.remove(seat);

  /// (방장) 손님이 알려 온 점수.
  void setScore(int seat, KtScore s) {
    if (seat == mySeat || _cpus.containsKey(seat)) return;
    scores[seat] = s;
  }

  /// (손님) 방장이 알려 온 모든 자리의 점수. 내 자리는 내 것을 믿는다.
  void setBoard(List<KtScore> all) {
    for (var i = 0; i < min(all.length, players); i++) {
      if (i != mySeat) scores[i] = all[i];
    }
  }

  /// 결과를 정한다 (방장은 모아 둔 점수로, 손님은 방장이 보낸 점수로).
  void settle([List<KtScore>? finalScores]) {
    if (finalScores != null) {
      for (var i = 0; i < min(finalScores.length, players); i++) {
        scores[i] = finalScores[i];
      }
    }
    ranks = ktRanks(scores);
  }

  /// 같은 자리들로 새 판 (새 씨앗). CPU 자리는 처음부터 다시 친다.
  void again(int newSeed) {
    seed = newSeed;
    run = KtRun(kind: KtKind.race, song: song, seed: newSeed);
    for (var i = 0; i < players; i++) {
      scores[i] = const KtScore(0, 0);
    }
    for (final s in _cpus.keys.toList()) {
      _cpus[s] = KtCpu(level: level, seed: newSeed * 31 + s);
    }
    ranks = null;
  }

  /// 다시 들어오는 손님에게 보낼 판의 모습. [t]는 지금 판 시계.
  Map<String, dynamic> snapshot(double t) => {
        'song': song.id,
        'seed': seed,
        'names': names,
        'level': level.name,
        'el': t,
        'sc': [for (final s in scores) s.toJson()],
      };

  /// 받은 판의 모습으로 손님 쪽 경주를 만든다. 맞지 않는 내용이면 null.
  static ({KtRace race, double elapsed})? fromSnapshot(Map<String, dynamic> snap, int seat) {
    final song = KtSong.byId('${snap['song']}');
    final seed = snap['seed'], el = snap['el'], rawNames = snap['names'], sc = snap['sc'];
    if (song == null || seed is! int || el is! num || rawNames is! List || sc is! List) return null;
    final names = [for (final n in rawNames) '$n'];
    if (seat < 0 || seat >= names.length || sc.length != names.length) return null;
    final race = KtRace(song: song, seed: seed, names: names, mySeat: seat, isHost: false, level: levelOf(snap['level']));
    final all = [for (final s in sc) KtScore.fromJson(s)];
    race.setBoard(all);
    race.run.jumpTo(el.toDouble(), hits: all[seat].hits, misses: all[seat].misses);
    race.scores[seat] = all[seat];
    return (race: race, elapsed: el.toDouble());
  }

  static KtCpuLevel levelOf(Object? name) => KtCpuLevel.values.firstWhere((l) => l.name == name, orElse: () => KtCpuLevel.normal);
}
