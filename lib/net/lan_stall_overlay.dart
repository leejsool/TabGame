import 'dart:async';

import 'package:flutter/material.dart';

import 'lan_connection.dart';

/// 같은 Wi‑Fi 대결에서 상대 기기의 응답이 끊겼을 때 (카톡을 보러 잠깐 나갔을 수도 있다) 화면 위에 띄우는 "기다리는 중" 안내.
///
/// 앱 전체를 감싸서 어느 게임 화면에서든 보인다. 판은 그대로 두고 (내 손패 정리 같은 건 계속 할 수 있다), 처음에는 기다리는 시간만 보여 준다.
/// 한참([decisionAfter]) 기다려도 소식이 없으면 남은 사람이 "계속 기다리기"와 "이 판 끝내기" 중에서 정한다.
/// 끝내기를 고르면 연결을 닫고, 게임 화면은 평소의 "연결이 끊겼어요" 안내로 이어진다.
/// 방장 화면에서는 "CPU가 대신하기"도 고를 수 있다: 그 사람 자리를 CPU가 맡아 판이 계속되고, 그 사람이 돌아오면 바로 자리를 되찾는다.
class LanStallOverlay extends StatefulWidget {
  const LanStallOverlay({super.key, required this.child, this.decisionAfter = const Duration(seconds: 30)});

  final Widget child;

  /// 이만큼 기다려도 안 돌아오면 결정 단추가 나타난다.
  final Duration decisionAfter;

  @override
  State<LanStallOverlay> createState() => _LanStallOverlayState();
}

class _LanStallOverlayState extends State<LanStallOverlay> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    LanConnection.stalledConnections.addListener(_changed);
    _changed();
  }

  @override
  void dispose() {
    LanConnection.stalledConnections.removeListener(_changed);
    _tick?.cancel();
    super.dispose();
  }

  void _changed() {
    final any = LanConnection.stalledConnections.value.isNotEmpty;
    if (any && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!any) {
      _tick?.cancel();
      _tick = null;
    }
    if (mounted) setState(() {});
  }

  String _clock(Duration d) {
    final s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final stalled = LanConnection.stalledConnections.value;
    return Stack(
      children: [
        widget.child,
        if (stalled.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [for (final c in stalled) _card(context, c)],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _card(BuildContext context, LanConnection c) {
    final scheme = Theme.of(context).colorScheme;
    // 방장이 이 사람 자리를 CPU에게 맡겼다: 한 줄 안내만 (돌아오면 바로 이어진다)
    if (c.cpuCovered) {
      return Padding(
        key: ObjectKey(c), // (여러 사람이 동시에 나가 있어도 카드마다 따로)
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          elevation: 6,
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              children: [
                Icon(Icons.smart_toy_rounded, size: 20, color: scheme.onInverseSurface),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${c.peerNick} 자리는 CPU가 대신하고 있어요. 돌아오면 바로 이어져요.',
                    style: TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final since = c.stalledSince ?? DateTime.now();
    final waited = DateTime.now().difference(since);
    final snoozed = c.decisionSnoozedUntil != null && DateTime.now().isBefore(c.decisionSnoozedUntil!);
    final decide = waited >= widget.decisionAfter && !snoozed;
    return Padding(
      key: ObjectKey(c),
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        elevation: 6,
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      c.suspended ? '${c.peerNick} 님이 나갔어요. 돌아오기를 기다리는 중… ${_clock(waited)}' : '${c.peerNick}의 응답을 기다리는 중… ${_clock(waited)}',
                      style: TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ],
              ),
              if (!decide)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 30),
                  child: Text(
                    '잠깐 나갔을 수 있어요. 돌아오면 이어서 할 수 있어요.',
                    style: TextStyle(color: scheme.onInverseSurface.withValues(alpha: 0.75), fontSize: 12.5),
                  ),
                ),
              if (decide) ...[
                const SizedBox(height: 6),
                Text(
                  c.onTakeOver != null ? 'CPU가 대신해도, 돌아오면 바로 다시 할 수 있어요.' : '한참 지나도 소식이 없어요. 어떻게 할까요?',
                  style: TextStyle(color: scheme.onInverseSurface.withValues(alpha: 0.85), fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => c.decisionSnoozedUntil = DateTime.now().add(const Duration(minutes: 2))),
                      child: Text('계속 기다리기', style: TextStyle(color: scheme.onInverseSurface)),
                    ),
                    if (c.onTakeOver != null)
                      FilledButton.icon(
                        key: const ValueKey('take-over'),
                        onPressed: c.onTakeOver,
                        icon: const Icon(Icons.smart_toy_rounded, size: 18),
                        label: const Text('CPU가 대신하기'),
                      ),
                    FilledButton(
                      onPressed: c.close,
                      style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
                      child: const Text('이 판 끝내기'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
