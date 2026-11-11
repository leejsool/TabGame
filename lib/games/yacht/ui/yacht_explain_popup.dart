import 'package:flutter/material.dart';

import '../core/yacht_advisor.dart';
import '../core/yacht_fraction.dart';
import '../core/yacht_rules.dart';
import 'yacht_fraction_view.dart';
import 'yacht_look.dart';
import 'yacht_scale.dart';

const List<String> _letters = ['A', 'B', 'C', 'D', 'E'];

/// "6이", "2가"처럼 숫자 뒤에 붙는 조사.
String _josa(int n) => const {1: '이', 2: '가', 3: '이', 4: '가', 5: '가', 6: '이'}[n]!;

/// 숫자 목록을 읽기 쉽게: 이어진 3개 이상은 "1~4", 나머지는 "1, 3, 5".
String _compress(List<int> v) {
  final out = <String>[];
  var i = 0;
  while (i < v.length) {
    var j = i;
    while (j + 1 < v.length && v[j + 1] == v[j] + 1) {
      j++;
    }
    if (j - i >= 2) {
      out.add('${v[i]}~${v[j]}');
    } else {
      for (var k = i; k <= j; k++) {
        out.add('${v[k]}');
      }
    }
    i = j + 1;
  }
  return out.join(', ');
}

/// 해당하는 경우들을 한 줄씩 적은 글 (주사위 수 [n]에 따라 보기 좋은 방식으로).
List<String> yachtCaseLines(List<List<int>> tuples, int n) {
  if (tuples.isEmpty) return const [];
  if (n == 1) {
    return ['A가 ${_compress([for (final t in tuples) t[0]])}일 때 → ${tuples.length}가지'];
  }
  if (n == 2) {
    final byFirst = <int, List<int>>{};
    for (final t in tuples) {
      byFirst.putIfAbsent(t[0], () => []).add(t[1]);
    }
    return [
      for (final e in byFirst.entries) 'A가 ${e.key}일 때, B가 ${_compress(e.value)} → ${e.value.length}가지',
    ];
  }
  // 3개 이상: 눈의 조합(순서는 무시)별로 몇 가지씩인지
  final bySet = <String, int>{};
  for (final t in tuples) {
    final key = ([...t]..sort()).join(', ');
    bySet.update(key, (v) => v + 1, ifAbsent: () => 1);
  }
  final keys = bySet.keys.toList();
  final lines = [for (final k in keys.take(10)) '($k)가 나오는 순서들 → ${bySet[k]}가지'];
  if (keys.length > 10) lines.add('… 그 밖에 ${keys.length - 10}가지 조합이 더 있어요');
  return lines;
}

/// 해당하는 경우가 "특정 눈 f가 하나라도 나오는 모든 경우"이면 f, 아니면 null.
int? _containsFace(List<List<int>> tuples, int n) {
  final total = _pow(6, n), without = _pow(5, n);
  if (tuples.length != total - without) return null;
  for (var f = 1; f <= 6; f++) {
    if (tuples.every((t) => t.contains(f))) return f;
  }
  return null;
}

/// 해당하는 경우가 "특정 눈 f가 하나도 안 나오는 모든 경우"이면 f, 아니면 null.
int? _excludesFace(List<List<int>> tuples, int n) {
  if (tuples.length != _pow(5, n)) return null;
  for (var f = 1; f <= 6; f++) {
    if (tuples.every((t) => !t.contains(f))) return f;
  }
  return null;
}

int _pow(int x, int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= x;
  }
  return r;
}

/// 분수 팝업 위에 한 번 더 뜨는 설명 창: "왜 이 확률일까요?"
///
/// 1) 다시 굴리는 주사위 n개의 모든 경우의 수 (6의 n제곱), 2) 그중 이 묶음에 해당하는 경우를 하나씩 센 것,
/// 3) 해당하는 수 ÷ 전체 = 확률, 4) 가능하면 다른 방법 (반대로 세기 · 겹치는 것 빼기)을 보여 준다.
Future<void> showYachtGroupExplain(
  BuildContext context, {
  required YachtAdvisor advisor,
  required YachtCategory cat,
  required List<int> dice,
  required YachtChanceBreakdown bd,
  required YachtBreakdownGroup group,
  String? lead,
}) {
  final n = bd.rolled;
  final total = _pow(6, n);
  final tuples = advisor.outcomesOf(cat, bd, group);
  final ways = tuples.length;
  final lines = yachtCaseLines(tuples, n);
  final contains = n > 0 && ways > 0 ? _containsFace(tuples, n) : null;
  final excludes = n > 0 && ways > 0 ? _excludesFace(tuples, n) : null;
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final small = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.45);
      const body = TextStyle(fontSize: 14.5, height: 1.45);
      const op = TextStyle(fontSize: 17, fontWeight: FontWeight.w800);

      Widget section(String text) => Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 5),
            child: Text(text, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: kYachtColor)),
          );

      Widget box(Widget child) => Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
            child: child,
          );

      Widget die(int value, {bool kept = false}) => Padding(
            padding: const EdgeInsets.only(right: 5),
            child: YachtDie(value: value, size: 32, held: kept, accent: kYachtColor),
          );

      Widget blank(String letter) => Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: scheme.outline, width: 1.4), borderRadius: BorderRadius.circular(8)),
            child: Text(letter, style: TextStyle(fontWeight: FontWeight.w900, color: scheme.onSurfaceVariant)),
          );

      final what = group.done
          ? '“${cat.label}”이(가) 바로 완성되는 경우'
          : (group.next.num > 0 ? '아직 완성은 아니지만, 다음 굴림에서 완성될 확률이 ${group.next}인 경우' : '“${cat.label}”을(를) 더 이상 완성할 수 없는 경우');

      return YachtScaled(
        child: AlertDialog(
        key: const ValueKey('yacht-explain-popup'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        title: Row(
          children: [
            const Text('왜 ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            YachtFractionView(group.prob, size: 17, color: kYachtColor, bold: true),
            const Text('일까요?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (lead != null) ...[
                  Text(lead, key: const ValueKey('yacht-explain-lead'), style: body),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    for (final v in bd.keptValues) die(v, kept: true),
                    for (var i = 0; i < n; i++) blank(_letters[i]),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  n == 0
                      ? '굴릴 주사위가 없어요. 고정한 주사위만으로 이미 결정돼요.'
                      : '초록 테두리는 고정한 주사위, ${_letters.take(n).join(' · ')}는 다시 굴리는 주사위예요.',
                  style: small,
                ),
                const SizedBox(height: 6),
                Text('알아볼 경우: $what', style: body.copyWith(fontWeight: FontWeight.w700)),
                section('1. 전체 경우의 수'),
                box(
                  Text(
                    n == 0
                        ? '굴리지 않으니 경우는 1가지예요.'
                        : (n == 1
                            ? '주사위 하나는 1~6, 6가지가 나올 수 있어요. → 6가지'
                            : '주사위 하나마다 6가지씩이라 ${List.filled(n, '6').join(' × ')} = $total가지예요.'),
                    key: const ValueKey('yacht-explain-total'),
                    style: body,
                  ),
                ),
                section('2. 그중 이 경우에 해당하는 것'),
                if (lines.isEmpty)
                  box(Text(ways == 0 ? '해당하는 경우가 하나도 없어요.' : '굴리지 않아도 이미 이 경우예요.', style: body))
                else
                  box(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [for (final l in lines) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(l, style: body))],
                    ),
                  ),
                if (ways > 0 || n > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('합쳐서 $ways가지', key: const ValueKey('yacht-explain-ways'), style: body.copyWith(fontWeight: FontWeight.w900)),
                  ),
                section('3. 확률 = 해당하는 경우 ÷ 전체 경우'),
                box(
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      YachtFractionView.raw(ways, total, size: 16),
                      if (YachtFrac(ways, total) != YachtFrac.zero && (YachtFrac(ways, total).den != total)) ...[
                        const Text('=', style: op),
                        YachtFractionView(YachtFrac(ways, total), size: 16, color: kYachtColor, bold: true),
                      ],
                      Text('≈ ${yachtPercent(ways / total)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: kYachtColor)),
                    ],
                  ),
                ),
                if (contains != null) ...[
                  section('다른 방법: 반대로 세기'),
                  box(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$contains${_josa(contains)} 하나도 안 나오는 경우를 전체에서 빼요. 주사위 하나가 $contains${_josa(contains)} 아닐 확률은 5/6이에요.', style: body),
                        const SizedBox(height: 6),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            for (var i = 0; i < n; i++) ...[
                              if (i > 0) const Text('×', style: op),
                              const YachtFractionView.raw(5, 6, size: 15),
                            ],
                            if (n > 1) ...[const Text('=', style: op), YachtFractionView.raw(_pow(5, n), total, size: 15)],
                            const Text('→  1 -', style: op),
                            YachtFractionView.raw(_pow(5, n), total, size: 15),
                            const Text('=', style: op),
                            YachtFractionView.raw(ways, total, size: 15, color: kYachtColor, bold: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (n == 2) ...[
                    section('다른 방법: 겹치는 것 빼기'),
                    box(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('A가 $contains${_josa(contains)} 나올 확률과 B가 $contains${_josa(contains)} 나올 확률을 더하면, 둘 다 $contains${_josa(contains)} 나오는 경우를 두 번 센 셈이라 한 번 빼요.', style: body),
                          const SizedBox(height: 6),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              const YachtFractionView.raw(1, 6, size: 15),
                              const Text('+', style: op),
                              const YachtFractionView.raw(1, 6, size: 15),
                              const Text('-', style: op),
                              const YachtFractionView.raw(1, 36, size: 15),
                              const Text('=', style: op),
                              const YachtFractionView.raw(11, 36, size: 15, color: kYachtColor, bold: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else if (excludes != null) ...[
                  section('다른 방법: 곱해서 구하기'),
                  box(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('주사위 하나가 $excludes${_josa(excludes)} 아닐 확률은 5/6이고, 주사위마다 따로 굴러요. 모두 $excludes${_josa(excludes)} 아니려면 확률을 곱해요.', style: body),
                        const SizedBox(height: 6),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            for (var i = 0; i < n; i++) ...[
                              if (i > 0) const Text('×', style: op),
                              const YachtFractionView.raw(5, 6, size: 15),
                            ],
                            const Text('=', style: op),
                            YachtFractionView.raw(ways, total, size: 15, color: kYachtColor, bold: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인'))],
      ));
    },
  );
}

/// "다음 굴림에서 완성될 확률"(예: 1/6)을 눌렀을 때: 그 묶음에 드는 결과 하나를 예로 들어, 마지막 굴림의 확률을 같은 방식으로 설명한다.
Future<void> showYachtNextChanceExplain(
  BuildContext context, {
  required YachtAdvisor advisor,
  required YachtCategory cat,
  required YachtChanceBreakdown bd,
  required YachtBreakdownGroup group,
}) {
  final tuples = advisor.outcomesOf(cat, bd, group);
  if (tuples.isEmpty) return Future.value();
  final sample = [...bd.keptValues, ...tuples.first]..sort();
  final next = advisor.breakdown(cat, sample, 1);
  if (next == null) return Future.value();
  final done = next.groups.where((g) => g.done);
  if (done.isEmpty) return Future.value();
  return showYachtGroupExplain(
    context,
    advisor: advisor,
    cat: cat,
    dice: sample,
    bd: next,
    group: done.first,
    lead: '예를 들어 첫 굴림 결과가 ${sample.join(', ')}이(가) 나왔다고 해 봐요. 한 번 더 굴릴 때 “${cat.label}”이(가) 완성될 확률을 구하면 아래와 같아요. 이 묶음의 다른 결과들도 확률이 같아요.',
  );
}
