import 'package:flutter/material.dart';

import '../core/game_info.dart';
import '../core/game_registry.dart';
import '../net/lan_rejoin_flow.dart';

/// 허브 맨 위의 "하던 방에 다시 들어가기" 카드들.
///
/// 같은 Wi‑Fi 방에서 판을 하다가 앱을 껐거나 나갔을 때, 기기에 받아 둔 표([RejoinTickets])로 같은 자리에 바로 다시 앉을 수 있다.
/// 방장 기기가 켜져 있고 판이 아직 끝나지 않았을 때만 들어가진다. 표가 없으면 아무것도 보이지 않는다.
class RejoinCards extends StatefulWidget {
  const RejoinCards({super.key});

  @override
  State<RejoinCards> createState() => _RejoinCardsState();
}

class _RejoinCardsState extends State<RejoinCards> {
  List<RejoinTicket> _tickets = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    RejoinTickets.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    RejoinTickets.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final list = await RejoinTickets.load();
    if (mounted) setState(() => _tickets = [for (final t in list) if (_gameOf(t) != null) t]);
  }

  GameInfo? _gameOf(RejoinTicket t) {
    for (final g in allGames) {
      if (g.lanGame == t.game && g.lanResume != null) return g;
    }
    return null;
  }

  Future<void> _rejoin(RejoinTicket t) async {
    final game = _gameOf(t);
    if (game == null || _busy) return;
    setState(() => _busy = true);
    try {
      final result = await lanRejoinWithProgress(context, t);
      if (!mounted) {
        result.conn?.close();
        return;
      }
      if (!result.ok) {
        lanToast(context, lanRejoinFailText(result.fail!));
        return;
      }
      final screen = game.lanResume!(result.resume!, result.conn!);
      if (screen == null) {
        result.conn!.close();
        lanToast(context, '판의 모습을 받지 못했어요. 다시 시도해 주세요.');
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tickets.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        children: [
          for (final t in _tickets)
            Builder(builder: (context) {
              final game = _gameOf(t)!;
              final label = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('하던 ${game.title} 방이 있어요', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900)),
                  Text(
                    t.hostNick.isEmpty ? '방장 기기가 켜져 있으면 바로 이어서 해요' : '${t.hostNick} 님이 연 방 · 바로 이어서 해요',
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ],
              );
              final button = FilledButton(
                onPressed: _busy ? null : () => _rejoin(t),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: game.color,
                  textStyle: const TextStyle(fontFamily: 'NanumGothic', fontWeight: FontWeight.w800),
                ),
                child: const Text('다시 들어가기'),
              );
              final forget = IconButton(
                tooltip: '이 방 잊기',
                icon: const Icon(Icons.close_rounded),
                onPressed: _busy ? null : () => RejoinTickets.forget(t.game),
              );
              return Container(
                key: ValueKey('rejoin-${t.game}'),
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: game.color.withValues(alpha: 0.5), width: 1.5),
                ),
                // 좁은 폰에서는 글이 두세 줄로 꺾이지 않게 단추를 아래 줄로 내린다
                child: LayoutBuilder(
                  builder: (context, box) {
                    final narrow = box.maxWidth < 440;
                    final icon = Icon(Icons.wifi_rounded, color: game.color, size: 28);
                    if (!narrow) {
                      return Row(children: [icon, const SizedBox(width: 12), Expanded(child: label), const SizedBox(width: 8), button, forget]);
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [icon, const SizedBox(width: 12), Expanded(child: label), forget]),
                        Padding(padding: const EdgeInsets.only(right: 8, top: 2), child: button),
                      ],
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}
