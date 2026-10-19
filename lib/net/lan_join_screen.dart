import 'dart:async';

import 'package:flutter/material.dart';

import '../core/settings_scope.dart';
import 'lan_connection.dart';
import 'lan_discovery.dart';
import 'lan_rejoin_flow.dart';
import 'lan_screens.dart';

/// 같은 Wi‑Fi에서 열린 방을 찾아 들어가는 화면. 주소를 직접 입력해서 들어갈 수도 있다.
class LanJoinScreen extends StatefulWidget {
  const LanJoinScreen({
    super.key,
    required this.game,
    required this.color,
    required this.roomTitle,
    required this.roomSubtitle,
    required this.buildGame,
    this.discoveryPort = kLanDiscoveryPort,
    this.extraTargets = const [],
  });

  final String game;
  final Color color;

  /// 방 목록 한 줄의 제목·보조 글 (방 정보 [LanRoom.info]로 만든다).
  final String Function(LanRoom room) roomTitle;
  final String Function(LanRoom room) roomSubtitle;

  /// 방에서 온 시작 메시지로 이 기기의 게임 화면을 만든다. 메시지가 잘못됐으면 null.
  final Widget? Function(Map<String, dynamic> start, LanConnection conn) buildGame;

  /// (시험용) 방 찾기 포트와 추가로 물어볼 주소.
  final int discoveryPort;
  final List<String> extraTargets;

  @override
  State<LanJoinScreen> createState() => _LanJoinScreenState();
}

class _LanJoinScreenState extends State<LanJoinScreen> {
  LanFinder? _finder;
  StreamSubscription<List<LanRoom>>? _sub;
  List<LanRoom> _rooms = const [];
  bool _connecting = false;
  String? _message;

  /// 여러 명이 모이는 방에 들어가 기다리는 중일 때: 지금 들어온 사람들 이름과 필요한 인원, 그 방과의 연결.
  List<String>? _lobbyNames;
  int? _lobbyNeed;
  LanConnection? _lobbyConn;
  bool _cancelled = false;
  final TextEditingController _address = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startFinder();
  }

  /// 방 이름 (옛 버전이 연 방처럼 이름이 없으면 주소 끝 숫자로).
  String _nameOf(LanRoom r) => r.info['room'] is String ? r.info['room'] as String : '${r.address.split('.').last}번 방';

  Future<void> _startFinder() async {
    try {
      final finder = await LanFinder.start(game: widget.game, discoveryPort: widget.discoveryPort, extraTargets: widget.extraTargets);
      if (!mounted) {
        finder.close();
        return;
      }
      _finder = finder;
      _sub = finder.rooms.listen((r) {
        // 이미 시작한 판(다시 들어오기만 받는 방)은 새로 들어갈 방이 아니니 목록에 올리지 않는다
        if (mounted) setState(() => _rooms = [for (final room in r) if (room.info['rejoin'] != true || room.info['open'] == true) room]);
      });
    } catch (_) {
      if (mounted) setState(() => _message = '방을 찾을 수 없어요. 이 기기가 Wi‑Fi에 연결되어 있는지 확인해 주세요.');
    }
  }

  void _stopFinder() {
    _sub?.cancel();
    _finder?.close();
    _sub = null;
    _finder = null;
    _rooms = const [];
  }

  @override
  void dispose() {
    _stopFinder();
    _address.dispose();
    super.dispose();
  }

  Future<void> _join(String host, int port) async {
    if (_connecting) return;
    final nick = SettingsScope.of(context).nickname;
    setState(() {
      _connecting = true;
      _message = null;
    });
    LanConnection? conn;
    var started = false;
    var waitedInLobby = false; // 여러 명이 모이는 방에서 기다리던 중이었나
    _cancelled = false;
    try {
      conn = await LanConnection.connect(host, port);
      conn.send({'t': 'hello', 'game': widget.game, 'nick': nick});
      // 방이 시작 메시지를 보낼 때까지 기다린다. 여러 명이 모이는 방은 `lobby`(들어온 사람 목록)를 보내 주고,
      // 그때는 방장이 시작할 때까지 얼마든지 기다린다. (그런 소식이 없는 방은 8초 안에 시작하지 않으면 실패)
      final startC = Completer<Map<String, dynamic>>();
      Timer? limit = Timer(const Duration(seconds: 8), () {
        if (!startC.isCompleted) startC.completeError(TimeoutException('start'));
      });
      final sub = conn.messages.listen((m) {
        final t = m['t'];
        if (t == 'lobby') {
          limit?.cancel();
          limit = null;
          waitedInLobby = true;
          final names = m['names'];
          if (mounted && names is List) setState(() => _lobbyNames = [for (final n in names) '$n']);
          _lobbyNeed = m['need'] is int ? m['need'] as int : null;
        } else if ((t == 'start' || t == 'busy') && !startC.isCompleted) {
          startC.complete(m);
        }
      });
      conn.closed.then((_) {
        if (!startC.isCompleted) startC.completeError(StateError('closed'));
      });
      _lobbyConn = conn;
      final Map<String, dynamic> m;
      try {
        m = await startC.future;
      } finally {
        limit?.cancel();
        await sub.cancel();
        _lobbyConn = null;
        if (mounted) setState(() => _lobbyNames = null);
      }
      if (m['t'] == 'busy') {
        conn.close();
        if (mounted) setState(() => _message = '이미 다른 기기가 이 방에 들어와 있어요.');
        return;
      }
      conn.peer = m;
      final screen = widget.buildGame(m, conn);
      if (screen == null) throw const FormatException('start');
      if (!mounted) {
        conn.close();
        return;
      }
      started = true;
      _saveTicket(m, host, port);
      _stopFinder();
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
      if (mounted) _startFinder();
    } catch (_) {
      conn?.close();
      if (mounted && !started && !_cancelled) {
        setState(() => _message = waitedInLobby
            ? '기다리던 방과 연결이 끊어졌어요. 방이 아직 열려 있으면 다시 들어와 보세요.'
            : '방에 들어갈 수 없어요. 방이 아직 열려 있는지, 같은 Wi‑Fi인지 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  /// 방이 준 "다시 들어오기 표"를 보관한다 (앱을 껐다 켜도 하던 방에 다시 들어갈 수 있게).
  void _saveTicket(Map<String, dynamic> start, String host, int port) {
    final t = start['rejoin'];
    if (t is! Map || t['room'] is! String || t['token'] is! String) return;
    RejoinTickets.save(RejoinTicket(
      game: widget.game,
      roomId: t['room'] as String,
      token: t['token'] as String,
      host: host,
      port: port,
      hostNick: start['nick'] is String ? start['nick'] as String : '',
      savedAt: DateTime.now().millisecondsSinceEpoch,
    )).catchError((Object _) {}); // (보관을 못 해도 판은 그대로 한다)
  }

  /// 모이는 중인 방에서 기다리다 나온다.
  void _leaveLobby() {
    _cancelled = true;
    _lobbyConn?.close();
  }

  /// 방 번호("37"), 주소("192.168.0.37") 또는 "192.168.0.37:45822".
  Future<void> _joinTyped() async {
    if (_address.text.trim().isEmpty) return;
    final target = parseRoomInput(_address.text, await localLanAddresses());
    if (target == null) {
      if (mounted) setState(() => _message = '방 번호나 주소를 다시 확인해 주세요. (예: 37 또는 192.168.0.37)');
      return;
    }
    _join(target.host, target.port);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('방 찾기', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Colors.transparent),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (_lobbyNames != null) ...[
                  LanInfoCard(
                    title: '방장이 시작하기를 기다리는 중이에요${_lobbyNeed == null ? '' : ' (${_lobbyNames!.length}/$_lobbyNeed명)'}',
                    lines: _lobbyNames!,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: _leaveLobby, icon: const Icon(Icons.logout_rounded), label: const Text('방에서 나가기')),
                  const SizedBox(height: 16),
                ],
                if (_message != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: scheme.errorContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: scheme.error),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_message!, style: const TextStyle(fontSize: 14, height: 1.35))),
                      ],
                    ),
                  ),
                Text('열려 있는 방', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                if (_rooms.isEmpty)
                  Container(
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
                  )
                else
                  for (final r in _rooms)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      color: scheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: scheme.outlineVariant)),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: Icon(Icons.wifi_rounded, color: widget.color),
                        ),
                        title: Text(widget.roomTitle(r), style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_nameOf(r)} 방 · ${r.address.split('.').last}번', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: widget.color)),
                            Text(widget.roomSubtitle(r), style: const TextStyle(fontSize: 12.5)),
                          ],
                        ),
                        trailing: FilledButton(onPressed: _connecting ? null : () => _join(r.address, r.port), child: const Text('들어가기')),
                      ),
                    ),
                const SizedBox(height: 24),
                Text('방 번호로 들어가기', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '방이 위에 안 보이면, 방을 만든 기기 화면에 나온 방 번호(또는 주소)를 입력하세요.',
                  style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _address,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _joinTyped(),
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '방 번호 또는 주소', hintText: '37  또는  192.168.0.37', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(onPressed: _connecting ? null : _joinTyped, child: const Text('들어가기')),
                  ],
                ),
                if (_connecting) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
