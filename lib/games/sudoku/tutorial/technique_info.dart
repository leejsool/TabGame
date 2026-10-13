import '../core/techniques.dart';

/// 심화 기술 연습에서 가르치는 기술 하나의 설명.
class TechniqueInfo {
  const TechniqueInfo({
    required this.technique,
    required this.summary,
    required this.what,
    required this.how,
    this.fill = false,
  });

  final Technique technique;

  /// 목록에 보이는 한 줄 설명.
  final String summary;

  /// 기술이 무엇인지.
  final String what;

  /// 판에서 어떻게 찾는지.
  final String how;

  /// true이면 후보를 지우는 대신 숫자를 3개 채우는 연습 (싱글 기술).
  final bool fill;

  String get id => 'sudoku_${technique.name}';
  String get label => technique.label;
  int get level => technique.level;
}

/// 연습 순서대로. (쉬운 기술부터)
const List<TechniqueInfo> kTechniqueInfos = [
  TechniqueInfo(
    technique: Technique.nakedSingle,
    fill: true,
    summary: '한 칸에 들어갈 숫자가 하나뿐일 때',
    what: '빈 칸의 같은 행·열·박스에 이미 있는 숫자는 쓸 수 없어요. 그걸 모두 빼고 나니 '
        '숫자가 딱 하나 남는다면, 그게 이 칸의 정답이에요.',
    how: '메모를 켜 두고 후보가 하나만 남은 칸을 찾아요. "빠른 메모" 버튼으로 후보를 한꺼번에 '
        '적어 두면 편해요.',
  ),
  TechniqueInfo(
    technique: Technique.hiddenSingle,
    fill: true,
    summary: '한 줄에서 그 숫자가 들어갈 칸이 한 곳뿐일 때',
    what: '칸 하나만 보면 후보가 여러 개여도, 행(열·박스) 전체를 보면 어떤 숫자가 들어갈 수 있는 '
        '칸이 딱 한 곳뿐일 때가 있어요. 그러면 그 숫자는 그 칸에 들어가야 해요.',
    how: '박스 하나를 정하고, 1부터 9까지 숫자를 하나씩 "이 숫자는 어느 칸에 들어갈 수 있지?" '
        '하고 따져 봐요. 이미 그 숫자가 있는 행과 열은 막혀 있어요.',
  ),
  TechniqueInfo(
    technique: Technique.pointing,
    summary: '박스 안의 후보가 한 줄로 몰려 있을 때',
    what: '한 박스 안에서 어떤 숫자가 들어갈 수 있는 칸이 모두 같은 행(또는 열)에 있다면, 그 숫자는 '
        '박스 안의 그 줄에 들어가요. 그러니 같은 줄의 박스 밖 칸에서는 그 숫자를 지울 수 있어요.',
    how: '박스마다 숫자 하나씩 후보가 있는 칸들을 훑어보고, 한 줄에 일직선으로 몰려 있는지 찾아요.',
  ),
  TechniqueInfo(
    technique: Technique.claiming,
    summary: '한 줄의 후보가 한 박스 안에 몰려 있을 때',
    what: '한 행(또는 열)에서 어떤 숫자가 들어갈 수 있는 칸이 모두 같은 박스 안에 있다면, 그 숫자는 '
        '그 박스의 이 줄에 들어가요. 그러니 같은 박스의 다른 줄 칸에서는 그 숫자를 지울 수 있어요.',
    how: '줄 하나를 정하고 숫자 하나의 후보 칸을 보세요. 그 칸들이 모두 한 박스 안에 있으면 찾은 거예요.',
  ),
  TechniqueInfo(
    technique: Technique.nakedPair,
    summary: '두 칸이 같은 두 숫자만 후보일 때',
    what: '같은 줄(또는 박스)의 두 칸이 똑같이 숫자 두 개만 후보라면, 그 두 숫자는 이 두 칸이 '
        '나눠 가져요. 그 줄의 다른 칸에서는 두 숫자를 지울 수 있어요.',
    how: '후보가 딱 두 개인 칸을 찾고, 같은 줄에 똑같은 후보 두 개를 가진 칸이 또 있는지 봐요.',
  ),
  TechniqueInfo(
    technique: Technique.hiddenPair,
    summary: '두 숫자가 들어갈 칸이 똑같은 두 칸뿐일 때',
    what: '한 줄에서 두 숫자가 들어갈 수 있는 칸이 똑같은 두 칸뿐이라면, 그 두 칸은 그 숫자들의 '
        '자리예요. 이 두 칸에 적힌 다른 후보는 지울 수 있어요.',
    how: '줄 하나에서 숫자들의 후보 칸을 비교해 보세요. 두 숫자가 같은 두 칸에만 나타나면 찾은 거예요.',
  ),
  TechniqueInfo(
    technique: Technique.nakedTriple,
    summary: '세 칸의 후보가 세 숫자 안에 모일 때',
    what: '같은 줄의 세 칸이 가진 후보를 모두 합쳐도 숫자가 세 개뿐이라면(칸마다 세 개가 모두 있지 '
        '않아도 돼요), 그 세 숫자는 이 세 칸의 몫이에요. 그 줄의 다른 칸에서 세 숫자를 지워요. '
        '같은 방식으로 네 칸·네 숫자(쿼드)도 있어요.',
    how: '후보가 2~3개인 칸들을 모아서, 합친 숫자가 세 개인 묶음을 찾아요.',
  ),
  TechniqueInfo(
    technique: Technique.hiddenTriple,
    summary: '세 숫자가 들어갈 칸이 세 칸뿐일 때',
    what: '한 줄에서 세 숫자가 들어갈 수 있는 칸이 똑같은 세 칸뿐이라면, 그 세 칸은 그 숫자들의 '
        '자리예요. 세 칸에 적힌 다른 후보는 지울 수 있어요.',
    how: '찾기 어려운 기술이에요. 힌트 버튼으로 어디를 봐야 하는지 확인하면서 연습해 보세요.',
  ),
  TechniqueInfo(
    technique: Technique.xWing,
    summary: '직사각형 모양으로 걸린 후보',
    what: '어떤 숫자가 두 행에서 모두 같은 두 열에만 들어갈 수 있다면(후보 네 개가 직사각형 모양), '
        '그 숫자는 두 행에 대각선으로 자리 잡아요. 그러면 그 두 열의 다른 칸에서는 이 숫자를 지울 '
        '수 있어요. 행과 열을 바꿔도 똑같아요.',
    how: '숫자 하나를 정해 두고, 후보가 딱 두 칸뿐인 줄 두 개가 같은 열(행)에 걸쳐 있는지 찾아요.',
  ),
  TechniqueInfo(
    technique: Technique.xyWing,
    summary: '후보가 두 개씩인 세 칸의 연쇄',
    what: '후보가 두 개씩인 세 칸이 있어요. 중심 칸 {A, B}, 날개 칸 {A, C}와 {B, C}. 중심이 A이면 '
        '한쪽 날개가 C가 되고, 중심이 B이면 다른 쪽 날개가 C가 되니, 어느 쪽이든 날개 중 하나는 C예요. '
        '그래서 두 날개가 모두 보는 칸에서는 C를 지울 수 있어요.',
    how: '후보가 두 개인 칸을 중심으로 잡고, 그 칸이 보는 칸 중에서 후보가 겹치는 두 칸(날개)을 찾아요.',
  ),
  TechniqueInfo(
    technique: Technique.xyzWing,
    summary: '후보가 세 개인 중심 칸을 가진 윙',
    what: 'XY-윙과 비슷하지만 중심 칸의 후보가 세 개 {A, B, C}예요. 날개는 {A, C}와 {B, C}. '
        '어떻게 되든 세 칸 중 하나는 반드시 C가 돼요. 그래서 세 칸이 모두 보는 칸에서만 C를 지울 수 있어요.',
    how: '후보가 세 개인 칸을 중심으로 잡고, 그 칸이 보는 두 칸(날개)과 후보를 비교해 보세요.',
  ),
  TechniqueInfo(
    technique: Technique.swordfish,
    summary: 'X-윙의 세 줄 버전',
    what: 'X-윙을 세 줄로 넓힌 거예요. 어떤 숫자가 세 행에서 모두 같은 세 열 안에만 들어갈 수 있다면, '
        '그 세 열의 다른 칸에서 이 숫자를 지울 수 있어요. 행과 열을 바꿔도 똑같아요.',
    how: '아주 어려운 기술이에요. 힌트로 어떤 줄들을 봐야 하는지 확인하면서 익혀 보세요.',
  ),
];

/// 난이도 묶음 이름.
String levelTitle(int level) => switch (level) {
      1 => 'Lv.1 기본 기술 (쉬움)',
      2 => 'Lv.2 중급 기술 (보통)',
      3 => 'Lv.3 고급 기술 (어려움)',
      _ => 'Lv.4 전문가 기술 (어려움)',
    };
