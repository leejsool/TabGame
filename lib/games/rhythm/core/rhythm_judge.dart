import 'rhythm_chart.dart';

enum Rating {
  perfect('완벽!'),
  good('좋아요'),
  wrongSide('반대쪽!'),
  miss('놓쳤어요'),
  stray('앗!'),

  /// 꾹 누르기를 제대로 시작했다 (판정은 손을 뗄 때 나온다).
  holdStart('');

  const Rating(this.label);
  final String label;

  bool get isHit => this == perfect || this == good;
}

/// 판정 하나의 결과.
class Judged {
  const Judged(this.rating, this.event, this.error);

  final Rating rating;

  /// 맞추려던 박자 (stray면 null).
  final ChartEvent? event;

  /// 탭 시각 − 정답 시각(초). 양수면 늦게 친 것.
  final double error;
}

/// 플레이어의 탭·꾹 누르기를 정답 박자와 맞춰 보는 판정기. 어린이용이라 판정 폭을 넉넉하게 잡았다.
///
/// 짧은 탭은 누르는 순간이 곧 내려치는 순간이다. 꾹 누르기는 누르는 순간(시작)이 맞아야 하고,
/// 손을 떼는 순간이 내려치는 순간으로 판정된다.
class RhythmJudge {
  RhythmJudge(
    Iterable<ChartEvent> expected, {
    this.perfectWindow = 0.07,
    this.goodWindow = 0.15,
    this.matchWindow = 0.2,
    this.swipeSlack = 1.3,
    this.guardSlack = 1.5,
  }) : _expected = expected.toList() {
    _done = List.filled(_expected.length, false);
    _pressed = List.filled(_expected.length, false);
  }

  final double perfectWindow;
  final double goodWindow;

  /// 이 안에 들어온 탭만 그 박자의 시도로 본다 (벗어나면 stray).
  final double matchWindow;

  /// 옆으로 긋기는 손가락이 일정 거리를 가야 해서 탭보다 늦게 잡힌다 — 판정 폭을 이만큼 넓힌다.
  final double swipeSlack;

  /// 위로 밀어 막기는 긋기보다 조금 더 넉넉하게 본다.
  final double guardSlack;

  double _slack(ChartEvent e) => e.isGuard ? guardSlack : (e.isSwipe ? swipeSlack : 1.0);

  final List<ChartEvent> _expected;
  late final List<bool> _done;
  late final List<bool> _pressed;
  int? _holding;

  int perfect = 0;
  int good = 0;
  int miss = 0;
  int stray = 0;
  int combo = 0;
  int maxCombo = 0;
  int score = 0;

  int get total => _expected.length;
  int get hits => perfect + good;
  int get judged => perfect + good + miss;

  /// 지금 꾹 누르고 있는 박자 (없으면 null).
  ChartEvent? get holdingEvent => _holding == null ? null : _expected[_holding!];

  /// 0~1: 완벽 100%, 좋아요 70%로 센 정확도.
  double get accuracy => total == 0 ? 0 : (perfect + good * 0.7) / total;

  /// 별 0~3개.
  int get stars {
    final a = accuracy;
    if (a >= 0.9) return 3;
    if (a >= 0.7) return 2;
    if (a >= 0.45) return 1;
    return 0;
  }

  void _break() => combo = 0;

  void _hit(Rating r) {
    combo++;
    if (combo > maxCombo) maxCombo = combo;
    if (r == Rating.perfect) {
      perfect++;
      score += 100 + (combo > 10 ? 10 : combo);
    } else {
      good++;
      score += 60;
    }
  }

  /// 누르는 순간 기준이 되는 시각.
  double _ref(int i) => _expected[i].pressTime;

  Judged _rate(ChartEvent e, double err) {
    final a = err.abs();
    final k = _slack(e);
    if (a <= perfectWindow * k) {
      _hit(Rating.perfect);
      return Judged(Rating.perfect, e, err);
    }
    if (a <= goodWindow * k) {
      _hit(Rating.good);
      return Judged(Rating.good, e, err);
    }
    miss++;
    _break();
    return Judged(Rating.miss, e, err);
  }

  /// 화면을 눌렀다. [t]는 곡 시작부터의 시간(초, 입력 보정 적용 후).
  ///
  /// 박자는 앞에서부터 차례로 짝짓는다. 다만 가장 이른 박자가 "좋아요" 범위를 벗어났는데
  /// 다음 박자가 확실히 더 가깝다면, 이른 박자는 놓친 것으로 보고 다음 박자로 판정한다.
  Judged tap(double t, Side side) {
    final cands = <int>[];
    for (var i = 0; i < _expected.length; i++) {
      if (_done[i] || _pressed[i] || _expected[i].isSwipe || _expected[i].isGuard) continue;
      final err = t - _ref(i);
      if (err < -matchWindow || err > matchWindow) continue;
      cands.add(i);
    }
    cands.sort((a, b) => _ref(a).compareTo(_ref(b)));
    if (cands.isEmpty) {
      stray++;
      _break();
      return Judged(Rating.stray, null, 0);
    }
    var pick = cands.first;
    final errFirst = t - _ref(pick);
    if (errFirst.abs() > goodWindow && cands.length > 1 && (t - _ref(cands[1])).abs() < errFirst.abs() * 0.6) {
      _done[pick] = true;
      miss++;
      _break();
      pick = cands[1];
    }
    final e = _expected[pick];
    final err = t - _ref(pick);
    if (e.side != side) {
      _done[pick] = true;
      miss++;
      _break();
      return Judged(Rating.wrongSide, e, err);
    }
    if (e.isHold) {
      // 눌렀을 때의 정확도는 따로 점수를 주지 않고, 손을 뗄 때 한 번에 판정한다
      _pressed[pick] = true;
      _holding = pick;
      return Judged(Rating.holdStart, e, err);
    }
    _done[pick] = true;
    return _rate(e, err);
  }

  /// 화면을 [dir] 쪽으로 쓱 그었다 (일정 거리를 넘긴 순간). [t]는 [tap]과 같은 시계.
  /// 방향만 본다: 박자가 맞아도 방향이 반대면 [Rating.wrongSide].
  Judged swipe(double t, Side dir) {
    int? pick;
    for (var i = 0; i < _expected.length; i++) {
      final e = _expected[i];
      if (_done[i] || !e.isSwipe) continue; // 막기 박자는 위로 밀기([guard])로만
      if ((t - _ref(i)).abs() > matchWindow * swipeSlack) continue;
      if (pick == null || _ref(i) < _ref(pick)) pick = i;
    }
    if (pick == null) {
      stray++;
      _break();
      return Judged(Rating.stray, null, 0);
    }
    final e = _expected[pick];
    final err = t - _ref(pick);
    _done[pick] = true;
    if (e.side != dir) {
      miss++;
      _break();
      return Judged(Rating.wrongSide, e, err);
    }
    return _rate(e, err);
  }

  /// 화면을 위로 쓱 밀었다 (보스의 공격 막기). 방향(어느 손)은 보지 않고 박자만 본다.
  /// [t]는 [tap]과 같은 시계. 가까운 막기 박자가 없으면 [Rating.stray].
  Judged guard(double t) {
    int? pick;
    for (var i = 0; i < _expected.length; i++) {
      final e = _expected[i];
      if (_done[i] || !e.isGuard) continue;
      if ((t - _ref(i)).abs() > matchWindow * guardSlack) continue;
      if (pick == null || _ref(i) < _ref(pick)) pick = i;
    }
    if (pick == null) {
      stray++;
      _break();
      return Judged(Rating.stray, null, 0);
    }
    final e = _expected[pick];
    _done[pick] = true;
    return _rate(e, t - _ref(pick));
  }

  /// 손을 뗐다. 꾹 누르고 있던 박자가 없으면 null.
  Judged? release(double t) {
    final i = _holding;
    if (i == null) return null;
    _holding = null;
    _done[i] = true;
    final e = _expected[i];
    return _rate(e, t - e.time);
  }

  /// 시각 [now]까지 아무도 치지 않은 박자를 놓친 것으로 처리하고 돌려준다.
  List<Judged> expire(double now) {
    final out = <Judged>[];
    for (var i = 0; i < _expected.length; i++) {
      if (_done[i]) continue;
      final e = _expected[i];
      final deadline = (_pressed[i] ? e.time : _ref(i)) + matchWindow * _slack(e);
      if (deadline >= now) continue;
      _done[i] = true;
      if (_holding == i) _holding = null;
      miss++;
      _break();
      out.add(Judged(Rating.miss, e, 0));
    }
    return out;
  }

  /// 아직 판정이 끝나지 않은 박자 중 다음으로 해야 할 것 — 안내 링 표시용.
  /// 꾹 누르는 중이면 그 박자(손을 뗄 차례).
  ChartEvent? nextPending(double now) {
    final h = holdingEvent;
    if (h != null) return h;
    ChartEvent? best;
    var bestRef = double.infinity;
    for (var i = 0; i < _expected.length; i++) {
      if (_done[i]) continue;
      final r = _ref(i);
      if (r + goodWindow * _slack(_expected[i]) >= now && r < bestRef) {
        best = _expected[i];
        bestRef = r;
      }
    }
    return best;
  }
}
