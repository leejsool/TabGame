import 'package:flutter/material.dart';

import '../core/give_up.dart';
import 'record_widgets.dart';

/// 대결 게임 기록 한 줄이 화면에 어떻게 보일지.
class VsTile {
  const VsTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    this.resigned = false,
  });

  /// CPU와 한 판의 결과 줄: 이김 / 짐(또는 기권) / 무승부([humanWon]이 null).
  factory VsTile.cpu({
    required ColorScheme scheme,
    required bool? humanWon,
    required bool resigned,
    required String levelLabel,
    required String detail,
  }) {
    if (humanWon == null) {
      return VsTile(
        icon: Icons.handshake_rounded,
        color: scheme.outline,
        title: '무승부 · CPU $levelLabel',
        detail: detail,
        resigned: resigned,
      );
    }
    return VsTile(
      icon: humanWon ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
      color: humanWon ? const Color(0xFFF2A900) : scheme.error,
      title: '${humanWon ? '이겼어요' : resigned ? '기권했어요' : '졌어요'} · CPU $levelLabel',
      detail: detail,
      resigned: resigned,
    );
  }

  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  /// 기권으로 끝난 판이면 "포기" 딱지가 붙는다.
  final bool resigned;
}

/// "둘이서" 요약 카드의 칸 하나 (이름 + 큰 숫자).
class VsTally {
  const VsTally(this.label, this.count, this.color);

  final String label;
  final int count;
  final Color color;
}

/// 대결 게임(CPU와 / 둘이서)의 기록 보드 틀: CPU 난이도별 전적 + 둘이서 요약 + 최근 결과 30개.
///
/// 게임은 기록 목록을 읽는 방법([load])과, 기록 한 개를 CPU 대결 여부·결과·화면 줄로 바꾸는 방법만 알려 준다.
/// (기록 저장은 `core/json_history.dart`의 `JsonHistoryStore`, 설정 화면은 `versus/vs_setup.dart`)
class VsRecordsBoard<R, L> extends StatefulWidget {
  const VsRecordsBoard({
    super.key,
    required this.load,
    required this.emptyIcon,
    required this.levels,
    required this.levelLabel,
    required this.levelOf,
    required this.isCpu,
    required this.humanWon,
    required this.twoPlayerTallies,
    required this.tile,
    this.hasDraws = false,
    this.onRetry,
  });

  /// 최신 순 기록 목록.
  final Future<List<R>> Function() load;
  final IconData emptyIcon;

  /// CPU 난이도들(쉬운 순)과 그 이름, 기록이 어느 난이도인지.
  final List<L> levels;
  final String Function(L level) levelLabel;
  final L? Function(R record) levelOf;

  final bool Function(R record) isCpu;

  /// CPU 대결에서 내가 이겼는가 (졌으면 false, 무승부면 null).
  final bool? Function(R record) humanWon;

  /// 무승부가 있는 게임이면 true (전적에 "무"를 보여 준다).
  final bool hasDraws;

  /// 둘이서 한 판들([two])의 요약 칸들 (마지막에 "총 판 수"는 틀이 붙인다).
  final List<VsTally> Function(List<R> two, ColorScheme scheme) twoPlayerTallies;

  final VsTile Function(BuildContext context, R record, ColorScheme scheme) tile;

  /// 기권한 CPU 대결을 같은 설정으로 다시 해 보는 함수 (없거나 null이면 "다시 도전" 단추가 없다).
  final VoidCallback? Function(BuildContext context, R record)? onRetry;

  @override
  State<VsRecordsBoard<R, L>> createState() => _VsRecordsBoardState<R, L>();
}

class _VsRecordsBoardState<R, L> extends State<VsRecordsBoard<R, L>> {
  List<R> _all = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    widget.load().then((v) {
      if (mounted) {
        setState(() {
          _all = v;
          _loaded = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final scheme = Theme.of(context).colorScheme;
    final cpu = _all.where(widget.isCpu).toList();
    final two = _all.where((r) => !widget.isCpu(r)).toList();
    return RecordsList(
      children: [
        const SectionTitle('CPU와 대결'),
        for (final level in widget.levels)
          _LevelRow(
            label: widget.levelLabel(level),
            results: [for (final r in cpu) if (widget.levelOf(r) == level) widget.humanWon(r)],
            hasDraws: widget.hasDraws,
          ),
        const SectionTitle('둘이서 (한 기기)'),
        _TwoPlayerCard(
          tallies: [...widget.twoPlayerTallies(two, scheme), VsTally('총 판 수', two.length, scheme.onSurface)],
          empty: two.isEmpty,
        ),
        const SectionTitle('최근 결과'),
        if (_all.isEmpty)
          EmptyRecords(
            icon: widget.emptyIcon,
            message: '아직 끝낸 판이 없어요.\n한 판 끝내면 여기에 전적이 쌓여요!',
          )
        else
          for (final r in _all.take(30))
            _ResultTile(
              tile: widget.tile(context, r, scheme),
              onRetry: widget.isCpu(r) ? widget.onRetry?.call(context, r) : null,
            ),
      ],
    );
  }
}

/// 난이도 한 줄: 승·패(·무) 수와 승률 막대. [results]는 그 난이도의 판마다 (이김 true / 짐 false / 무승부 null).
class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.label, required this.results, required this.hasDraws});

  final String label;
  final List<bool?> results;
  final bool hasDraws;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wins = results.where((r) => r == true).length;
    final losses = results.where((r) => r == false).length;
    final draws = results.where((r) => r == null).length;
    final total = results.length;
    final rate = total == 0 ? 0.0 : wins / total;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        color: scheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(
                total == 0 ? '아직 기록이 없어요' : '$wins승 $losses패${hasDraws ? ' $draws무' : ''}',
                style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: rate, minHeight: 8),
          ),
          const SizedBox(height: 4),
          Text(
            total == 0 ? '' : '승률 ${(rate * 100).round()}% · $total판',
            style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

class _TwoPlayerCard extends StatelessWidget {
  const _TwoPlayerCard({required this.tallies, required this.empty});

  final List<VsTally> tallies;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        color: scheme.surface,
      ),
      child: empty
          ? Center(child: Text('아직 기록이 없어요', style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.65))))
          : Row(
              children: [
                for (final t in tallies)
                  Expanded(
                    child: Column(
                      children: [
                        Text('${t.count}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: t.color)),
                        Text(t.label, style: const TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.tile, this.onRetry});

  final VsTile tile;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: tile.color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(tile.icon, color: tile.color),
        ),
        title: Row(
          children: [
            Flexible(child: Text(tile.title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
            if (tile.resigned) ...[const SizedBox(width: 6), const GiveUpChip()],
          ],
        ),
        subtitle: Text(tile.detail, style: const TextStyle(fontSize: 12.5)),
        trailing: tile.resigned && onRetry != null
            ? IconButton.filledTonal(tooltip: '다시 도전', onPressed: onRetry, icon: const Icon(Icons.replay_rounded))
            : null,
      ),
    );
  }
}
