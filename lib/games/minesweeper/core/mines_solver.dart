/// 지뢰찾기 논리 힌트: 지금 보이는 숫자만으로 "확실히" 말할 수 있는 칸을 찾아 이유와 함께 알려준다.
library;

import 'mines_rules.dart';

enum HintKind { safe, mine }

class MinesHint {
  const MinesHint({required this.kind, required this.targets, required this.reasons, required this.message});

  /// 확실히 안전한 칸들이면 [HintKind.safe], 확실히 지뢰인 칸들이면 [HintKind.mine].
  final HintKind kind;
  final List<int> targets;

  /// 이유가 되는 숫자 칸들.
  final List<int> reasons;
  final String message;
}

class MinesSolver {
  MinesSolver._();

  /// 지금 판에서 확실한 칸을 하나(묶음) 찾는다. 없으면 null.
  /// 순서: 단순한 규칙(숫자 하나로 확정) → 두 숫자를 비교하는 규칙.
  static MinesHint? findHint(MinesBoard b) {
    // 숫자 칸마다 "아직 안 열렸고 깃발도 없는 이웃"과 "더 필요한 지뢰 수"
    final numbered = <int>[];
    final unknown = <int, Set<int>>{};
    final need = <int, int>{};
    for (var i = 0; i < b.size; i++) {
      if (b.marks[i] != CellMark.revealed || b.adj[i] == 0) continue;
      final hidden = <int>{};
      var flags = 0;
      for (final n in b.neighbors(i)) {
        if (b.marks[n] == CellMark.hidden) hidden.add(n);
        if (b.marks[n] == CellMark.flagged) flags++;
      }
      if (hidden.isEmpty) continue;
      numbered.add(i);
      unknown[i] = hidden;
      need[i] = b.adj[i] - flags;
    }

    // 1. 숫자 하나로 확정
    for (final i in numbered) {
      final u = unknown[i]!, n = need[i]!;
      if (n == 0) {
        return MinesHint(
          kind: HintKind.safe,
          targets: u.toList()..sort(),
          reasons: [i],
          message: '이 숫자 ${b.adj[i]} 주변에는 이미 지뢰 ${b.adj[i]}개를 모두 찾았어요. 나머지 칸은 안전해요!',
        );
      }
    }
    for (final i in numbered) {
      final u = unknown[i]!, n = need[i]!;
      if (n > 0 && n == u.length) {
        return MinesHint(
          kind: HintKind.mine,
          targets: u.toList()..sort(),
          reasons: [i],
          message: '이 숫자 ${b.adj[i]} 주변에 남은 칸이 ${u.length}개인데 지뢰가 ${u.length}개 더 있어야 해요. 전부 지뢰예요!',
        );
      }
    }

    // 2. 두 숫자 비교: 한쪽의 후보 칸이 다른 쪽에 통째로 들어 있으면, 남는 칸을 알 수 있다
    for (final a in numbered) {
      for (final c in numbered) {
        if (a == c) continue;
        final ua = unknown[a]!, uc = unknown[c]!;
        if (ua.length >= uc.length || !uc.containsAll(ua)) continue;
        final diff = uc.difference(ua);
        final dn = need[c]! - need[a]!;
        if (dn == 0) {
          return MinesHint(
            kind: HintKind.safe,
            targets: diff.toList()..sort(),
            reasons: [a, c],
            message: '두 숫자를 비교해 보세요. 한쪽 숫자의 후보 칸이 다른 쪽에 포함돼서, 겹치지 않는 칸은 안전해요!',
          );
        }
        if (dn == diff.length) {
          return MinesHint(
            kind: HintKind.mine,
            targets: diff.toList()..sort(),
            reasons: [a, c],
            message: '두 숫자를 비교해 보세요. 겹치지 않는 칸에 지뢰가 모두 들어가야 해요. 전부 지뢰예요!',
          );
        }
      }
    }
    return null;
  }
}
