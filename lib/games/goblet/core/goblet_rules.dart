/// 고블렛 고블러스 규칙 엔진 (화면과 무관한 순수 로직).
///
/// 3×3 판, 팀마다 크기 1·2·3 말이 각각 2개씩(총 6개).
/// 큰 말은 작은 말(내 것이든 상대 것이든)을 덮을 수 있고, 맨 위에 보이는 말로 가로·세로·대각선 3줄을 만들면 이긴다.
library;

enum Team {
  red('빨강팀'),
  blue('파랑팀');

  const Team(this.label);

  final String label;

  /// 판 위 소유자 번호 (0 = 없음).
  int get owner => index + 1;

  Team get other => this == Team.red ? Team.blue : Team.red;

  static Team fromOwner(int owner) => owner == 1 ? Team.red : Team.blue;
}

/// 한 수. [place]는 내 대기 말을 판에 올리는 것, [slide]는 판 위의 내 말(맨 위)을 옮기는 것.
class GobbletMove {
  const GobbletMove.place(this.size, this.to) : from = -1;
  const GobbletMove.slide(this.from, this.to, this.size);

  /// 옮기기 전 칸 (대기 말을 올리면 -1).
  final int from;
  final int to;

  /// 움직이는 말의 크기 (1~3).
  final int size;

  bool get isPlace => from < 0;

  @override
  bool operator ==(Object other) =>
      other is GobbletMove &&
      other.from == from &&
      other.to == to &&
      other.size == size;

  @override
  int get hashCode => Object.hash(from, to, size);

  @override
  String toString() => isPlace ? 'place($size→$to)' : 'slide($from→$to, $size)';
}

class GobbletBoard {
  GobbletBoard()
      : owners = List<int>.filled(27, 0),
        turn = 1;

  GobbletBoard.raw(this.owners, this.turn);

  /// 칸 c의 크기 s 말의 소유자는 owners[c*3 + s-1] (0 = 없음, 1 = 빨강, 2 = 파랑).
  /// 한 칸에는 크기마다 많아야 하나씩 쌓일 수 있고, 위에서 보이는 말은 가장 큰 말이다.
  final List<int> owners;

  /// 지금 둘 차례의 소유자 번호 (1 = 빨강이 선공).
  int turn;

  static const List<List<int>> lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], // 가로
    [0, 3, 6], [1, 4, 7], [2, 5, 8], // 세로
    [0, 4, 8], [2, 4, 6], // 대각선
  ];

  GobbletBoard copy() => GobbletBoard.raw(List<int>.of(owners), turn);

  Team get turnTeam => Team.fromOwner(turn);

  int topSize(int cell) {
    for (var s = 3; s >= 1; s--) {
      if (owners[cell * 3 + s - 1] != 0) return s;
    }
    return 0;
  }

  /// 칸에서 맨 위에 보이는 말의 소유자 (빈 칸이면 0).
  int topOwner(int cell) {
    final s = topSize(cell);
    return s == 0 ? 0 : owners[cell * 3 + s - 1];
  }

  /// 판 위에 있는 [owner]의 크기 [size] 말 개수.
  int onBoard(int owner, int size) {
    var n = 0;
    for (var c = 0; c < 9; c++) {
      if (owners[c * 3 + size - 1] == owner) n++;
    }
    return n;
  }

  /// 아직 판에 올리지 않은 말 개수.
  int reserve(int owner, int size) => 2 - onBoard(owner, size);

  List<GobbletMove> legalMoves() {
    final moves = <GobbletMove>[];
    // 큰 말부터 (탐색에서 좋은 수를 먼저 보기 위해)
    for (var s = 3; s >= 1; s--) {
      if (reserve(turn, s) > 0) {
        for (var c = 0; c < 9; c++) {
          if (topSize(c) < s) moves.add(GobbletMove.place(s, c));
        }
      }
    }
    for (var from = 0; from < 9; from++) {
      if (topOwner(from) != turn) continue;
      final s = topSize(from);
      for (var to = 0; to < 9; to++) {
        if (to != from && topSize(to) < s) moves.add(GobbletMove.slide(from, to, s));
      }
    }
    return moves;
  }

  bool isLegal(GobbletMove m) => legalMoves().contains(m);

  /// 수를 둔다. (차례가 넘어간다)
  void apply(GobbletMove m) {
    if (!m.isPlace) owners[m.from * 3 + m.size - 1] = 0;
    owners[m.to * 3 + m.size - 1] = turn;
    turn = 3 - turn;
  }

  /// [apply]를 되돌린다.
  void undo(GobbletMove m) {
    final mover = 3 - turn;
    owners[m.to * 3 + m.size - 1] = 0;
    if (!m.isPlace) owners[m.from * 3 + m.size - 1] = mover;
    turn = mover;
  }

  /// [owner]가 맨 위 말로 만든 줄 (없으면 null).
  List<int>? lineOf(int owner) {
    for (final l in lines) {
      if (topOwner(l[0]) == owner && topOwner(l[1]) == owner && topOwner(l[2]) == owner) {
        return l;
      }
    }
    return null;
  }

  /// 방금 [mover]가 둔 뒤의 승자 (0 = 없음).
  ///
  /// 말을 들어 올려 상대의 줄이 드러나면, 내 줄도 같이 만들었더라도 상대가 이긴다.
  int winnerAfter(int mover) {
    final opp = 3 - mover;
    if (lineOf(opp) != null) return opp;
    if (lineOf(mover) != null) return mover;
    return 0;
  }

  /// 같은 배치인지 비교하기 위한 키 (반복 판정용).
  String get key => '${owners.join()}$turn';
}
