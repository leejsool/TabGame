/// 예언 교과학습에 쓰는 순수 계산들 (화면과 무관).
library;

/// 폰 노이만 방식으로 자연수 [n]을 집합으로 쓴 글. 0 = {}, 1 = {0}, 2 = {0, 1}, … (각 수는 앞선 모든 수의 집합)
///
/// 예: 0 → `{}`, 1 → `{{}}`, 2 → `{{}, {{}}}`.
String vonNeumann(int n) {
  if (n == 0) return '{}';
  return '{${[for (var i = 0; i < n; i++) vonNeumann(i)].join(', ')}}';
}

/// 집합으로 쓴 글에서 중괄호 한 쌍({ })이 몇 개인가. 수 n은 2의 n제곱 쌍이다.
int braceCount(int n) => RegExp('{').allMatches(vonNeumann(n)).length;

/// 숫자 줄 [numbers]와 "그 숫자가 표 전체에 나타나는 횟수" 줄 [counts]로 된 표에서,
/// 숫자마다 실제로 표 전체(두 줄)에 몇 번 나타나는가.
List<int> occurrences(List<int> numbers, List<int> counts) {
  final all = [...numbers, ...counts];
  return [for (final n in numbers) all.where((v) => v == n).length];
}

/// 표가 자기 자신을 정확히 설명하는가: 줄 [counts]의 숫자가 모두 실제 나타나는 횟수와 같다.
bool selfDescribing(List<int> numbers, List<int> counts) {
  final occ = occurrences(numbers, counts);
  for (var i = 0; i < numbers.length; i++) {
    if (occ[i] != counts[i]) return false;
  }
  return true;
}

/// 숫자 줄이 1, 2, …, [k]인 표에서 자기 자신을 정확히 설명하는 횟수 줄들 (모든 경우를 따져 본 것).
List<List<int>> selfDescribingTables(int k) {
  final numbers = [for (var i = 1; i <= k; i++) i];
  final out = <List<int>>[];
  final counts = List<int>.filled(k, 1);
  void rec(int i) {
    if (i == k) {
      if (selfDescribing(numbers, counts)) out.add(List<int>.of(counts));
      return;
    }
    for (var v = 1; v <= 2 * k; v++) {
      counts[i] = v;
      rec(i + 1);
    }
  }

  rec(0);
  return out;
}

/// 글자 수를 세는 규칙: 공백을 뺀 글자(한글·숫자·문장부호)의 수.
int letterCount(String s) => s.replaceAll(RegExp(r'\s'), '').runes.length;

/// 자기 자신의 글자 수를 정확히 말하는 문장.
const String kSelfCountingSentence = '이 문장은 공백을 빼면 모두 열여덟 글자예요';

/// 리 샐로스의 자기 설명 팬그램(모든 알파벳을 쓴 문장). 자기 안의 알파벳 개수를 스물여섯 글자 모두 정확히 말한다.
const String kSallowsPangram =
    'This pangram contains four As, one B, two Cs, one D, thirty Es, six Fs, five Gs, seven Hs, eleven Is, '
    'one J, one K, two Ls, two Ms, eighteen Ns, fifteen Os, two Ps, one Q, five Rs, twenty-seven Ss, '
    'eighteen Ts, two Us, seven Vs, eight Ws, two Xs, three Ys, & one Z.';

/// 영어 알파벳(A~Z)이 [s]에 몇 번씩 나타나는가 (대소문자 구분 없음). 키는 'A'~'Z' 순서로 항상 26개.
Map<String, int> letterTally(String s) {
  final upper = s.toUpperCase();
  return {
    for (var c = 0x41; c <= 0x5A; c++) String.fromCharCode(c): upper.runes.where((r) => r == c).length,
  };
}

/// 샐로스의 또 다른 자기 설명 문장. 알파벳뿐 아니라 쉼표·어포스트로피(’)·하이픈·느낌표의 개수까지 정확히 말한다.
const String kSallowsFoolSentence =
    'Only the fool would take trouble to verify that his sentence was composed of ten a’s, three b’s, '
    'four c’s, four d’s, forty-six e’s, sixteen f’s, four g’s, thirteen h’s, fifteen i’s, two k’s, nine l’s, '
    'four m’s, twenty-five n’s, twenty-four o’s, five p’s, sixteen r’s, forty-one s’s, thirty-seven t’s, '
    'ten u’s, eight v’s, eight w’s, four x’s, eleven y’s, twenty-seven commas, twenty-three apostrophes, '
    'seven hyphens and, last but not least, a single !';

/// [keys]의 각 글자(부호 포함)가 [s]에 몇 번씩 나타나는가 (대소문자 구분 없음). 키 순서를 그대로 지킨다.
Map<String, int> charTally(String s, Iterable<String> keys) {
  final lower = s.toLowerCase();
  return {for (final k in keys) k: RegExp(RegExp.escape(k)).allMatches(lower).length};
}

/// 베리의 역설에 나오는 설명. 공백을 빼면 24글자라서, 스스로 "스물다섯 글자 미만"이다.
const String kBerryPhrase = '스물다섯 글자 미만으로 정의할 수 없는 가장 작은 양의 정수';

/// 행 또는 열 한 줄의 "끝날 때 숫자 개수" 시험: 줄 칸이 [cells]개이고 이미 숫자가 [numbers]개 있을 때 다음 빈칸에
/// 숫자를 쓰면 몇 개가 되는가? (맛보기 노트: 4, X, 빈칸, 3인 줄에 무엇을 쓰면 어떻게 되는지 보려고 쓴다.)
({int count, List<int> correct}) rowOutcome(List<int> row) {
  // row: 숫자(1 이상) / X(-1). 모두 채워진 줄에서 숫자 개수와 맞힌 숫자들.
  final count = row.where((v) => v > 0).length;
  return (count: count, correct: [for (final v in row) if (v == count) v]);
}
