/// 프리셀 규칙 엔진 (화면과 무관한 순수 로직).
///
/// 카드는 0~51 한 개의 숫자: 숫자 = 계급*4 + 무늬. 계급 0=A … 12=K.
/// 무늬 0=클로버 ♣, 1=다이아 ♦, 2=하트 ♥, 3=스페이드 ♠ (마이크로소프트 프리셀과 같은 순서).
library;

import 'dart:math';

int rankOf(int card) => card >> 2;
int suitOf(int card) => card & 3;
bool isRedSuit(int suit) => suit == 1 || suit == 2;
bool isRedCard(int card) => isRedSuit(suitOf(card));

const List<String> kRankLabels = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
const List<String> kSuitLetters = ['C', 'D', 'H', 'S'];

/// 사람이 읽는 이름. 예: "JD" = 다이아 J.
String cardLabel(int card) => '${kRankLabels[rankOf(card)] == '10' ? 'T' : kRankLabels[rankOf(card)]}'
    '${kSuitLetters[suitOf(card)]}';

/// 풀 수 없는 것으로 알려진 유일한 번호 (1~32000 중).
const int kUnsolvableDeal = 11982;
const int kMaxDeal = 32000;

enum Place { column, cell, foundation }

/// 한 수: [from]의 [fromIndex]에서 카드 [count]장을 [to]의 [toIndex]로.
/// 완성 칸(foundation)의 번호는 무늬 번호와 같다.
class FcMove {
  const FcMove(this.from, this.fromIndex, this.to, this.toIndex, [this.count = 1]);

  final Place from;
  final int fromIndex;
  final Place to;
  final int toIndex;
  final int count;

  int get code => ((((from.index * 16 + fromIndex) * 16 + (count - 1)) * 4 + to.index) * 16) + toIndex;

  static FcMove fromCode(int code) {
    final toIndex = code % 16;
    var r = code ~/ 16;
    final to = Place.values[r % 4];
    r ~/= 4;
    final count = r % 16 + 1;
    r ~/= 16;
    final fromIndex = r % 16;
    final from = Place.values[r ~/ 16];
    return FcMove(from, fromIndex, to, toIndex, count);
  }

  @override
  bool operator ==(Object other) => other is FcMove && other.code == code;

  @override
  int get hashCode => code;

  @override
  String toString() => 'FcMove(${from.name}$fromIndex x$count → ${to.name}$toIndex)';
}

class FcState {
  FcState(this.columns, this.cells, this.found);

  /// 번호로 판을 만든다 (마이크로소프트 프리셀과 같은 섞기 → 같은 번호는 늘 같은 판).
  factory FcState.deal(int deal) {
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
    final columns = List.generate(8, (_) => <int>[]);
    for (var i = 0; i < 52; i++) {
      columns[i % 8].add(cards[i]);
    }
    return FcState(columns, List<int>.filled(4, -1), List<int>.filled(4, 0));
  }

  /// 8개 열. 각 열은 아래(처음 깔린 카드)→위(맨 위, 움직일 수 있는 카드) 순서.
  final List<List<int>> columns;

  /// 프리셀 4칸 (-1 = 빔).
  final List<int> cells;

  /// 무늬별로 완성 칸에 올라간 카드 수 (A부터 차례로 올라가므로 다음에 올릴 계급과 같다).
  final List<int> found;

  FcState copy() => FcState(
        [for (final c in columns) List<int>.of(c)],
        List<int>.of(cells),
        List<int>.of(found),
      );

  int get freeCells => cells.where((c) => c < 0).length;
  int get emptyColumns => columns.where((c) => c.isEmpty).length;
  int get foundationTotal => found.fold(0, (a, b) => a + b);
  bool get isWon => foundationTotal == 52;

  bool canFoundation(int card) => found[suitOf(card)] == rankOf(card);

  /// [card]를 [column] 맨 위에 올릴 수 있는가 (빈 열이거나, 색이 다르고 계급이 하나 낮을 때).
  static bool fitsOn(int card, List<int> column) {
    if (column.isEmpty) return true;
    final top = column.last;
    return rankOf(top) == rankOf(card) + 1 && isRedCard(top) != isRedCard(card);
  }

  /// 열 맨 위에서부터 이어진 "색이 번갈아 계급이 내려가는" 줄의 길이.
  int runLength(int column) {
    final col = columns[column];
    if (col.isEmpty) return 0;
    var n = 1;
    while (n < col.length) {
      final lower = col[col.length - n - 1];
      final upper = col[col.length - n];
      if (rankOf(lower) == rankOf(upper) + 1 && isRedCard(lower) != isRedCard(upper)) {
        n++;
      } else {
        break;
      }
    }
    return n;
  }

  /// 한꺼번에 옮길 수 있는 카드 수의 한도. (빈 프리셀 + 1) × 2^(빈 열 수)
  int maxMovable({required bool toEmptyColumn}) {
    final empties = max(0, emptyColumns - (toEmptyColumn ? 1 : 0));
    return (freeCells + 1) * (1 << empties);
  }

  bool isLegal(FcMove m) {
    switch (m.from) {
      case Place.foundation:
        return false;
      case Place.column:
        if (m.fromIndex < 0 || m.fromIndex > 7) return false;
        final col = columns[m.fromIndex];
        final n = m.count;
        if (n < 1 || n > col.length || n > runLength(m.fromIndex)) return false;
        final card = col[col.length - n];
        switch (m.to) {
          case Place.foundation:
            return n == 1 && canFoundation(card) && m.toIndex == suitOf(card);
          case Place.cell:
            return n == 1 && m.toIndex >= 0 && m.toIndex < 4 && cells[m.toIndex] < 0;
          case Place.column:
            if (m.toIndex == m.fromIndex || m.toIndex < 0 || m.toIndex > 7) return false;
            final dest = columns[m.toIndex];
            return fitsOn(card, dest) && n <= maxMovable(toEmptyColumn: dest.isEmpty);
        }
      case Place.cell:
        if (m.fromIndex < 0 || m.fromIndex > 3 || m.count != 1) return false;
        final card = cells[m.fromIndex];
        if (card < 0) return false;
        switch (m.to) {
          case Place.foundation:
            return canFoundation(card) && m.toIndex == suitOf(card);
          case Place.column:
            return m.toIndex >= 0 && m.toIndex < 8 && fitsOn(card, columns[m.toIndex]);
          case Place.cell:
            return false;
        }
    }
  }

  /// 수를 둔다. (합법인지는 확인하지 않는다 → 먼저 [isLegal])
  void apply(FcMove m) {
    final List<int> moved;
    if (m.from == Place.column) {
      final col = columns[m.fromIndex];
      moved = col.sublist(col.length - m.count);
      col.removeRange(col.length - m.count, col.length);
    } else {
      moved = [cells[m.fromIndex]];
      cells[m.fromIndex] = -1;
    }
    switch (m.to) {
      case Place.column:
        columns[m.toIndex].addAll(moved);
      case Place.cell:
        cells[m.toIndex] = moved.first;
      case Place.foundation:
        found[m.toIndex]++;
    }
  }

  /// 맨 위 카드(또는 프리셀 카드) 하나를 들고 있는 칸의 카드.
  int? topOfColumn(int column) => columns[column].isEmpty ? null : columns[column].last;

  /// 놓을 수 있는 모든 합법적인 수. [forSolver]면 풀이에 도움이 안 되는 수와 대칭인 수를 뺀다.
  List<FcMove> legalMoves({bool forSolver = false}) {
    final moves = <FcMove>[];

    // 완성 칸으로
    for (var i = 0; i < 8; i++) {
      final top = topOfColumn(i);
      if (top != null && canFoundation(top)) {
        moves.add(FcMove(Place.column, i, Place.foundation, suitOf(top)));
      }
    }
    for (var k = 0; k < 4; k++) {
      final c = cells[k];
      if (c >= 0 && canFoundation(c)) {
        moves.add(FcMove(Place.cell, k, Place.foundation, suitOf(c)));
      }
    }

    // 열 → 열 (여러 장 포함)
    var emptySeen = false;
    for (var j = 0; j < 8; j++) {
      final dest = columns[j];
      if (forSolver && dest.isEmpty) {
        if (emptySeen) continue; // 빈 열은 모두 같으니 하나만
        emptySeen = true;
      }
      final limit = maxMovable(toEmptyColumn: dest.isEmpty);
      for (var i = 0; i < 8; i++) {
        if (i == j || columns[i].isEmpty) continue;
        final run = min(runLength(i), limit);
        for (var n = 1; n <= run; n++) {
          final card = columns[i][columns[i].length - n];
          if (!fitsOn(card, dest)) continue;
          // 열 전체를 빈 열로 옮기는 건 아무 변화가 없다
          if (forSolver && dest.isEmpty && n == columns[i].length) continue;
          moves.add(FcMove(Place.column, i, Place.column, j, n));
        }
      }
    }

    // 프리셀 → 열
    emptySeen = false;
    for (var j = 0; j < 8; j++) {
      final dest = columns[j];
      if (forSolver && dest.isEmpty) {
        if (emptySeen) continue;
        emptySeen = true;
      }
      for (var k = 0; k < 4; k++) {
        final c = cells[k];
        if (c >= 0 && fitsOn(c, dest)) moves.add(FcMove(Place.cell, k, Place.column, j));
      }
    }

    // 열 → 프리셀
    for (var i = 0; i < 8; i++) {
      if (columns[i].isEmpty) continue;
      for (var k = 0; k < 4; k++) {
        if (cells[k] < 0) {
          moves.add(FcMove(Place.column, i, Place.cell, k));
          if (forSolver) break; // 빈 칸은 모두 같다
        }
      }
    }
    return moves;
  }

  /// 완성 칸으로 올려도 손해가 없는(다른 카드가 이 카드를 받침으로 쓸 일이 없는) 수. 없으면 null.
  FcMove? safeAutoMove() {
    bool safe(int card) {
      final r = rankOf(card);
      if (r <= 1) return true;
      final a = isRedCard(card) ? 0 : 1;
      final b = isRedCard(card) ? 3 : 2;
      return found[a] >= r && found[b] >= r;
    }

    FcMove? best;
    var bestRank = 99;
    for (var i = 0; i < 8; i++) {
      final top = topOfColumn(i);
      if (top != null && canFoundation(top) && safe(top) && rankOf(top) < bestRank) {
        bestRank = rankOf(top);
        best = FcMove(Place.column, i, Place.foundation, suitOf(top));
      }
    }
    for (var k = 0; k < 4; k++) {
      final c = cells[k];
      if (c >= 0 && canFoundation(c) && safe(c) && rankOf(c) < bestRank) {
        bestRank = rankOf(c);
        best = FcMove(Place.cell, k, Place.foundation, suitOf(c));
      }
    }
    return best;
  }

  /// 모든 열이 위로 갈수록 계급이 작아지는 상태 → 나머지는 자동으로 전부 올릴 수 있다.
  bool get canFinishAutomatically {
    for (final col in columns) {
      for (var i = 1; i < col.length; i++) {
        if (rankOf(col[i]) > rankOf(col[i - 1])) return false;
      }
    }
    return true;
  }

  /// 같은 상황(열 순서·프리셀 칸 위치만 다른 것)을 같은 문자열로 만든다. 풀이기의 중복 검사용.
  String get key {
    final cols = [for (final c in columns) c.join(',')]..sort();
    final cs = cells.where((c) => c >= 0).toList()..sort();
    return '${cols.join('|')}#${cs.join(',')}#${found.join(',')}';
  }
}
