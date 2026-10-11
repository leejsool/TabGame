import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../ui/jigsaw_images.dart';

/// 완성한 직소퍼즐 한 판의 기록.
class JigsawRecord {
  const JigsawRecord({
    required this.at,
    required this.target,
    required this.pieces,
    required this.seconds,
    required this.source,
  });

  final int at;

  /// 처음에 고른 조각 수 (12/24/48/96).
  final int target;

  /// 실제 조각 수.
  final int pieces;
  final int seconds;

  /// 그림의 출처. 'none'이면 다시 할 수 없다.
  final JigsawSource source;

  bool get canReplay => source.kind != 'none';

  Map<String, dynamic> toJson() => {
        'at': at,
        'target': target,
        'pieces': pieces,
        'sec': seconds,
        'src': source.toJson(),
      };

  static JigsawRecord fromJson(Map<String, dynamic> j) => JigsawRecord(
        at: j['at'] as int,
        target: j['target'] as int,
        pieces: j['pieces'] as int,
        seconds: j['sec'] as int,
        source: JigsawSource.fromJson(j['src'] as Map<String, dynamic>),
      );
}

class JigsawHistory {
  JigsawHistory._();

  static const _key = 'jigsaw.history';

  /// 사진 파일을 함께 보관하므로 개수를 적게 제한한다.
  static const maxEntries = 30;

  /// 최신 순.
  static Future<List<JigsawRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List) JigsawRecord.fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      await prefs.remove(_key);
      return [];
    }
  }

  static Future<void> add(JigsawRecord r) async {
    final list = await load();
    list.insert(0, r);
    if (list.length > maxEntries) list.removeRange(maxEntries, list.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final e in list) e.toJson()]));
  }
}
