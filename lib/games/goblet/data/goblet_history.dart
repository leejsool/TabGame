import '../../../core/json_history.dart';

import '../core/goblet_ai.dart';
import '../core/goblet_rules.dart';

/// 끝난 고블렛 한 판의 결과.
class GobbletRecord {
  const GobbletRecord({
    required this.at,
    required this.vsCpu,
    required this.winner,
    required this.moves,
    this.level,
    this.human,
    this.byReveal = false,
    this.resigned = false,
    this.online = false,
  });

  final int at;
  final bool vsCpu;

  /// 같은 Wi‑Fi의 다른 기기와 한 판인가 ([human]은 이 기기를 쓴 사람의 팀).
  final bool online;

  /// 이긴 팀. null이면 무승부.
  final Team? winner;
  final int moves;

  /// CPU 대결일 때: 난이도와 내 팀.
  final CpuLevel? level;
  final Team? human;

  /// 말을 들어 올리는 바람에 상대 줄이 드러나서 결정된 경우.
  final bool byReveal;

  /// 진 쪽이 기권해서 끝난 판인가.
  final bool resigned;

  bool get isDraw => winner == null;

  /// CPU 대결에서 내가 이겼는가 (CPU 대결이 아니면 null).
  bool? get humanWon => vsCpu && winner != null ? winner == human : null;

  /// Wi‑Fi 대결에서 내가 이겼는가 (무승부거나 Wi‑Fi 대결이 아니면 null).
  bool? get onlineWon => online && winner != null ? winner == human : null;

  Map<String, dynamic> toJson() => {
        'at': at,
        'cpu': vsCpu,
        'w': winner?.name,
        'm': moves,
        'lv': level?.name,
        'h': human?.name,
        'rv': byReveal,
        if (resigned) 'rs': 1,
        if (online) 'net': 1,
      };

  static GobbletRecord fromJson(Map<String, dynamic> j) => GobbletRecord(
        at: j['at'] as int,
        vsCpu: j['cpu'] as bool,
        winner: j['w'] == null ? null : Team.values.byName(j['w'] as String),
        moves: j['m'] as int,
        level: j['lv'] == null ? null : CpuLevel.values.byName(j['lv'] as String),
        human: j['h'] == null ? null : Team.values.byName(j['h'] as String),
        byReveal: j['rv'] as bool? ?? false,
        resigned: j['rs'] == 1,
        online: j['net'] == 1,
      );
}

class GobbletHistory {
  GobbletHistory._();

  static const maxEntries = 200;

  static const _store = JsonHistoryStore<GobbletRecord>(
    key: 'goblet.history',
    fromJson: GobbletRecord.fromJson,
    toJson: _toJson,
    maxEntries: maxEntries,
  );

  static Map<String, dynamic> _toJson(GobbletRecord r) => r.toJson();

  /// 최신 순.
  static Future<List<GobbletRecord>> load() => _store.load();

  static Future<void> add(GobbletRecord r) => _store.add(r);
}
