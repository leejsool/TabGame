import 'prophecy_rules.dart';

/// 안내·교과학습에 쓰는 예시 판들. 0 = 먼저 쓰는 쪽(분홍), 1 = 나중에 쓰는 쪽(청록).
const int _x = kCross;
const int _b = kBlank;

ProphState _make(int rows, int cols, List<int> cells, [List<int>? owners]) {
  // 주인을 따로 안 주면: 숫자·X를 번갈아 쓴 것으로 (칸 번호 순서로) 정한다
  final own = owners ?? [for (var i = 0; i < cells.length; i++) cells[i] == _b ? kNoOwner : i % 2];
  return ProphState.fromCells(rows, cols, cells, own);
}

/// 아직 아무것도 안 쓴 4행 × 5열 표.
ProphState emptyBoard() => _make(4, 5, List<int>.filled(20, _b));

/// 몇 칸 쓴 표 (숫자와 X를 써 본 모습).
ProphState startedBoard() => _make(
      4,
      5,
      [
        5, _b, _b, _b, _b, //
        _b, _b, 4, _b, _b,
        3, _b, _x, _b, _b,
        _b, _b, _b, _b, _b,
      ],
      [
        0, kNoOwner, kNoOwner, kNoOwner, kNoOwner, //
        kNoOwner, kNoOwner, 0, kNoOwner, kNoOwner,
        1, kNoOwner, 1, kNoOwner, kNoOwner,
        kNoOwner, kNoOwner, kNoOwner, kNoOwner, kNoOwner,
      ],
    );

/// 같은 숫자를 두 번 쓰려는 예: 4행 1열(칸 15)에 4를 쓰려 하는데 같은 행의 오른쪽에 이미 4가 있다 (칸 번호는 [kRepeatCell]).
ProphState repeatBoard() => _make(
      4,
      5,
      [
        5, _b, _b, 3, _b, //
        _b, _b, 4, _b, _b,
        3, _b, _x, _b, _b,
        _b, _b, _b, 4, 1,
      ],
      [
        0, kNoOwner, kNoOwner, 1, kNoOwner, //
        kNoOwner, kNoOwner, 0, kNoOwner, kNoOwner,
        1, kNoOwner, 1, kNoOwner, kNoOwner,
        kNoOwner, kNoOwner, kNoOwner, 0, 0,
      ],
    );

/// [repeatBoard]에서 4를 쓰려다 막히는 칸 (4행 1열).
const int kRepeatCell = 15;

/// 어떤 숫자도 쓸 수 없어서 저절로 X가 되는 예 (4×4): 가운데 위쪽 칸(0행 0열)이 막힌다.
/// 0행에 1·2, 0열에 3·4가 있으면 0행 0열에는 1~4 어느 것도 쓸 수 없다.
ProphState deadCellBefore() => _make(
      4,
      4,
      [
        _b, 1, 2, _b, //
        3, _b, _b, _b,
        _b, _b, _b, _b,
        _b, _b, _b, _b,
      ],
      [
        kNoOwner, 0, 1, kNoOwner, //
        0, kNoOwner, kNoOwner, kNoOwner,
        kNoOwner, kNoOwner, kNoOwner, kNoOwner,
        kNoOwner, kNoOwner, kNoOwner, kNoOwner,
      ],
    );

/// [deadCellBefore] 다음에 누군가 0열의 4를 쓰는 순간, 0행 0열이 저절로 X가 된 모습.
ProphState deadCellAfter() => _make(
      4,
      4,
      [
        _x, 1, 2, _b, //
        3, _b, _b, _b,
        4, _b, _b, _b,
        _b, _b, _b, _b,
      ],
      [
        kNoOwner, 0, 1, kNoOwner, //
        0, kNoOwner, kNoOwner, kNoOwner,
        1, kNoOwner, kNoOwner, kNoOwner,
        kNoOwner, kNoOwner, kNoOwner, kNoOwner,
      ],
    );

/// 책에 나온 다 채운 4행 × 5열 표. 4(분홍)는 모두 맞혔고, 나머지(청록)도 일부 맞혀 12 : 19점이 된다.
ProphState bookBoard() {
  const cells = [
    5, 4, 2, 3, _x, //
    2, 5, 4, 1, 3,
    3, _x, _x, 4, 2,
    4, 2, 3, 5, 1,
  ];
  final owners = [for (final v in cells) v == _x ? 1 : (v == 4 || v == 2 || v == 1 ? 0 : 1)];
  return ProphState.fromCells(4, 5, cells, owners);
}
