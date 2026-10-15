import '../../../core/json_history.dart';

import '../ui/jigsaw_images.dart';

/// 직소퍼즐 한 판의 기록: 완성했거나, 포기한 판.
class JigsawRecord {
  const JigsawRecord({
    required this.at,
    required this.target,
    required this.pieces,
    required this.seconds,
    required this.source,
    this.gaveUp = false,
    this.placed = 0,
  });

  final int at;

  /// 처음에 고른 조각 수 (12/24/48/96).
  final int target;

  /// 실제 조각 수.
  final int pieces;
  final int seconds;

  /// 그림의 출처. 'none'이면 다시 할 수 없다.
  final JigsawSource source;

  /// 포기한 판인가 (그러면 [seconds]는 포기하기까지 걸린 시간).
  final bool gaveUp;

  /// 포기할 때까지 맞춘 조각 수.
  final int placed;

  bool get canReplay => source.kind != 'none';

  Map<String, dynamic> toJson() => {
        'at': at,
        'target': target,
        'pieces': pieces,
        'sec': seconds,
        'src': source.toJson(),
        if (gaveUp) 'gu': 1,
        if (gaveUp) 'placed': placed,
      };

  static JigsawRecord fromJson(Map<String, dynamic> j) => JigsawRecord(
        at: j['at'] as int,
        target: j['target'] as int,
        pieces: j['pieces'] as int,
        seconds: j['sec'] as int,
        source: JigsawSource.fromJson(j['src'] as Map<String, dynamic>),
        gaveUp: j['gu'] == 1,
        placed: (j['placed'] as int?) ?? 0,
      );
}

class JigsawHistory {
  JigsawHistory._();

  /// 사진 파일을 함께 보관하므로 개수를 적게 제한한다.
  static const maxEntries = 30;

  static const _store = JsonHistoryStore<JigsawRecord>(
    key: 'jigsaw.history',
    fromJson: JigsawRecord.fromJson,
    toJson: _toJson,
    maxEntries: maxEntries,
  );

  static Map<String, dynamic> _toJson(JigsawRecord r) => r.toJson();

  /// 최신 순.
  static Future<List<JigsawRecord>> load() => _store.load();

  /// 기록을 더한다. 같은 그림·조각 수의 포기 기록은 하나만 남기고, 포기했던 판을 완성하면 포기 기록은 지운다.
  /// 넘치면 오래된 완성 기록부터 지운다 (다시 도전할 수 있는 포기한 판은 되도록 남긴다).
  static Future<void> add(JigsawRecord r) => _store.add(
        r,
        beforeInsert: (list) {
          if (r.source.kind == 'none') return;
          list.removeWhere((e) =>
              e.gaveUp && e.target == r.target && e.source.kind == r.source.kind && e.source.ref == r.source.ref);
        },
        protect: (e) => e.gaveUp,
      );
}
