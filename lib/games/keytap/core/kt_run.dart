import 'dart:math';

import 'kt_songs.dart';

/// 판의 종류: 곡 완주(3바퀴, 바퀴마다 빨라짐) · 무한(점점 빨라지다 틀리면 끝) · Wi‑Fi 경주(틀려도 계속, 2바퀴).
enum KtKind { song, endless, race }

/// 시간 → 내려온 줄 수. [seg]줄마다 속도가 바뀐다 (바퀴·단계).
class KtTempo {
  const KtTempo(this.seg, this._speed);

  /// 곡 완주·경주: 한 바퀴마다 22%씩 빨라진다.
  factory KtTempo.song(KtSong song) => KtTempo(song.length, (k) => song.speed * (1 + 0.22 * k));

  /// 무한: 20줄마다 조금씩 빨라지고 9줄/초에서 멈춘다.
  factory KtTempo.endless() => KtTempo(20, (k) => min(2.6 + 0.22 * k, 9.0));

  final int seg;
  final double Function(int k) _speed;

  double speedOf(int k) => _speed(k);

  /// 시작하고 [t]초 뒤 내려온 줄 수.
  double posAt(double t) {
    if (t <= 0) return 0;
    var k = 0;
    while (true) {
      final v = _speed(k);
      final dur = seg / v;
      if (t < dur) return k * seg + t * v;
      t -= dur;
      k++;
    }
  }

  /// [p]줄 내려오는 데 걸리는 시간.
  double timeAt(double p) {
    if (p <= 0) return 0;
    var t = 0.0;
    var k = 0;
    while (p > seg) {
      t += seg / _speed(k);
      p -= seg;
      k++;
    }
    return t + p / _speed(k);
  }
}

/// 한 번 누른 결과.
enum KtTap { hit, wrong, ignored }

/// 건반 톡톡 한 판의 규칙 (화면 없이 시험할 수 있는 순수 Dart).
///
/// 줄 i는 세로 좌표 [i, i+1)을 차지하고, 화면 맨 아래의 좌표가 [pos]다. 줄마다 검은 블록이 한 칸(lane) 있고,
/// 아래에서부터 차례로 눌러야 한다. 블록이 화면 아래로 다 빠져나가면 놓친 것이다.
class KtRun {
  KtRun({required this.kind, this.song, required this.seed})
      : assert(kind == KtKind.endless || song != null),
        tempo = kind == KtKind.endless ? KtTempo.endless() : KtTempo.song(song!),
        lead = kind == KtKind.race ? 2.5 : 0,
        _rng = Random(seed),
        _noteRng = Random(seed + 1);

  final KtKind kind;
  final KtSong? song;
  final int seed;
  final KtTempo tempo;

  /// 경주는 시작 신호 뒤 [lead]줄만큼 빈 칸이 먼저 내려온다 (첫 블록까지 여유).
  final double lead;

  final Random _rng, _noteRng;
  final List<int> _lanes = [];
  final List<int> _notes = [];

  /// 곡 완주는 3바퀴, 경주는 2바퀴. 무한은 끝이 없다.
  int get totalRows => switch (kind) {
        KtKind.song => song!.length * 3,
        KtKind.race => song!.length * 2,
        KtKind.endless => 1 << 30,
      };

  bool started = false;
  double t = 0;
  int next = 0;
  int hits = 0;
  int misses = 0;
  bool over = false;
  bool finished = false;

  /// 틀려서 끝났을 때 빨갛게 보여 줄 칸 (줄, 칸).
  int? failRow, failLane;

  /// 경주에서 놓친 줄들 (회색 대신 옅은 빨강으로 그린다).
  final Set<int> missedRows = {};

  /// 경주에서 흰 칸을 누르면 잠깐 못 누른다.
  double stunUntil = -1;

  /// 경주에서 마지막으로 잘못 누른 칸 (깜빡여 보여 준다).
  int? wrongRow, wrongLane;
  double wrongAt = -10;

  static const double stunTime = 0.5;

  double get pos => started ? tempo.posAt(t) - lead : -lead;

  /// 그릴 때 화면 맨 아래 좌표: 블록을 놓쳐 끝났으면 그 블록이 보이게 조금 되돌린다.
  double get viewPos {
    final fr = failRow;
    return over && fr != null ? min(pos, fr - 0.15) : pos;
  }

  bool get done => over || finished;

  /// 줄 [i]의 검은 블록 칸 (0~3). 바로 앞 줄과 같은 칸은 나오지 않는다.
  int lane(int i) {
    while (_lanes.length <= i) {
      if (_lanes.isEmpty) {
        _lanes.add(_rng.nextInt(4));
        continue;
      }
      final l = _rng.nextInt(3);
      _lanes.add(l >= _lanes.last ? l + 1 : l);
    }
    return _lanes[i];
  }

  /// 줄 [i]를 누르면 나는 음 (MIDI 번호).
  int note(int i) {
    final s = song;
    if (s != null) return s.notes[i % s.length];
    while (_notes.length <= i) {
      _notes.addAll(KtSong.all[_noteRng.nextInt(KtSong.all.length)].notes);
    }
    return _notes[i];
  }

  /// 지금 몇 바퀴째인지 (0부터). 무한이면 속도 단계.
  int get lap => kind == KtKind.endless ? next ~/ tempo.seg : min(next, totalRows - 1) ~/ song!.length;

  /// 곡 완주의 별: 다 돈 바퀴 수 (최대 3).
  int get stars => kind == KtKind.song ? (finished ? 3 : min(3, next ~/ song!.length)) : 0;

  /// 지금 속도 (줄/초).
  double get speed => tempo.speedOf(kind == KtKind.endless ? max(0, pos).floor() ~/ tempo.seg : lap);

  /// 시간을 [now]초로 옮긴다 (시작 뒤 지난 시간). 지나간 블록을 놓친 것으로 처리한다.
  void tick(double now) {
    if (!started || done) return;
    t = now;
    final p = pos;
    while (!done && next < totalRows && p > next + 1.05) {
      if (kind == KtKind.race) {
        misses++;
        missedRows.add(next);
        next++;
      } else {
        failRow = next;
        failLane = lane(next);
        over = true;
      }
    }
    if (next >= totalRows) finished = true;
  }

  /// (곡 완주·무한) 시작 블록을 누르기 전에 시계를 맞춘다. 경주는 시작 신호에 바로 시작한다.
  void start() {
    started = true;
    t = 0;
  }

  /// [laneIndex] 칸의 세로 좌표 [y](줄 단위, 화면 맨 아래 = [pos])를 눌렀다.
  KtTap tap(int laneIndex, double y) {
    if (done) return KtTap.ignored;
    if (kind == KtKind.race && (!started || t < stunUntil)) return KtTap.ignored;
    final target = next;
    if (laneIndex == lane(target) && y >= target - 0.4 && y < target + 1.45) {
      if (!started) start();
      hits++;
      next++;
      if (next >= totalRows) finished = true;
      return KtTap.hit;
    }
    final r = y.floor();
    if (r >= 0 && laneIndex == lane(r)) return KtTap.ignored; // 이미 친 블록이나 아직 차례가 아닌 블록
    if (!started) return KtTap.ignored; // 시작 전에는 흰 칸을 눌러도 괜찮다
    if (kind == KtKind.race) {
      misses++;
      stunUntil = t + stunTime;
      wrongRow = r;
      wrongLane = laneIndex;
      wrongAt = t;
      return KtTap.wrong;
    }
    failRow = r;
    failLane = laneIndex;
    over = true;
    return KtTap.wrong;
  }

  /// (Wi‑Fi로 다시 들어올 때) 경주의 [now]초 지점으로 건너뛴다. 점수는 그 자리를 맡던 쪽에서 받은 것.
  void jumpTo(double now, {required int hits, required int misses}) {
    started = true;
    t = now;
    this.hits = hits;
    this.misses = misses;
    next = max(0, (pos - 1.05).ceil());
    if (next >= totalRows) finished = true;
  }
}

/// CPU의 솜씨.
enum KtCpuLevel {
  easy('쉬움', 0.80),
  normal('보통', 0.91),
  hard('어려움', 0.975);

  const KtCpuLevel(this.label, this.accuracy);
  final String label;
  final double accuracy;
}

/// 경주에서 CPU(또는 나간 사람 자리를 맡은 CPU)가 치는 흉내: 블록이 지나갈 때마다 솜씨만큼 맞힌다.
class KtCpu {
  KtCpu({required this.level, required int seed, this.fromRow = 0, this.hits = 0, this.misses = 0}) : _rng = Random(seed), _row = fromRow;

  final KtCpuLevel level;
  final int fromRow;
  final Random _rng;
  int _row;
  int hits, misses;

  /// 화면 맨 아래가 [pos]줄일 때까지 지나간 블록을 친다 (전체 [total]줄).
  void advanceTo(double pos, int total) {
    while (_row < total && pos > _row + 0.6) {
      if (_rng.nextDouble() < level.accuracy) {
        hits++;
      } else {
        misses++;
      }
      _row++;
    }
  }
}

/// 경주 한 자리의 점수.
class KtScore {
  const KtScore(this.hits, this.misses);
  final int hits, misses;

  List<int> toJson() => [hits, misses];
  static KtScore fromJson(Object? j) =>
      j is List && j.length == 2 && j[0] is int && j[1] is int ? KtScore(j[0] as int, j[1] as int) : const KtScore(0, 0);
}

/// 등수 (0 = 1등). 많이 맞힌 순, 같으면 덜 틀린 순. 완전히 같으면 같은 등수.
List<int> ktRanks(List<KtScore> scores) {
  int better(KtScore a, KtScore b) => a.hits != b.hits ? b.hits - a.hits : a.misses - b.misses;
  return [
    for (final s in scores) scores.where((o) => better(o, s) < 0).length,
  ];
}
