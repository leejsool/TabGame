import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 버튼의 `textStyle: TextStyle(...)`은 앱 테마의 글자 모양을 통째로 바꾼다.
/// 글꼴을 빠뜨리면 그 버튼 글자만 나눔고딕 대신 기기 기본 글꼴로 나오니, 모든 곳에 글꼴이 들어 있는지 코드를 훑어 확인한다.
void main() {
  test('버튼 글자 모양(textStyle)에는 모두 나눔고딕이 들어 있다', () {
    final start = RegExp(r'textStyle:\s*(const\s+)?TextStyle\(');
    final missing = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      for (final m in start.allMatches(src)) {
        // 여는 괄호에 맞는 닫는 괄호까지가 이 TextStyle의 내용
        var depth = 1, i = m.end;
        while (i < src.length && depth > 0) {
          if (src[i] == '(') depth++;
          if (src[i] == ')') depth--;
          i++;
        }
        if (!src.substring(m.end, i).contains('fontFamily')) {
          missing.add('${f.path}:${'\n'.allMatches(src.substring(0, m.start)).length + 1}');
        }
      }
    }
    expect(missing, isEmpty, reason: "fontFamily: 'NanumGothic'을 넣어 주세요");
  });
}
