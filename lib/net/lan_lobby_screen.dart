import 'dart:async';

import 'package:flutter/material.dart';

import '../core/settings_scope.dart';
import 'lan_connection.dart';
import 'lan_discovery.dart';
import 'lan_rejoin.dart';
import 'lan_screens.dart';

/// 방이 다 찼을 때 게임이 정하는 것: 손님마다 보낼 시작 메시지(`t: 'start'`, 들어온 순서대로)와, 방을 연 쪽이 띄울 게임 화면.
///
/// 게임 화면은 손님 연결들과 함께 "다시 들어오기 접수처"([LanRejoinDesk])를 받는다. 판이 시작된 뒤에도 방 문을 열어 두고,
/// 나갔던 손님이 돌아오면 이 접수처가 받아 준다. 화면이 닫힐 때 접수처도 닫아야 한다 (안 닫아도 방이 닫힐 때 같이 닫힌다).
class LanLobbyPlan {
  const LanLobbyPlan({required this.messages, required this.hostScreen});

  final List<Map<String, dynamic>> messages;
  final Widget Function(List<LanConnection> guests, LanRejoinDesk desk) hostScreen;
}

/// 인원수를 정하지 않고 연 방의 규칙: 방장 말고 최대 [maxPlayers] - 1명까지 들어올 수 있고, 한 명이라도 들어오면
/// 방장이 "이대로 시작하기" 또는 "CPU 몇 명 넣고 시작하기"를 눌러 시작한다. (자리가 다 차면 저절로 시작)
class LanFlexibleRoom {
  const LanFlexibleRoom({required this.allowedPlayers, required this.onStart, this.maxPlayers = 4});

  /// 할 수 있는 전체 인원 수들 (CPU 포함). 예: 쿼리도는 {2, 4}, 다빈치 코드는 {2, 3, 4}.
  final Set<int> allowedPlayers;

  /// 방에 들어올 수 있는 가장 큰 전체 인원 (CPU 포함).
  final int maxPlayers;

  /// 시작할 때 들어와 있는 손님들과 넣을 CPU 수로 시작 메시지들과 방장의 게임 화면을 정한다.
  final LanLobbyPlan Function(List<LanConnection> guests, int cpus) onStart;

  /// 지금 들어와 있는 사람이 [humans]명일 때 고를 수 있는 CPU 수들 (작은 수부터). 자리가 차면 비어 있다.
  List<int> cpuChoices(int humans) => [
        for (var k = 0; humans + k <= maxPlayers; k++)
          if (allowedPlayers.contains(humans + k)) k,
      ];
}

/// 여러 명이 모이는 방: 방을 열고 [needGuests]명이 모두 들어오면 저절로 시작한다.
/// ([LanFlexibleRoom]을 주면 인원수를 정하지 않고, 방장이 시작 단추로 CPU를 넣어 채운다.)
///
/// 들어온 사람의 이름은 방 화면에 모두 보이고, 손님들 화면에도 같은 목록이 보인다 (`lobby` 메시지).
/// 기다리는 동안 누가 나가면 목록에서 빠지고 그 자리는 다시 빈다. (한 명만 기다리는 게임은 [LanHostScreen])
class LanLobbyScreen extends StatefulWidget {
  const LanLobbyScreen({
    super.key,
    required this.game,
    required this.gameName,
    required this.info,
    required this.summary,
    required this.needGuests,
    this.onFull,
    this.flexible,
    this.gamePort = kLanGamePort,
    this.discoveryPort = kLanDiscoveryPort,
  }) : assert(onFull != null || flexible != null, 'onFull이나 flexible 중 하나는 있어야 해요');

  /// 인원수를 정하지 않은 방 (방장이 시작 단추로 정한다). [needGuests]는 이때 최대 손님 수로 쓴다.
  LanLobbyScreen.flexible({
    Key? key,
    required String game,
    required String gameName,
    required Map<String, dynamic> info,
    required List<String> summary,
    required LanFlexibleRoom room,
    int gamePort = kLanGamePort,
    int discoveryPort = kLanDiscoveryPort,
  }) : this(
          key: key,
          game: game,
          gameName: gameName,
          info: info,
          summary: summary,
          needGuests: room.maxPlayers - 1,
          flexible: room,
          gamePort: gamePort,
          discoveryPort: discoveryPort,
        );

  final String game;
  final String gameName;

  /// 방을 찾는 기기에게 알려 줄 방 정보. 들어온 사람 수(`joined`)와 필요한 사람 수(`need`)는 이 화면이 채운다.
  final Map<String, dynamic> info;
  final List<String> summary;

  /// 방장 말고 더 필요한 사람 수.
  final int needGuests;

  /// 방이 찼을 때 시작 메시지들과 방장의 게임 화면을 정한다. 손님은 들어온 순서대로 주어진다.
  final LanLobbyPlan Function(List<LanConnection> guests)? onFull;

  /// 인원수를 정하지 않은 방이면 그 규칙.
  final LanFlexibleRoom? flexible;

  /// (시험용) 연결을 기다리는 포트와 방 찾기 응답 포트.
  final int gamePort, discoveryPort;

  @override
  State<LanLobbyScreen> createState() => _LanLobbyScreenState();
}

class _LanLobbyScreenState extends State<LanLobbyScreen> {
  late String _roomName;
  bool _opened = false;
  LanHost? _host;
  StreamSubscription<LanConnection>? _sub;
  List<String> _addresses = const [];
  String? _error;
  bool _starting = false;
  final List<LanConnection> _guests = [];

  /// 시작한 뒤의 "다시 들어오기 접수처" (방 문을 열어 둔다). 이 화면이 사라질 때 같이 닫는다.
  LanRejoinDesk? _desk;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    _roomName = SettingsScope.of(context).nickname;
    _open();
  }

  Map<String, dynamic> get _info => {
        ...widget.info,
        'room': _roomName,
        'nick': _roomName,
        'joined': _guests.length + 1,
        'need': widget.needGuests + 1,
        if (widget.flexible != null) 'flex': true, // 인원수를 정하지 않은 방 (모이는 대로 방장이 시작한다)
      };

  Future<void> _open() async {
    setState(() => _error = null);
    try {
      final host = await LanHost.open(
        game: widget.game,
        info: _info,
        maxGuests: widget.needGuests,
        gamePort: widget.gamePort,
        discoveryPort: widget.discoveryPort,
      );
      if (!mounted) {
        await host.close();
        return;
      }
      _host = host;
      _sub = host.guests.listen(_onGuest);
      final addresses = await localLanAddresses();
      if (mounted) setState(() => _addresses = addresses);
    } catch (_) {
      if (mounted) setState(() => _error = '방을 열 수 없어요. 이 기기가 Wi‑Fi에 연결되어 있는지 확인해 주세요.');
    }
  }

  /// 방에 있는 사람들 이름 (방장 먼저, 들어온 순서대로).
  List<String> get _names => [_roomName, for (final g in _guests) g.peerNick];

  void _publish() {
    _host?.updateInfo(_info);
    final lobby = {'t': 'lobby', 'names': _names, if (widget.flexible == null) 'need': widget.needGuests + 1};
    for (final g in _guests) {
      g.send(lobby);
    }
  }

  void _onGuest(LanConnection conn) {
    if (_starting) {
      conn.close();
      return;
    }
    _guests.add(conn);
    conn.closed.then((_) {
      if (_starting || !_guests.remove(conn)) return;
      if (mounted) setState(_publish);
    });
    if (mounted) setState(_publish);
    if (_guests.length == widget.needGuests) _start(); // 자리가 다 차면 저절로 시작 (인원을 안 정한 방도 마찬가지)
  }

  /// 시작한다. 인원수를 정하지 않은 방은 [cpus]명을 CPU로 채운다.
  Future<void> _start({int cpus = 0}) async {
    if (_starting) return;
    _starting = true;
    final guests = [..._guests];
    final flexible = widget.flexible;
    final plan = flexible != null ? flexible.onStart(guests, cpus) : widget.onFull!(guests);
    final host = _host!;
    _host = null;
    // 방 문은 닫지 않고 접수처에 넘긴다: 나갔던 손님이 (앱을 껐다 켜도) 표를 들고 다시 들어올 수 있게
    final desk = _desk = LanRejoinDesk.open(host: host, guests: guests, info: _info);
    for (var i = 0; i < guests.length; i++) {
      guests[i].send({'t': 'start', 'nick': _roomName, 'rejoin': desk.ticketFor(i), ...plan.messages[i]});
    }
    if (!mounted) {
      for (final g in guests) {
        g.close();
      }
      await desk.close();
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => plan.hostScreen(guests, desk)));
    await desk.close();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _host?.close();
    _desk?.close();
    if (!_starting) {
      for (final g in _guests) {
        g.close();
      }
    }
    super.dispose();
  }

  /// 인원수를 정하지 않은 방: 한 명이라도 들어왔으면 시작 단추들을 보여 준다 ("이대로 시작하기", "CPU 1명 넣고 시작하기" …).
  Widget _startChoices(LanFlexibleRoom flexible, ColorScheme scheme) {
    final humans = _guests.length + 1;
    if (_guests.isEmpty) {
      return Text(
        '아무도 들어오지 않았어요. 한 명이 들어오면 시작 단추가 나타나요.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.5, color: scheme.onSurface.withValues(alpha: 0.65)),
      );
    }
    final choices = flexible.cpuChoices(humans);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final k in choices) ...[
          k == 0
              ? FilledButton.icon(
                  key: const ValueKey('start-cpus0'),
                  onPressed: _starting ? null : () => _start(),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text('이대로 시작하기 ($humans명)'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                )
              : OutlinedButton.icon(
                  key: ValueKey('start-cpus$k'),
                  onPressed: _starting ? null : () => _start(cpus: k),
                  icon: const Icon(Icons.smart_toy_rounded),
                  label: Text('CPU $k명 넣고 시작하기 (${humans + k}명)'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
          const SizedBox(height: 8),
        ],
        Text(
          '사람이 더 들어올 수 있어요. 모이는 대로 눌러서 시작하세요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final need = widget.needGuests + 1;
    final flexible = widget.flexible;
    return Scaffold(
      appBar: AppBar(title: const Text('사람을 기다리는 중', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Colors.transparent),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (_error != null) ...[
                  Icon(Icons.wifi_off_rounded, size: 56, color: scheme.error),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.4)),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _open, child: const Text('다시 시도')),
                ] else ...[
                  const Center(child: SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 5))),
                  const SizedBox(height: 18),
                  const Text('방이 열렸어요', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    flexible == null
                        ? '다른 기기에서 ${widget.gameName} → "같은 Wi‑Fi로 함께" → "방 찾기"를 눌러\n이 방에 들어오세요. $need명이 모두 모이면 바로 시작해요.'
                        : '다른 기기에서 ${widget.gameName} → "같은 Wi‑Fi로 함께" → "방 찾기"를 눌러\n이 방에 들어오세요. 모이는 대로 시작할 수 있어요: 한 명이라도 들어오면 아래 단추가 나타나요. (최대 $need명, 다 차면 바로 시작해요)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.5, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.75)),
                  ),
                  const SizedBox(height: 20),
                  LanInfoCard(
                    title: flexible == null ? '모인 사람 (${_guests.length + 1}/$need명)' : '모인 사람 (${_guests.length + 1}명 · 최대 $need명)',
                    lines: flexible == null
                        ? [for (var i = 0; i < need; i++) i < _names.length ? _names[i] : '… 기다리는 중']
                        : [..._names, if (_names.length < need) '… 더 들어올 수 있어요'],
                  ),
                  if (flexible != null) ...[
                    const SizedBox(height: 12),
                    _startChoices(flexible, scheme),
                  ],
                  const SizedBox(height: 12),
                  LanInfoCard(
                    title: '우리 방 이름 (방장 별명)',
                    lines: [_roomName, if (roomNumberOf(_addresses) != null) '방 번호 ${roomNumberOf(_addresses)}'],
                    big: true,
                  ),
                  const SizedBox(height: 12),
                  LanInfoCard(lines: widget.summary),
                  const SizedBox(height: 12),
                  LanInfoCard(
                    title: '방이 안 보이면, 다른 기기에 방 번호나 이 주소를 입력하세요',
                    lines: [
                      if (_addresses.isEmpty) 'Wi‑Fi 주소를 찾지 못했어요. Wi‑Fi에 연결되어 있는지 확인해 주세요.',
                      for (final a in _addresses) _host != null && _host!.port != kLanGamePort ? '$a:${_host!.port}' : a,
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
