import 'dart:math';

import 'package:flutter/material.dart';

import 'settings.dart';
import 'settings_scope.dart';

/// 별명(닉네임)의 최대 글자 수.
const int kMaxNicknameLength = 10;

const List<String> _adjectives = [
  '빨간', '파란', '노란', '초록', '보라', '분홍', '하얀', '까만', '작은', '큰',
  '빠른', '느긋한', '용감한', '졸린', '신나는', '똑똑한', '배고픈', '씩씩한', '수줍은', '반짝이는',
];
const List<String> _animals = [
  '토끼', '여우', '고래', '펭귄', '사자', '호랑이', '거북이', '다람쥐', '판다', '부엉이',
  '오리', '고양이', '강아지', '코끼리', '기린', '돌고래', '햄스터', '앵무새', '곰', '너구리',
];

/// 처음 한 번 저절로 지어지는 별명 (예: "빨간 토끼"). 20×20가지.
String randomNickname([Random? rng]) {
  final r = rng ?? Random();
  return '${_adjectives[r.nextInt(_adjectives.length)]} ${_animals[r.nextInt(_animals.length)]}';
}

/// 사람이 입력한(또는 상대에게서 받은) 별명을 다듬는다: 앞뒤 공백을 지우고, 연속한 공백은 하나로 하고,
/// [kMaxNicknameLength]글자까지만 남긴다. 비어 있으면 null.
String? cleanNickname(Object? raw) {
  if (raw is! String) return null;
  final t = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return null;
  final runes = t.runes.toList();
  return String.fromCharCodes(runes.length > kMaxNicknameLength ? runes.sublist(0, kMaxNicknameLength) : runes).trim();
}

/// 별명을 바꾸는 창: 직접 쓰거나 "다시 뽑기"(주사위)로 새 별명을 받는다. 저장하면 설정에 기록된다.
Future<void> editNickname(BuildContext context, {Settings? settings}) async {
  settings ??= SettingsScope.of(context);
  final saved = await showDialog<String>(context: context, builder: (_) => _NicknameDialog(initial: settings!.nickname));
  final clean = cleanNickname(saved);
  if (clean != null) settings.nickname = clean;
}

class _NicknameDialog extends StatefulWidget {
  const _NicknameDialog({required this.initial});

  final String initial;

  @override
  State<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<_NicknameDialog> {
  // 창이 닫히는 동안에도 입력칸이 쓰이니, 창이 완전히 사라질 때 함께 치운다.
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reroll() {
    final next = randomNickname();
    _controller.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('내 별명'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('같은 Wi‑Fi로 함께 할 때 방 이름과 상대에게 보이는 이름이에요.', style: TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLength: kMaxNicknameLength,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => Navigator.pop(context, v),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: '별명',
              suffixIcon: IconButton(tooltip: '다시 뽑기', icon: const Icon(Icons.casino_rounded), onPressed: _reroll),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: const Text('저장')),
      ],
    );
  }
}

/// "내 별명: 빨간 토끼 [바꾸기]" 한 줄 (설정 화면과 같은 Wi‑Fi 첫 화면에서 쓴다).
class NicknameBar extends StatelessWidget {
  const NicknameBar({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = SettingsScope.of(context).nickname;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => editNickname(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Icon(Icons.badge_rounded, color: scheme.primary),
              const SizedBox(width: 10),
              const Text('내 별명', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 10),
              Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
              TextButton.icon(onPressed: () => editNickname(context), icon: const Icon(Icons.edit_rounded, size: 18), label: const Text('바꾸기')),
            ],
          ),
        ),
      ),
    );
  }
}
