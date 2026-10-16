import 'grid.dart';
import 'techniques.dart';

/// 마스터 기술들 (Lv.5 이상): 한 숫자만 보는 패턴, 유일해를 이용하는 기술, 체인, ALS, 가정법.
///
/// 모든 찾기 함수는 "후보를 지울 수 있는 곳이 있을 때만" 단계를 돌려준다. (정답을 알고 있어도 쓰지 않는다 — 논리만으로 찾는다.)
/// 유니크 직사각형과 BUG+1은 "해가 하나뿐인 퍼즐"이라는 전제를 쓴다.
class MasterFinders {
  MasterFinders._();

  static int _unitOf(bool byRow, int line) => byRow ? line : 9 + line;
  static int _cellAt(bool byRow, int line, int x) => byRow ? line * 9 + x : x * 9 + line;

  static List<int> _with(CandidateGrid g, Iterable<int> cells, int b) => [
        for (final c in cells)
          if (g.cand[c] & b != 0) c,
      ];

  /// 두 칸 [a], [b]를 모두 보는 칸 중 숫자 [b]가 후보인 칸들 ([skip] 제외).
  static Map<int, int> _commonElims(CandidateGrid g, int a, int c, int digitBit, Set<int> skip) => {
        for (final t in commonPeers(a, c))
          if (!skip.contains(t) && g.cand[t] & digitBit != 0) t: digitBit,
      };

  // ── 스카이스크래퍼 ──

  /// 숫자 하나가 두 줄(행 둘 또는 열 둘)에서 각각 두 칸뿐이고, 그중 한 칸씩은 같은 줄(기둥)에 있을 때
  /// 나머지 두 칸(지붕) 중 하나는 반드시 그 숫자다. 지붕 두 칸이 모두 보는 칸에서 그 숫자를 지운다.
  static SolveStep? skyscraper(CandidateGrid g) {
    for (var d = 1; d <= 9; d++) {
      final b = bit(d);
      for (final byRow in [true, false]) {
        final strong = <(int, int, int)>[]; // (줄, 위치1, 위치2)
        for (var line = 0; line < 9; line++) {
          final xs = [for (var x = 0; x < 9; x++) if (g.cand[_cellAt(byRow, line, x)] & b != 0) x];
          if (xs.length == 2) strong.add((line, xs[0], xs[1]));
        }
        for (var i = 0; i < strong.length; i++) {
          for (var j = i + 1; j < strong.length; j++) {
            final (l1, a1, b1) = strong[i];
            final (l2, a2, b2) = strong[j];
            final shared = {a1, b1}.intersection({a2, b2});
            if (shared.length != 1) continue; // 둘 다 같으면 X-윙
            final base = shared.first;
            final roof1 = a1 == base ? b1 : a1;
            final roof2 = a2 == base ? b2 : a2;
            final e1 = _cellAt(byRow, l1, roof1), e2 = _cellAt(byRow, l2, roof2);
            final base1 = _cellAt(byRow, l1, base), base2 = _cellAt(byRow, l2, base);
            final elim = _commonElims(g, e1, e2, b, {base1, base2});
            if (elim.isEmpty) continue;
            return SolveStep(
              technique: Technique.skyscraper,
              cells: [e1, base1, base2, e2],
              digits: b,
              units: [_unitOf(byRow, l1), _unitOf(byRow, l2)],
              eliminations: elim,
            );
          }
        }
      }
    }
    return null;
  }

  // ── 투스트링 카이트 ──

  /// 한 행에서 두 칸뿐, 한 열에서 두 칸뿐인 숫자. 행의 한 칸과 열의 한 칸이 같은 박스에 있으면 (연 줄처럼 이어져),
  /// 박스 밖에 남은 두 칸 중 하나는 반드시 그 숫자다. 두 칸이 모두 보는 칸에서 지운다.
  static SolveStep? twoStringKite(CandidateGrid g) {
    for (var d = 1; d <= 9; d++) {
      final b = bit(d);
      final rows = <List<int>>[];
      final cols = <List<int>>[];
      for (var line = 0; line < 9; line++) {
        final r = _with(g, unitCells[line], b);
        if (r.length == 2) rows.add(r);
        final c = _with(g, unitCells[9 + line], b);
        if (c.length == 2) cols.add(c);
      }
      for (final r in rows) {
        for (final c in cols) {
          for (var i = 0; i < 2; i++) {
            for (var j = 0; j < 2; j++) {
              final x = r[i], y = c[j];
              if (x == y || boxOf[x] != boxOf[y]) continue;
              final x2 = r[1 - i], y2 = c[1 - j];
              if (x2 == y2 || x2 == y || y2 == x) continue;
              final elim = _commonElims(g, x2, y2, b, {x, y});
              if (elim.isEmpty) continue;
              return SolveStep(
                technique: Technique.twoStringKite,
                cells: [x2, x, y, y2],
                digits: b,
                unit: 18 + boxOf[x],
                units: [rowOf[x], 9 + colOf[y]],
                eliminations: elim,
              );
            }
          }
        }
      }
    }
    return null;
  }

  // ── 빈 직사각형 ──

  /// 박스 안의 한 숫자 후보가 "십자(한 행 + 한 열)"에만 있을 때, 박스 밖의 줄에서 그 숫자가 두 칸뿐이고 한 칸이 십자의 줄에 걸리면
  /// 십자의 다른 줄 위의 한 칸에서 그 숫자를 지울 수 있다.
  static SolveStep? emptyRectangle(CandidateGrid g) {
    for (var d = 1; d <= 9; d++) {
      final b = bit(d);
      for (var box = 0; box < 9; box++) {
        final cells = _with(g, unitCells[18 + box], b);
        if (cells.length < 3) continue; // 두 칸이면 어느 쪽으로든 한 줄에 놓여 포인팅이 된다
        if (cells.every((c) => rowOf[c] == rowOf[cells.first]) || cells.every((c) => colOf[c] == colOf[cells.first])) continue;
        final r0 = (box ~/ 3) * 3, c0 = (box % 3) * 3;
        for (var R = r0; R < r0 + 3; R++) {
          for (var C = c0; C < c0 + 3; C++) {
            if (!cells.every((c) => rowOf[c] == R || colOf[c] == C)) continue;
            if (!cells.any((c) => rowOf[c] == R && colOf[c] != C) || !cells.any((c) => colOf[c] == C && rowOf[c] != R)) continue;
            // (1) 박스 밖의 열 K: 그 숫자가 두 칸뿐이고 한 칸이 십자의 행 R 위에 있다 → 다른 칸 (x, K)의 행에서 십자의 열 C와 만나는 칸
            for (var K = 0; K < 9; K++) {
              if (K >= c0 && K < c0 + 3) continue;
              final pair = _with(g, unitCells[9 + K], b);
              if (pair.length != 2 || !pair.any((c) => rowOf[c] == R)) continue;
              final other = pair.firstWhere((c) => rowOf[c] != R);
              final x = rowOf[other];
              if (x >= r0 && x < r0 + 3) continue;
              final t = x * 9 + C;
              if (g.cand[t] & b == 0) continue;
              return SolveStep(
                technique: Technique.emptyRectangle,
                cells: [...cells, ...pair],
                digits: b,
                unit: 18 + box,
                units: [R, 9 + C, 9 + K],
                eliminations: {t: b},
                note: 'col,$R,$C,$other,${pair.firstWhere((c) => rowOf[c] == R)}',
              );
            }
            // (2) 박스 밖의 행 L: 그 숫자가 두 칸뿐이고 한 칸이 십자의 열 C 위에 있다 → 다른 칸 (L, y)의 열에서 십자의 행 R과 만나는 칸
            for (var L = 0; L < 9; L++) {
              if (L >= r0 && L < r0 + 3) continue;
              final pair = _with(g, unitCells[L], b);
              if (pair.length != 2 || !pair.any((c) => colOf[c] == C)) continue;
              final other = pair.firstWhere((c) => colOf[c] != C);
              final y = colOf[other];
              if (y >= c0 && y < c0 + 3) continue;
              final t = R * 9 + y;
              if (g.cand[t] & b == 0) continue;
              return SolveStep(
                technique: Technique.emptyRectangle,
                cells: [...cells, ...pair],
                digits: b,
                unit: 18 + box,
                units: [R, 9 + C, L],
                eliminations: {t: b},
                note: 'row,$R,$C,$other,${pair.firstWhere((c) => colOf[c] == C)}',
              );
            }
          }
        }
      }
    }
    return null;
  }

  // ── 유니크 직사각형 ──

  /// 네 칸이 두 박스에 걸쳐 직사각형을 이루고 같은 두 숫자 {a, b}만 후보라면, 퍼즐의 해가 둘이 되어 버린다("죽은 패턴").
  /// 해는 하나뿐이니 이 패턴을 피하도록 후보를 지울 수 있다. (타입 1: 한 칸만 군더더기가 있을 때 / 타입 2: 두 칸에 같은 군더더기가 있을 때)
  static SolveStep? uniqueRectangle(CandidateGrid g) {
    for (var r1 = 0; r1 < 9; r1++) {
      for (var r2 = r1 + 1; r2 < 9; r2++) {
        for (var c1 = 0; c1 < 9; c1++) {
          for (var c2 = c1 + 1; c2 < 9; c2++) {
            final q = [r1 * 9 + c1, r1 * 9 + c2, r2 * 9 + c1, r2 * 9 + c2];
            if (q.any((c) => g.values[c] != 0)) continue;
            if (q.map((c) => boxOf[c]).toSet().length != 2) continue;
            final common = q.map((c) => g.cand[c]).reduce((a, b) => a & b);
            if (popCount(common) < 2) continue;
            for (final pair in _pairsOf(common)) {
              final extra = [for (final c in q) g.cand[c] & ~pair];
              final bi = [for (var i = 0; i < 4; i++) if (extra[i] == 0) i]; // {a,b}만 가진 칸
              // 타입 1: 세 칸이 {a,b}뿐, 한 칸에 군더더기
              if (bi.length == 3) {
                final t = q[[for (var i = 0; i < 4; i++) if (extra[i] != 0) i].first];
                return SolveStep(
                  technique: Technique.uniqueRectangle,
                  cells: q,
                  digits: pair,
                  eliminations: {t: pair},
                  note: '1',
                );
              }
              // 타입 2: 두 칸이 {a,b}뿐, 나머지 두 칸이 똑같은 군더더기 한 숫자
              if (bi.length == 2) {
                final roofs = [for (var i = 0; i < 4; i++) if (extra[i] != 0) i];
                final e0 = extra[roofs[0]], e1 = extra[roofs[1]];
                if (e0 != e1 || popCount(e0) != 1) continue;
                final ra = q[roofs[0]], rb = q[roofs[1]];
                if (!sees(ra, rb)) continue; // 지붕 두 칸은 같은 줄이어야 한다
                final elim = _commonElims(g, ra, rb, e0, q.toSet());
                if (elim.isEmpty) continue;
                return SolveStep(
                  technique: Technique.uniqueRectangle,
                  cells: q,
                  digits: pair,
                  eliminations: elim,
                  note: '2',
                );
              }
            }
          }
        }
      }
    }
    return null;
  }

  /// 마스크에서 두 숫자씩 고른 모든 조합.
  static List<int> _pairsOf(int mask) {
    final ds = digitsOf(mask);
    return [
      for (var i = 0; i < ds.length; i++)
        for (var j = i + 1; j < ds.length; j++) bit(ds[i]) | bit(ds[j]),
    ];
  }

  // ── BUG+1 ──

  /// 빈 칸이 모두 후보 두 개뿐인데 딱 한 칸만 후보가 세 개라면, 그대로 두면 해가 둘 이상인 "BUG" 모양이 된다.
  /// 해가 하나뿐이니 그 칸은 BUG를 깨는 숫자(행·열·박스에서 후보가 세 번 나오는 숫자)여야 한다.
  static SolveStep? bugPlusOne(CandidateGrid g) {
    var odd = -1;
    for (var i = 0; i < 81; i++) {
      if (g.values[i] != 0) continue;
      final n = popCount(g.cand[i]);
      if (n == 2) continue;
      if (n == 3 && odd < 0) {
        odd = i;
        continue;
      }
      return null;
    }
    if (odd < 0) return null;
    // 이 칸의 유닛에서는 한 숫자 d만 후보가 세 번, 나머지 모든 (유닛, 숫자)는 0번 또는 2번 나와야 BUG+1이다
    for (final d in digitsOf(g.cand[odd])) {
      var ok = true;
      for (var u = 0; u < 27 && ok; u++) {
        for (var e = 1; e <= 9 && ok; e++) {
          final n = _with(g, unitCells[u], bit(e)).length;
          final tripled = e == d && unitCells[u].contains(odd);
          if (tripled ? n != 3 : !(n == 0 || n == 2)) ok = false;
        }
      }
      if (!ok) continue;
      return SolveStep(
        technique: Technique.bugPlusOne,
        cells: [odd],
        digits: bit(d),
        placeCell: odd,
        placeDigit: d,
      );
    }
    return null;
  }

  // ── XY-체인 ──

  /// 후보가 두 개뿐인 칸들이 "서로 보는 칸 · 겹치는 숫자"로 이어진 사슬. 사슬의 양 끝이 같은 숫자 x를 가지면 둘 중 하나는 반드시 x다.
  /// 양 끝이 모두 보는 칸에서 x를 지운다. (네 칸 이상 이어진 것; 세 칸은 XY-윙)
  static SolveStep? xyChain(CandidateGrid g) {
    final bi = [for (var i = 0; i < 81; i++) if (g.values[i] == 0 && popCount(g.cand[i]) == 2) i];
    final isBi = {for (final c in bi) c};
    const maxLen = 8;
    SolveStep? found;

    void dfs(List<int> chain, int x, int out) {
      if (found != null) return;
      final last = chain.last;
      for (final nx in peers[last]) {
        if (!isBi.contains(nx) || chain.contains(nx) || g.cand[nx] & bit(out) == 0) continue;
        final other = g.cand[nx] & ~bit(out);
        final nextOut = digitsOf(other).first;
        final path = [...chain, nx];
        if (nextOut == x && path.length >= 4) {
          final elim = _commonElims(g, path.first, nx, bit(x), path.toSet());
          if (elim.isNotEmpty) {
            found = SolveStep(technique: Technique.xyChain, cells: path, digits: bit(x), eliminations: elim);
            return;
          }
        }
        if (path.length < maxLen) dfs(path, x, nextOut);
        if (found != null) return;
      }
    }

    for (final c0 in bi) {
      for (final x in digitsOf(g.cand[c0])) {
        final out = digitsOf(g.cand[c0] & ~bit(x)).first;
        dfs([c0], x, out);
        if (found != null) return found;
      }
    }
    return null;
  }

  // ── X-체인 ──

  /// 한 숫자의 "강한 연결"(유닛에서 두 칸뿐)과 "약한 연결"(서로 보는 칸)을 번갈아 이은 사슬. 양 끝이 모두 보는 칸에서 그 숫자를 지운다.
  /// (강한 연결 셋 이상; 둘이면 스카이스크래퍼·카이트)
  static SolveStep? xChain(CandidateGrid g) {
    for (var d = 1; d <= 9; d++) {
      final b = bit(d);
      // 강한 연결 상대
      final partners = <int, List<int>>{};
      for (var u = 0; u < 27; u++) {
        final cs = _with(g, unitCells[u], b);
        if (cs.length == 2) {
          partners.putIfAbsent(cs[0], () => []).add(cs[1]);
          partners.putIfAbsent(cs[1], () => []).add(cs[0]);
        }
      }
      if (partners.length < 6) continue;
      SolveStep? found;
      void dfs(List<int> path) {
        if (found != null) return;
        final tail = path.last;
        // 약한 연결로 건너가서 다시 강한 연결을 탄다
        for (final n2 in partners.keys) {
          if (path.contains(n2) || !sees(tail, n2)) continue;
          for (final n3 in partners[n2]!) {
            if (path.contains(n3) || n3 == n2) continue;
            final next = [...path, n2, n3];
            if (next.length >= 6) {
              final elim = _commonElims(g, next.first, n3, b, next.toSet());
              if (elim.isNotEmpty) {
                found = SolveStep(technique: Technique.xChain, cells: next, digits: b, eliminations: elim);
                return;
              }
            }
            if (next.length < 8) dfs(next);
            if (found != null) return;
          }
        }
      }

      for (final s0 in partners.keys) {
        for (final s1 in partners[s0]!) {
          dfs([s0, s1]);
          if (found != null) return found;
        }
      }
    }
    return null;
  }

  // ── ALS-XZ ──

  /// ALS(거의 잠긴 집합): 한 유닛의 칸 n개에 후보 숫자가 n+1개. 두 ALS가 공통 숫자 X를 "서로 다 보는" 방식으로 공유하고
  /// 또 다른 공통 숫자 Z가 있으면, 어느 쪽이든 한쪽 ALS가 Z를 차지한다. 두 ALS의 모든 Z 칸이 보는 칸에서 Z를 지운다.
  static SolveStep? alsXz(CandidateGrid g) {
    final als = _findAls(g);
    for (var i = 0; i < als.length; i++) {
      for (var j = i + 1; j < als.length; j++) {
        final a = als[i], b = als[j];
        if (a.cells.any(b.cells.contains)) continue;
        final common = a.digits & b.digits;
        if (popCount(common) < 2) continue;
        for (final x in digitsOf(common)) {
          final bx = bit(x);
          final ax = _with(g, a.cells, bx), bxc = _with(g, b.cells, bx);
          if (!ax.every((p) => bxc.every((q) => sees(p, q)))) continue; // X가 제한되어 있어야 한다
          for (final z in digitsOf(common & ~bx)) {
            final bz = bit(z);
            final zs = [..._with(g, a.cells, bz), ..._with(g, b.cells, bz)];
            final skip = {...a.cells, ...b.cells};
            final elim = <int, int>{
              for (var t = 0; t < 81; t++)
                if (g.values[t] == 0 && !skip.contains(t) && g.cand[t] & bz != 0 && zs.every((p) => sees(t, p))) t: bz,
            };
            if (elim.isEmpty) continue;
            return SolveStep(
              technique: Technique.alsXz,
              cells: [...a.cells, ...b.cells],
              digits: bx | bz,
              eliminations: elim,
              note: '$x,$z,${a.cells.length}', // X, Z, 앞 ALS의 칸 수 (설명용)
            );
          }
        }
      }
    }
    return null;
  }

  static List<_Als> _findAls(CandidateGrid g) {
    final out = <_Als>[];
    final seen = <String>{};
    for (var u = 0; u < 27; u++) {
      final open = [for (final c in unitCells[u]) if (g.values[c] == 0) c];
      final n = open.length;
      for (var mask = 1; mask < (1 << n); mask++) {
        final size = popCount(mask);
        if (size > 4) continue;
        var union = 0;
        final cells = <int>[];
        for (var k = 0; k < n; k++) {
          if (mask & (1 << k) == 0) continue;
          cells.add(open[k]);
          union |= g.cand[open[k]];
        }
        if (popCount(union) != size + 1) continue;
        final key = (cells..sort()).join(',');
        if (!seen.add(key)) continue;
        out.add(_Als(cells, union));
      }
    }
    return out;
  }

  // ── 가정법 (포싱 체인) ──

  /// 어떤 칸에 어떤 숫자가 들어간다고 "가정"하고 쉬운 규칙(싱글)만 따라가 보면 모순이 생기는 경우, 그 가정은 틀렸으니 그 후보를 지운다.
  static SolveStep? forcingChain(CandidateGrid g) {
    final order = [for (var i = 0; i < 81; i++) if (g.values[i] == 0) i]..sort((a, b) => popCount(g.cand[a]).compareTo(popCount(g.cand[b])));
    for (final c in order) {
      for (final d in digitsOf(g.cand[c])) {
        final why = _contradiction(g, c, d);
        if (why != null) {
          return SolveStep(
            technique: Technique.forcingChain,
            cells: [c],
            digits: bit(d),
            eliminations: {c: bit(d)},
            note: why,
          );
        }
      }
    }
    return null;
  }

  /// [cell]에 [digit]을 넣고 싱글만으로 따라가다 모순이 생기면 그 모습을 글로, 아니면 null.
  static String? _contradiction(CandidateGrid g, int cell, int digit) {
    final values = List<int>.of(g.values);
    final cand = List<int>.of(g.cand);

    String? place(int c, int d) {
      values[c] = d;
      cand[c] = 0;
      final m = ~bit(d);
      for (final p in peers[c]) {
        if (values[p] == d) return '${_cn(c)}과 ${_cn(p)}에 같은 숫자 $d${_josa(d)} 겹쳐요';
        if (values[p] == 0) {
          cand[p] &= m;
          if (cand[p] == 0) return '${_cn(p)}에 들어갈 숫자가 하나도 남지 않아요';
        }
      }
      return null;
    }

    var bad = place(cell, digit);
    if (bad != null) return bad;
    for (var guard = 0; guard < 200; guard++) {
      var progressed = false;
      for (var i = 0; i < 81; i++) {
        if (values[i] == 0 && popCount(cand[i]) == 1) {
          bad = place(i, digitsOf(cand[i]).first);
          if (bad != null) return bad;
          progressed = true;
        }
      }
      for (var u = 0; u < 27; u++) {
        for (var d = 1; d <= 9; d++) {
          final b = bit(d);
          var placed = false;
          var cnt = 0, pos = -1;
          for (final c in unitCells[u]) {
            if (values[c] == d) placed = true;
            if (values[c] == 0 && cand[c] & b != 0) {
              cnt++;
              pos = c;
            }
          }
          if (placed) continue;
          if (cnt == 0) return '${unitNameOf(u)}에서 $d${_josa(d)} 들어갈 곳이 없어져요';
          if (cnt == 1) {
            bad = place(pos, d);
            if (bad != null) return bad;
            progressed = true;
          }
        }
      }
      if (!progressed) return null;
    }
    return null;
  }

  static String _cn(int c) => '${rowOf[c] + 1}행 ${colOf[c] + 1}열';
  static String _josa(int d) => const {1, 3, 6, 7, 8}.contains(d) ? '이' : '가';

  /// 설명 글에서 쓰는 유닛 이름 (행·열·박스).
  static String unitNameOf(int u) {
    if (u < 9) return '${u + 1}행';
    if (u < 18) return '${u - 8}열';
    return '${u - 17}번째 박스';
  }
}

class _Als {
  const _Als(this.cells, this.digits);

  final List<int> cells;
  final int digits;
}
