import 'package:flutter/material.dart';

import 'lan_rejoin_flow.dart';

/// "하던 방이 있어요" 카드: 표로 하던 자리에 바로 다시 들어간다 ([onRejoin]이 null이면 단추가 꺼진다).
class LanRejoinRoomCard extends StatelessWidget {
  const LanRejoinRoomCard({super.key, required this.ticket, required this.color, required this.onRejoin});

  final RejoinTicket ticket;
  final Color color;
  final VoidCallback? onRejoin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('rejoin-room'),
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withValues(alpha: 0.6), width: 1.5)),
      child: ListTile(
        leading: Icon(Icons.replay_rounded, color: color, size: 30),
        title: const Text('하던 방이 있어요', style: TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
          '${ticket.hostNick.isEmpty ? '' : '${ticket.hostNick} 님이 연 방 · '}${ticket.host.split('.').last}번 · 하던 자리로 바로 이어서 해요',
          style: const TextStyle(fontSize: 12.5),
        ),
        trailing: FilledButton(onPressed: onRejoin, child: const Text('다시 들어가기')),
      ),
    );
  }
}

/// 열린 방이 아직 없을 때 보이는 "방을 찾는 중" 상자.
class LanSearchingBox extends StatelessWidget {
  const LanSearchingBox({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: 14),
          const Text('같은 Wi‑Fi의 방을 찾는 중…', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '다른 기기에서 "방 만들기 → 방 열기"를 먼저 눌러 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );
  }
}

/// 방 목록의 한 줄: 제목, 방 이름·번호, 보조 글과 "들어가기" 단추 ([onJoin]이 null이면 꺼진다).
class LanRoomTile extends StatelessWidget {
  const LanRoomTile({super.key, required this.title, required this.nameLine, required this.subtitle, required this.color, required this.onJoin});

  final String title;
  final String nameLine;
  final String subtitle;
  final Color color;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: scheme.outlineVariant)),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(Icons.wifi_rounded, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nameLine, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            Text(subtitle, style: const TextStyle(fontSize: 12.5)),
          ],
        ),
        trailing: FilledButton(onPressed: onJoin, child: const Text('들어가기')),
      ),
    );
  }
}
