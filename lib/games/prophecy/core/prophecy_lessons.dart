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

/// 베리의 역설에 나오는 설명 (스무 글자 이하로는 표현할 수 없는 가장 작은 수).
const String kBerryPhrase = '스무 글자 이하로 표현할 수 없는 가장 작은 수';

/// 행 또는 열 한 줄의 "끝날 때 숫자 개수" 시험: 줄 칸이 [cells]개이고 이미 숫자가 [numbers]개 있을 때 다음 빈칸에
/// 숫자를 쓰면 몇 개가 되는가? (맛보기 노트: 4, X, 빈칸, 3인 줄에 무엇을 쓰면 어떻게 되는지 보려고 쓴다.)
({int count, List<int> correct}) rowOutcome(List<int> row) {
  // row: 숫자(1 이상) / X(-1). 모두 채워진 줄에서 숫자 개수와 맞힌 숫자들.
  final count = row.where((v) => v > 0).length;
  return (count: count, correct: [for (final v in row) if (v == count) v]);
}
