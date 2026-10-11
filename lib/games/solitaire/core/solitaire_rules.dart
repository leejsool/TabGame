/// 솔리테어(클론다이크) 규칙 엔진 (화면과 무관한 순수 로직).
///
/// 카드는 프리셀과 같은 0~51 숫자: 숫자 = 계급*4 + 무늬. 계급 0=A … 12=K.
/// 무늬 0=클로버 ♣, 1=다이아 ♦, 2=하트 ♥, 3=스페이드 ♠.
library;

import '../../freecell/core/freecell_rules.dart' show rankOf, suitOf, isRedCard;

export '../../freecell/core/freecell_rules.dart' show rankOf, suitOf, isRedCard, isRedSuit, kRankLabels;

/// 판 번호 범위.
const int kMaxSolitaireDeal = 99999;

enum SolKind {
  /// 더미에서 [SolState.draw]장 뽑기.
  draw,

  /// 더미가 비었을 때 버린 카드를 뒤집어 더미로.
  recycle,
  wasteToCol,
  wasteToFound,
  colToCol,
  colToFound,
  foundToCol,
}

/// 한 수. [from]/[to]는 열 번호(0~6), 완성 칸으로 갈 때는 쓰지 않고, 완성 칸에서 나올 때 [from]은 무늬.
class SolMove {
  const SolMove(this.kind, {this.from = 0, this.to = 0, this.count = 1});

  static const draw = SolMove(SolKind.draw);
  static const recycle = SolMove(SolKind.recycle);

  final SolKind kind;
  final int from;
  final int to;
  final int count;

  int get code => (((kind.index * 8 + from) * 8) + to) * 16 + count;

  static SolMove fromCode(int code) {
    final count = code % 16;
    var r = code ~/ 16;
    final to = r % 8;
    r ~/= 8;
    final from = r % 8;
    return SolMove(SolKind.values[r ~/ 8], from: from, to: to, count: count);
  }

  @override
  bool operator ==(Object other) => other is SolMove && other.code == code;

  @override
  int get hashCode => code;

  @override
  String toString() => 'SolMove(${kind.name} $from→$to x$count)';
}

class SolState {
  SolState(this.tableau, this.up, this.stock, this.waste, this.found, this.fan, {this.draw = 1});

  /// 번호로 판을 만든다 (같은 번호 + 같은 뽑기 장수 = 늘 같은 판).
  factory SolState.deal(int deal, {int draw = 1}) {
    final deck = List<int>.generate(52, (i) => i);
    var left = 52;
    var seed = deal & 0xFFFFFFFF;
    final cards = List<int>.filled(52, 0);
    for (var i = 0; i < 52; i++) {
      seed = (seed * 214013 + 2531011) & 0xFFFFFFFF;
      final j = ((seed >> 16) & 0x7FFF) % left;
      cards[i] = deck[j];
      left--;
      deck[j] = deck[left];
    }
    final tableau = <List<int>>[];
    var p = 0;
    for (var col = 0; col < 7; col++) {
      tableau.add(cards.sublist(p, p + col + 1));
      p += col + 1;
    }
    return SolState(
      tableau,
      List<int>.filled(7, 1),
      cards.sublist(p), // 24장. 뽑을 때는 끝에서부터.
      <int>[],
      List<int>.filled(4, 0),
      0,
      draw: draw,
    );
  }

  /// 7개 열. 맨 뒤가 맨 위(보이는 쪽) 카드.
  final List<List<int>> tableau;

  /// 열마다 앞면인 카드 수 (맨 위쪽 [up]장이 앞면).
  final List<int> up;

  /// 뽑을 더미 (끝에서부터 뽑는다) / 버린 카드 (맨 뒤가 맨 위).
  final List<int> stock;
  final List<int> waste;

  /// 무늬별 완성 칸에 쌓인 카드 수 (A만 있으면 1).
  final List<int> found;

  /// 버린 카드 중 맨 위에서 펼쳐 보여줄 장수 (3장 뽑기에서 최근에 뽑은 카드들).
  int fan;

  /// 한 번에 뽑는 장수 (1 또는 3).
  final int draw;

  SolState copy() => SolState(
        [for (final c in tableau) List<int>.of(c)],
        List<int>.of(up),
        List<int>.of(stock),
        List<int>.of(waste),
        List<int>.of(found),
        fan,
        draw: draw,
      );

  bool get isWon => found.every((n) => n == 13);

  /// 뽑을 더미·버린 더미가 비었고 모든 카드가 앞면이면, 이제 반드시 끝까지 올릴 수 있다.
  bool get canFinishAutomatically =>
      stock.isEmpty && waste.isEmpty && !isWon && [for (var i = 0; i < 7; i++) up[i] == tableau[i].length].every((b) => b);

  int get faceDownCount => [for (var i = 0; i < 7; i++) tableau[i].length - up[i]].fold(0, (a, b) => a + b);

  int cardOfFound(int suit) => (found[suit] - 1) * 4 + suit;

  // ── 규칙 ──

  bool canPlaceOnCol(int card, int col) {
    final t = tableau[col];
    if (t.isEmpty) return rankOf(card) == 12;
    if (up[col] == 0) return false;
    final top = t.last;
    return isRedCard(top) != isRedCard(card) && rankOf(top) == rankOf(card) + 1;
  }

  bool canPlaceOnFound(int card) => found[suitOf(card)] == rankOf(card);

  /// 손해 없이 완성 칸으로 올려도 되는 카드인가 (더 이상 열에서 쓸 일이 없는 카드).
  bool isSafeForFound(int card) {
    final r = rankOf(card);
    if (!canPlaceOnFound(card)) return false;
    if (r <= 1) return true;
    final opp = isRedCard(card) ? const [0, 3] : const [1, 2];
    return found[opp[0]] >= r && found[opp[1]] >= r;
  }

  List<SolMove> legalMoves() {
    final moves = <SolMove>[];
    if (stock.isNotEmpty) {
      moves.add(SolMove.draw);
    } else if (waste.isNotEmpty) {
      moves.add(SolMove.recycle);
    }
    if (waste.isNotEmpty) {
      final card = waste.last;
      if (canPlaceOnFound(card)) moves.add(const SolMove(SolKind.wasteToFound));
      for (var j = 0; j < 7; j++) {
        if (canPlaceOnCol(card, j)) moves.add(SolMove(SolKind.wasteToCol, to: j));
      }
    }
    for (var i = 0; i < 7; i++) {
      final t = tableau[i];
      if (up[i] == 0) continue;
      if (canPlaceOnFound(t.last)) moves.add(SolMove(SolKind.colToFound, from: i));
      for (var k = 1; k <= up[i]; k++) {
        final card = t[t.length - k];
        for (var j = 0; j < 7; j++) {
          if (j != i && canPlaceOnCol(card, j)) {
            moves.add(SolMove(SolKind.colToCol, from: i, to: j, count: k));
          }
        }
      }
    }
    for (var s = 0; s < 4; s++) {
      if (found[s] == 0) continue;
      final card = cardOfFound(s);
      for (var j = 0; j < 7; j++) {
        if (canPlaceOnCol(card, j)) moves.add(SolMove(SolKind.foundToCol, from: s, to: j));
      }
    }
    return moves;
  }

  bool isLegal(SolMove m) => legalMoves().contains(m);

  /// 수를 둔다. 합법이라고 가정한다 (호출하는 쪽이 확인).
  void apply(SolMove m) {
    switch (m.kind) {
      case SolKind.draw:
        final n = stock.length < draw ? stock.length : draw;
        for (var i = 0; i < n; i++) {
          waste.add(stock.removeLast());
        }
        fan = n;
      case SolKind.recycle:
        stock.addAll(waste.reversed);
        waste.clear();
        fan = 0;
      case SolKind.wasteToCol:
        tableau[m.to].add(waste.removeLast());
        up[m.to]++;
        _wasteShrank();
      case SolKind.wasteToFound:
        found[suitOf(waste.removeLast())]++;
        _wasteShrank();
      case SolKind.colToCol:
        final from = tableau[m.from];
        final moved = from.sublist(from.length - m.count);
        from.removeRange(from.length - m.count, from.length);
        tableau[m.to].addAll(moved);
        up[m.from] -= m.count;
        up[m.to] += m.count;
        _flip(m.from);
      case SolKind.colToFound:
        final card = tableau[m.from].removeLast();
        found[suitOf(card)]++;
        up[m.from]--;
        _flip(m.from);
      case SolKind.foundToCol:
        final card = cardOfFound(m.from);
        found[m.from]--;
        tableau[m.to].add(card);
        up[m.to]++;
    }
  }

  void _flip(int col) {
    if (tableau[col].isNotEmpty && up[col] == 0) up[col] = 1;
  }

  void _wasteShrank() {
    if (waste.isEmpty) {
      fan = 0;
    } else {
      fan = (fan - 1).clamp(1, waste.length < 3 ? waste.length : 3);
    }
  }

  // ── 막힘 / 힌트 ──

  /// 더미를 한 바퀴 넘겨 봐도 열이나 완성 칸으로 둘 수 있는 수가 하나도 없는가.
  bool get isStuck {
    if (isWon) return false;
    final s = copy();
    final limit = (stock.length + waste.length + 1) * 2 + 2;
    for (var i = 0; i < limit; i++) {
      for (final m in s.legalMoves()) {
        if (m.kind == SolKind.draw || m.kind == SolKind.recycle || m.kind == SolKind.foundToCol) continue;
        if (s._isPointless(m)) continue;
        return false;
      }
      if (s.stock.isEmpty && s.waste.isEmpty) break;
      s.apply(s.stock.isNotEmpty ? SolMove.draw : SolMove.recycle);
    }
    return true;
  }

  /// 열 전체를 (이미 맨 아래가 K인데) 빈 열로 옮기는 수처럼 아무 변화가 없는 수.
  bool _isPointless(SolMove m) {
    if (m.kind != SolKind.colToCol) return false;
    final t = tableau[m.from];
    return t.length == m.count && tableau[m.to].isEmpty;
  }

  /// 지금 두면 좋은 수 하나를 추천한다. 둘 수 있는 게 없으면 null.
  SolMove? hint() {
    final moves = legalMoves().where((m) => !_isPointless(m)).toList();
    SolMove? firstOf(bool Function(SolMove) test) {
      for (final m in moves) {
        if (test(m)) return m;
      }
      return null;
    }

    // 1. 뒤집힌 카드를 열어 주는 수 (가장 뒤집힌 카드가 많은 열부터)
    SolMove? reveal;
    var bestHidden = 0;
    for (final m in moves) {
      if (m.kind != SolKind.colToCol && m.kind != SolKind.colToFound) continue;
      final count = m.kind == SolKind.colToFound ? 1 : m.count;
      final hidden = tableau[m.from].length - up[m.from];
      if (up[m.from] == count && hidden > bestHidden) {
        bestHidden = hidden;
        reveal = m;
      }
    }
    if (reveal != null) return reveal;
    // 2. 안전하게 올릴 수 있는 카드
    final safe = firstOf((m) {
      if (m.kind == SolKind.wasteToFound) return isSafeForFound(waste.last);
      if (m.kind == SolKind.colToFound) return isSafeForFound(tableau[m.from].last);
      return false;
    });
    if (safe != null) return safe;
    // 3. 버린 카드를 열에 / K를 빈 열에
    final w = firstOf((m) => m.kind == SolKind.wasteToCol);
    if (w != null) return w;
    final k = firstOf((m) => m.kind == SolKind.colToCol && tableau[m.to].isEmpty);
    if (k != null) return k;
    // 4. 그 밖의 완성 칸 올리기 / 열 하나를 통째로 비우는 수
    final f = firstOf((m) => m.kind == SolKind.wasteToFound || m.kind == SolKind.colToFound);
    if (f != null) return f;
    final c = firstOf((m) => m.kind == SolKind.colToCol && tableau[m.from].length == m.count);
    if (c != null) return c;
    // 5. 뽑기 (한 바퀴 넘겨도 둘 수 있는 수가 없으면 추천하지 않는다)
    if (isStuck) return null;
    return firstOf((m) => m.kind == SolKind.draw || m.kind == SolKind.recycle);
  }
}
