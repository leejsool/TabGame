import 'dart:async';

import 'package:flutter/material.dart';

import '../core/game_info.dart';
import '../core/game_registry.dart' show allGames;
import '../core/nickname.dart';
import '../core/settings_scope.dart';
import '../records/records_screen.dart';
import '../versus/vs_mode_switch.dart';
import 'lan_connection.dart';
import 'lan_discovery.dart';
import 'lan_join_parts.dart';
import 'lan_rejoin_flow.dart';
import 'lan_screens.dart';

/// 같은 Wi‑Fi에서 열린 방을 찾아 들어가는 화면. 주소를 직접 입력해서 들어갈 수도 있다.
///
/// [LanChooseScreen] 안에서 열리면([LanHubScope]) 같은 Wi‑Fi 첫 화면 노릇도 한다: 위에 모드 전환·별명, 아래에 "방 만들기" 단추.
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

  /// 이 게임에서 하다가 나온 방의 "다시 들어오기 표" (있으면 맨 위에 "하던 방" 카드를 보인다).
  RejoinTicket? _ticket;

  @override
  void initState() {
    super.initState();
    _startFinder();
    RejoinTickets.changes.addListener(_loadTicket);
    _loadTicket();
  }

  Future<void> _loadTicket() async {
    final t = await RejoinTickets.of(widget.game);
    if (mounted) setState(() => _ticket = t);
  }

  /// 표로 다시 들어갈 때 판 화면을 만들어 주는 함수 (게임 목록에 등록된 것).
  Widget? Function(Map<String, dynamic> resume, LanConnection conn)? get _resume {
    for (final g in allGames) {
      if (g.lanGame == widget.game) return g.lanResume;
    }
    return null;
  }

  /// 하던 방에 표로 다시 들어간다 (이미 시작한 판이라 방 목록에는 안 보이는 방).
  Future<void> _rejoin(RejoinTicket ticket) async {
    final build = _resume;
    if (_connecting || build == null) return;
    setState(() {
      _connecting = true;
      _message = null;
    });
    try {
      final result = await lanRejoinWithProgress(context, ticket, discoveryPort: widget.discoveryPort, extraTargets: widget.extraTargets);
      if (!mounted) {
        result.conn?.close();
        return;
      }
      if (!result.ok) {
        setState(() => _message = lanRejoinFailText(result.fail!));
        return;
      }
      final screen = build(result.resume!, result.conn!);
      if (screen == null) {
        result.conn!.close();
        setState(() => _message = '판의 모습을 받지 못했어요. 다시 시도해 주세요.');
        return;
      }
      _stopFinder();
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
      if (mounted) _startFinder();
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
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
    RejoinTickets.changes.removeListener(_loadTicket);
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

  /// 아래 "방 만들기": 방 찾기를 잠시 멈추고(내가 연 방이 목록에 뜨지 않게) 방 만들기 화면을 열었다가, 돌아오면 다시 찾는다.
  Future<void> _createRoom(LanHubScope hub) async {
    _stopFinder();
    if (mounted) setState(() {});
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: hub.createRoom));
    if (mounted) _startFinder();
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
    // 하던 방의 번호를 넣었으면 표로 제자리에 다시 앉는다 (이미 시작한 방은 새 손님을 받지 않는다)
    final ticket = _ticket;
    if (ticket != null && ticket.host == target.host && _resume != null) {
      _rejoin(ticket);
      return;
    }
    _join(target.host, target.port);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hub = LanHubScope.maybeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(hub?.title ?? '방 찾기', style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          if (hub != null)
            IconButton(
              tooltip: '내 기록',
              icon: const Icon(Icons.emoji_events_rounded),
              onPressed: () => openRecords(context, game: hub.recordsGame),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                // 위: (첫 화면일 때) 모드 전환과 별명 — 방을 찾는 동안에도 바꿀 수 있다
                if (hub != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      children: [
                        VsModeSwitch(gameId: hub.recordsGame, current: PlayMode.wifi),
                        const SizedBox(height: 12),
                        const NicknameBar(),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                      if (_ticket != null && _resume != null && _lobbyNames == null)
                        LanRejoinRoomCard(ticket: _ticket!, color: widget.color, onRejoin: _connecting ? null : () => _rejoin(_ticket!)),
                      Text('열려 있는 방', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      if (_rooms.isEmpty)
                        const LanSearchingBox()
                      else
                        for (final r in _rooms)
                          LanRoomTile(
                            title: widget.roomTitle(r),
                            nameLine: '${_nameOf(r)} 방 · ${r.address.split('.').last}번',
                            subtitle: widget.roomSubtitle(r),
                            color: widget.color,
                            onJoin: _connecting ? null : () => _join(r.address, r.port),
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
                // 아래: (첫 화면일 때) 방 만들기
                if (hub != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _connecting ? null : () => _createRoom(hub),
                        icon: const Icon(Icons.add_home_work_rounded),
                        label: const Text('방 만들기'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          textStyle: const TextStyle(fontFamily: 'Pretendard', fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
