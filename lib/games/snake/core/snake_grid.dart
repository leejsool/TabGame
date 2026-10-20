import 'dart:typed_data';

/// 뱀 몸 점들을 칸으로 나눠 담는 그물 (부딪힘·CPU의 앞길 살피기를 빠르게 하려고). 한 걸음마다 새로 짠다.
class BodyGrid {
  BodyGrid(double field, {this.cell = 64}) : side = (field / cell).ceil() + 1 {
    _cellStart = Int32List(side * side + 1);
  }

  final double cell;
  final int side;

  /// 점 좌표·굵기 (앞의 [count]칸만 쓴다). 한 걸음마다 수천 점을 다시 담으므로
  /// 숫자 하나하나가 새 객체가 되는 List 대신 미리 잡아 둔 배열을 되풀이해 쓴다.
  Float64List px = Float64List(1024), py = Float64List(1024), pr = Float64List(1024);

  /// 점 주인 (그 걸음의 뱀 번호).
  Int32List owner = Int32List(1024);
  Int32List _cellOf = Int32List(1024);
  int count = 0;
  late Int32List _cellStart;
  late final Int32List _fill = Int32List(side * side + 1);
  Int32List _order = Int32List(0);

  void begin() => count = 0;

  void _grow() {
    final n = px.length * 2;
    px = Float64List(n)..setRange(0, count, px);
    py = Float64List(n)..setRange(0, count, py);
    pr = Float64List(n)..setRange(0, count, pr);
    owner = Int32List(n)..setRange(0, count, owner);
    _cellOf = Int32List(n)..setRange(0, count, _cellOf);
  }

  int _cellIndex(double x, double y) {
    var cx = (x / cell).floor(), cy = (y / cell).floor();
    if (cx < 0) cx = 0;
    if (cy < 0) cy = 0;
    if (cx >= side) cx = side - 1;
    if (cy >= side) cy = side - 1;
    return cy * side + cx;
  }

  void add(double x, double y, double r, int who) {
    if (count == px.length) _grow();
    px[count] = x;
    py[count] = y;
    pr[count] = r;
    owner[count] = who;
    _cellOf[count] = _cellIndex(x, y);
    count++;
  }

  /// 담은 점들을 칸 차례로 정리한다 (센 다음 줄 세우기).
  void build() {
    _cellStart.fillRange(0, _cellStart.length, 0);
    for (var i = 0; i < count; i++) {
      _cellStart[_cellOf[i] + 1]++;
    }
    for (var i = 1; i < _cellStart.length; i++) {
      _cellStart[i] += _cellStart[i - 1];
    }
    if (_order.length < count) _order = Int32List(px.length);
    _fill.setRange(0, _fill.length, _cellStart);
    for (var i = 0; i < count; i++) {
      _order[_fill[_cellOf[i]]++] = i;
    }
  }

  /// ([x], [y])에서 [reach] 안쪽 칸들에 든 점 번호마다 [visit]을 부른다. [visit]이 true를 돌려주면 멈추고 true.
  bool query(double x, double y, double reach, bool Function(int i) visit) {
    var x0 = ((x - reach) / cell).floor(), x1 = ((x + reach) / cell).floor();
    var y0 = ((y - reach) / cell).floor(), y1 = ((y + reach) / cell).floor();
    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    if (x1 >= side) x1 = side - 1;
    if (y1 >= side) y1 = side - 1;
    for (var cy = y0; cy <= y1; cy++) {
      for (var cx = x0; cx <= x1; cx++) {
        final c = cy * side + cx;
        for (var k = _cellStart[c]; k < _cellStart[c + 1]; k++) {
          if (visit(_order[k])) return true;
        }
      }
    }
    return false;
  }
}

/// 먹이를 칸으로 나눠 담는 그물 (먹이는 드물게 바뀌니 넣고 뺄 때만 고친다).
class FoodGrid<T> {
  FoodGrid(double field, {this.cell = 80}) : side = (field / cell).ceil() + 1 {
    _cells = List.generate(side * side, (_) => <T>[]);
  }

  final double cell;
  final int side;
  late final List<List<T>> _cells;

  int _index(double x, double y) {
    var cx = (x / cell).floor(), cy = (y / cell).floor();
    if (cx < 0) cx = 0;
    if (cy < 0) cy = 0;
    if (cx >= side) cx = side - 1;
    if (cy >= side) cy = side - 1;
    return cy * side + cx;
  }

  void add(T item, double x, double y) => _cells[_index(x, y)].add(item);
  void remove(T item, double x, double y) => _cells[_index(x, y)].remove(item);

  void clear() {
    for (final c in _cells) {
      c.clear();
    }
  }

  /// ([x], [y])에서 [reach] 안쪽 칸들의 먹이마다 [visit]. (도는 동안 넣거나 빼지 않는다: 먹을 것은 모아 두었다가 뺀다)
  void query(double x, double y, double reach, void Function(T item) visit) {
    var x0 = ((x - reach) / cell).floor(), x1 = ((x + reach) / cell).floor();
    var y0 = ((y - reach) / cell).floor(), y1 = ((y + reach) / cell).floor();
    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    if (x1 >= side) x1 = side - 1;
    if (y1 >= side) y1 = side - 1;
    for (var cy = y0; cy <= y1; cy++) {
      for (var cx = x0; cx <= x1; cx++) {
        for (final f in _cells[cy * side + cx]) {
          visit(f);
        }
      }
    }
  }
}
