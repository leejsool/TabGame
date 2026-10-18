part of 'prophecy_lesson_screen.dart';

// 단원 내용 (파일을 역할별로 나눈 것)

List<Widget> _unitSelfDescribing(BuildContext context) => [
      lessonP('이번에는 표 하나가 자기 자신을 설명하게 만들어 봐요. 위 줄에는 숫자 1, 2, 3, 4가 있고, 아래 줄에는 "그 숫자가 이 표에 몇 번 나타나는지"를 써요. 이때 아래 줄에 쓴 숫자도 표의 일부라서 함께 세어야 해요!'),
      lessonH(context, '칸이 하나뿐인 표'),
      lessonP('숫자 1 하나만 있는 표로 해 볼게요. 아래 줄에 쓴 숫자도 표의 일부라서, 쓰는 순간 표의 모습이 바뀐다는 점을 보세요.'),
      const OneCellTableExamples(),
      lessonP('쓰는 순간 설명이 틀려지는, 예언 게임과 똑같은 일이에요. 그럼 "2"가 들어가는 칸을 하나 더 늘리면 도움이 될까요? 아래 실습에서 칸 수를 2로 바꿔 직접 해 보세요. 그래도 안 맞아요!'),
      lessonH(context, '직접 맞춰 보세요'),
      lessonP('칸 수를 바꿔 가며 위아래 화살표로 아래 줄의 숫자를 고쳐 보세요. 모든 칸이 초록이 되면 성공이에요.'),
      const SelfTableLab(),
      lessonP('칸이 1개, 2개, 3개인 표는 가능한 모든 경우를 따져 봐도 답이 없어요. 답이 생기는 가장 작은 표는 4칸짜리예요. 4칸에는 아래 줄이 2·3·2·1인 답 말고도 3·1·3·1이라는 다른 답이 하나 더 있어요.'),
      lessonH(context, '자기 자신의 글자 수를 세는 문장'),
      lessonP('문장도 자기 자신을 설명할 수 있어요. 영국의 리 샐로스는 자기 안에 알파벳이 몇 개씩 들어 있는지를 A부터 Z까지 모두 정확히 말하는 영어 문장을 만들었어요. 호프스태터가 이 문장을 소개해 유명해졌어요.'),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
        child: const Text('"$kSallowsPangram"', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.5)),
      ),
      lessonP('정말인지 알파벳을 직접 세어 본 결과예요. 문장이 말한 숫자와 하나도 어긋나지 않아요!'),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final e in letterTally(kSallowsPangram).entries)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: _accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
      lessonP('이렇게 자기 안의 글자 개수를 스스로 말하는 문장을 "오토그램(autogram)"이라고 불러요. 이 문장은 알파벳이 모두 들어 있는 오토그램이에요. 숫자를 하나라도 바꾸면, 그 숫자를 쓴 낱말 때문에 다른 글자의 개수가 달라져서 맞지 않게 돼요. 이런 문장을 찾으려면 컴퓨터로 수없이 고쳐 가며 맞춰 봐야 해요.'),
      lessonP('샐로스는 한술 더 떠서, 알파벳뿐 아니라 쉼표와 어포스트로피(’)와 하이픈과 느낌표의 개수까지 말하는 문장도 만들었어요. 문장의 뜻은 "이걸 일일이 확인하는 건 바보나 하는 짓"이래요. 그런데 우리는 바보가 되어 볼까요?'),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
        child: const Text('"$kSallowsFoolSentence"', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.5)),
      ),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final e in _foolTally().entries)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: _accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
      lessonP('쉼표 27개, 어포스트로피 23개, 하이픈 7개, 느낌표 1개까지 한 개도 틀리지 않아요. 한국어로는 훨씬 짧은 문장이 가능해요.'),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
        child: Text('"$kSelfCountingSentence"', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1.4)),
      ),
      lessonP('세어 볼까요? 이(1) 문장은(3) 공백을(3) 빼면(2) 모두(2) 열여덟(3) 글자예요(4) → 모두 ${letterCount(kSelfCountingSentence)}글자! 문장이 말한 숫자와 정확히 같아요. "열여덟"을 다른 수로 바꾸면 대부분 틀려져요.'),
      lessonKey(context, '자기 자신을 가리키는 말이나 그림이나 표를 "자기 참조"라고 해요. 재미있는 퍼즐이 되기도 하지만, 잘못 쓰면 모순이 되기도 해요. 다음 단원에서 만나요.', icon: Icons.loop_rounded),
    ];

List<Widget> _unitLiar(BuildContext context) => [
      lessonH(context, '거짓말쟁이 역설'),
      lessonP('가장 오래된 역설 가운데 하나예요. 고대 그리스 때부터 전해져 왔어요.'),
      const LiarDemo(),
      lessonP('문장이 자기 자신에 대해 "나는 거짓이야"라고 말할 때 생기는 문제예요. 이 문장은 참으로 둘 수도, 거짓으로 둘 수도 없어요.'),
      lessonH(context, '두 장의 카드'),
      lessonP('카드 앞면에는 "뒷면의 문장은 참이다", 뒷면에는 "앞면의 문장은 거짓이다"라고 적혀 있다고 해요. 두 문장이 서로를 가리키며 빙글빙글 돌아요.'),
      lessonBullets(context, [
        '앞면이 참이라고 하면 → 뒷면도 참이에요 → 그런데 뒷면은 "앞면은 거짓"이라고 말해요. 모순!',
        '앞면이 거짓이라고 하면 → 뒷면은 참이 아니라 거짓이에요 → 뒷면의 말("앞면은 거짓")이 거짓이니 앞면은 참이에요. 또 모순!',
      ]),
      lessonH(context, '불시 시험 역설 — 예언이 예언을 무너뜨려요'),
      lessonP('예언 게임과 아주 닮은 이야기예요. 선생님이 "다음 주 평일 중 하루, 불시 시험을 보겠다. 그날 아침까지는 언제인지 아무도 모를 거야"라고 말했어요. 학생들의 생각을 따라가 보세요.'),
      const ExamDemo(),
      lessonP('학생들의 추론은 "선생님의 예고가 반드시 참이다"라는 전제에서 시작해요. 그런데 추론 결과가 "예고는 불가능하다"가 되면, 학생들은 예고를 믿지 않게 되고, 그러면 어느 날 시험을 봐도 놀랄 수 있어요. 예고가 자기 자신의 참거짓을 흔드는 모양이에요. 철학자와 수학자들은 지금도 정확히 어디가 잘못인지를 두고 이야기를 나눠요.'),
      lessonKey(context, '예언 게임의 숫자도 같은 병에 걸려요. 쓰는 순간 줄의 개수가 바뀌어 자기 예언이 무너질 수 있으니까요.', icon: Icons.loop_rounded),
    ];

List<Widget> _unitHilbert(BuildContext context) => [
      lessonP('수학은 오랫동안 "틀림없는 진리의 탑"처럼 여겨졌어요. 아래 층이 튼튼하면 위 층도 튼튼하니까요. 그렇다면 맨 아래 바닥, 곧 수학의 기초는 무엇일까요?'),
      lessonArt(const MathTowerArt(), height: 290, caption: '수학의 탑: 각 층은 아래층 위에 놓여 있어요'),
      lessonH(context, '19세기: 흔들리는 바닥'),
      lessonBullets(context, [
        '유클리드 기하는 2000년 넘게 "세상에 하나뿐인 기하"로 여겨졌어요. 그런데 평행선에 대한 가정을 바꿔도 모순이 없는 새 기하(비유클리드 기하)가 19세기에 발견되었어요.',
        '칸토어는 1870년대에 "집합"으로 무한을 다루기 시작했고, 무한에도 크기가 여러 가지라는 놀라운 결과를 얻었어요.',
        '프레게 같은 논리학자들은 산수를 논리와 집합 위에 쌓으려고 했어요.',
      ]),
      lessonH(context, '힐베르트의 계획'),
      lessonP('독일의 수학자 다비트 힐베르트(1862~1943)는 1900년 국제수학자대회에서 앞으로 풀어야 할 23개의 문제를 내놓았어요. 그리고 수학 전체의 바닥을 튼튼하게 만들기 위해 세 가지를 보이자고 했어요.'),
      lessonBullets(context, [
        '완전성: 참인 수학 명제는 모두 증명할 수 있다.',
        '무모순성: 규칙(공리)에서 모순이 나오지 않는다.',
        '결정 가능성: 어떤 명제가 증명되는지 정해진 기계적인 절차로 가려낼 수 있다.',
      ]),
      lessonP('1930년 은퇴 연설에서 힐베르트는 "우리는 알아야 한다. 우리는 알게 될 것이다."라고 말했어요. 이 말은 그의 묘비에도 새겨져 있어요.'),
      lessonKey(context, '그런데 바로 그 무렵, 이 꿈에 금을 내는 일이 벌어졌어요. 하나는 집합론에서 발견된 역설(러셀), 또 하나는 같은 해 괴델이 처음 발표한 증명이에요. 뒤의 단원에서 만나요.', icon: Icons.warning_amber_rounded),
    ];

List<Widget> _unitSets(BuildContext context) => [
      lessonP('집합은 "무언가를 모아 놓은 주머니"예요. {1, 2, 3}은 1, 2, 3이 든 집합이고, 안에 든 것은 원소라고 불러요. 아무것도 안 든 주머니 { }는 공집합이에요.'),
      lessonP('주머니 속에는 주머니도 넣을 수 있어요. 놀랍게도 이것만으로 모든 자연수를 만들 수 있어요!'),
      lessonBullets(context, [
        '0 = { } (아무것도 없는 빈 주머니)',
        '1 = {0} (0이 든 주머니)',
        '2 = {0, 1}',
        '3 = {0, 1, 2} … 각 수는 자기보다 작은 수를 모두 담은 주머니예요.',
      ]),
      const VonNeumannExplorer(),
      lessonP('이 방법은 수학자 존 폰 노이만이 1920년대에 정리했어요. 이렇게 하면 "2는 3보다 작다"가 "2는 3의 원소다"라는 말이 되어서, 크기 비교까지 집합으로 설명돼요.'),
      lessonP('더하기와 곱하기, 분수와 소수, 도형과 방정식까지 이렇게 집합 위에 쌓아 올릴 수 있다는 것이 집합론의 큰 약속이었어요. 수학의 바닥을 "집합" 하나로 통일하는 꿈이었죠.'),
      lessonH(context, '무한에도 크기가 있어요'),
      lessonP('칸토어는 자연수 전체와 실수 전체는 둘 다 끝없이 많지만, 실수가 "더 많다"는 것을 보였어요(대각선 논법). 무한을 다루려면 집합이라는 도구가 꼭 필요했어요.'),
      lessonKey(context, '"모아 놓은 것 하나하나를 집합으로 본다"는 아주 단순한 생각에서 수학 전체를 쌓으려는 거예요. 그래서 이 바닥에 금이 가면 탑 전체가 흔들려요.', icon: Icons.layers_rounded),
    ];

List<Widget> _unitRussell(BuildContext context) => [
      lessonP('집합론이 막 시작되었을 때의 규칙은 아주 단순했어요. "어떤 성질이든, 그 성질을 가진 것들을 모으면 집합이 된다." 이 규칙이 수학을 크게 흔들게 돼요.'),
      lessonH(context, '자기 자신을 품는 집합?'),
      lessonP('대부분의 집합은 자기 자신을 원소로 갖지 않아요. {1, 2}에는 1과 2만 들어 있고 {1, 2} 자신은 들어 있지 않아요. 하지만 "모든 집합을 모은 집합"이 있다면, 그것도 집합이니까 자기 자신을 품게 돼요.'),
      lessonH(context, '러셀의 질문'),
      lessonP('1901년 영국의 버트런드 러셀은 이렇게 물었어요. "자기 자신을 원소로 갖지 않는 집합만 모은 집합 R을 만들면 어떻게 될까?"'),
      lessonBullets(context, [
        'R이 R을 원소로 가진다고 하면 → R은 "자기를 갖지 않는 집합"이어야 하는데, R을 가졌으니 모순!',
        'R이 R을 원소로 갖지 않는다고 하면 → R은 "자기를 갖지 않는 집합"이니 R의 원소여야 해요. 또 모순!',
      ]),
      lessonP('이 모순을 쉽게 보여 주는 이야기로 알려진 것이 "이발사의 역설"이에요.'),
      const BarberDemo(),
      lessonH(context, '두 이야기는 어디가 같고 어디가 다를까?'),
      lessonBullets(context, [
        '같은 점: 이발사 ↔ 집합 R, "스스로 깎는 사람" ↔ "자기를 원소로 갖는 집합", "스스로 깎지 않는 사람만 깎아 준다" ↔ "자기를 원소로 갖지 않는 것만 모은다".',
        '다른 점: 이발사 이야기는 "그런 이발사는 세상에 없다"고 하면 끝나요. 그런 규칙이 애초에 말이 안 되는 거예요. 하지만 집합론은 "어떤 성질이든 모으면 집합이 된다"고 약속했으니 R도 있어야만 해요! 그래서 약속(규칙) 자체를 고쳐야 했어요.',
      ]),
      lessonH(context, '수학자들의 대답'),
      lessonBullets(context, [
        '프레게는 산수를 집합으로 쌓은 책의 두 번째 권을 인쇄하던 중에 러셀의 편지를 받았다고 해요. 책의 기초가 무너진다는 것을 알게 된 그는 마지막에 이 사실을 덧붙였어요.',
        '체르멜로(1908)는 "아무 성질로나 집합을 만들 수 없고, 이미 있는 집합에서 골라낼 때만 집합이 된다"로 규칙을 바꿨어요. 여기에 프랭켈 등이 더해져 지금의 집합론(ZFC)이 되었고, 오늘날 수학 대부분이 그 위에서 이루어져요.',
        '러셀은 집합을 단계별 층으로 나누어 "자기 층을 가리키지 못하게" 하는 유형 이론을 만들었어요.',
      ]),
      lessonP('힐베르트는 "아무도 칸토어가 우리를 위해 만든 낙원에서 우리를 쫓아낼 수 없다"고 말하며 집합론을 지켜 내려 했어요.'),
      lessonKey(context, '예언 게임의 "자기 숫자 때문에 자기 예언이 무너지는" 일과 러셀의 R은 같은 모양이에요: 자기를 가리키면서 "아니다"가 끼어들어요.', icon: Icons.loop_rounded),
    ];

List<Widget> _unitMoreParadoxes(BuildContext context) => [
      lessonP('자기 자신을 가리키는 말에는 이런 함정이 많아요. 몇 가지를 더 만나 보세요. 먼저 스스로 생각해 보고 "답 보기"를 눌러요.'),
      const LessonReveal(
        title: '① 그렐링–넬슨 역설 (1908)\n\n자기 뜻에 맞는 낱말을 "자기해당어", 맞지 않는 낱말을 "비자기해당어"라고 해요. "짧다"는 두 글자라서 정말 짧아요(자기해당). "길다"는 두 글자라서 길지 않아요(비자기해당).\n그럼 "비자기해당어"라는 낱말은 비자기해당어일까요?',
        child: Text(
          '비자기해당어라고 하면, 자기 뜻("자기에게 맞지 않는 낱말")에 딱 맞으니 자기해당어가 돼요. 자기해당어라고 하면, 자기 뜻에 맞지 않으니 비자기해당어가 돼요. 어느 쪽이든 모순이에요. 러셀의 역설과 똑같은 모양이에요.',
          style: TextStyle(fontSize: 15, height: 1.55),
        ),
      ),
      LessonReveal(
        title: '② 베리의 역설\n\n"$kBerryPhrase"이라는 말은 어떤 수를 가리킬까요? 스무 글자로 표현할 수 있는 수는 한정되어 있으니, 표현할 수 없는 수가 있고 그중 가장 작은 수가 있을 거예요. 그런데…',
        child: Text(
          '방금 그 수를 설명한 이 말은 공백을 빼면 ${letterCount(kBerryPhrase)}글자예요! "스무 글자 이하로 표현할 수 없다"던 수를 ${letterCount(kBerryPhrase)}글자로 표현해 버렸어요. "표현한다"는 말을 수의 이야기 안에서 마음대로 쓸 때 생기는 모순이에요.',
          style: const TextStyle(fontSize: 15, height: 1.55),
        ),
      ),
      const LessonReveal(
        title: '③ 커리의 역설 (조금 어려워요)\n\n문장 S: "이 문장이 참이라면, 달은 치즈로 되어 있다."\nS가 참이라고 가정해 보세요.',
        child: Text(
          'S가 참이라고 가정하면, S가 말한 대로 달은 치즈예요. 그런데 "S가 참이면 달은 치즈다"가 바로 S 자신이에요. 가정에서 달이 치즈라는 결론이 나왔으니 S가 참이라는 것을 증명한 셈이에요. 그러면 정말로 달은 치즈가 돼 버려요! 자기를 가리키는 문장 하나로 아무 말이나 증명할 수 있다는, 무서운 이야기예요.',
          style: TextStyle(fontSize: 15, height: 1.55),
        ),
      ),
      lessonKey(context, '이 역설들의 공통 레시피: ① 자기 자신을 가리키고(자기 참조) ② "아니다·거짓이다·표현할 수 없다" 같은 부정이 끼어들어요. 수학자들은 이런 문장을 규칙으로 막거나 층을 나누어 피해 가는 법을 만들었어요.', icon: Icons.menu_book_rounded),
    ];

List<Widget> _unitGodel(BuildContext context) => [
      lessonH(context, '괴델의 불완전성 정리 (1931)'),
      lessonP('쿠르트 괴델(1906~1978)은 힐베르트의 꿈에 정면으로 답했어요. 먼저 놀라운 아이디어: 수학 문장과 증명도 숫자로 바꿀 수 있어요(괴델 수). 그러면 수학이 자기 자신에 대해서도 말할 수 있게 돼요. 그리고 이런 문장 G를 만들었어요.'),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
        child: const Text('G: "이 문장은 증명할 수 없다."', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
      ),
      lessonBullets(context, [
        'G를 증명할 수 있다면? G가 말한 것("증명 못 한다")이 거짓인데 그것을 증명한 셈이니, 규칙 체계가 거짓을 증명하는 모순 체계예요.',
        '그러니 모순 없는 체계에서는 G를 증명할 수 없어요. 그런데 G가 말하는 내용이 바로 "G는 증명할 수 없다"이니, G는 참이에요!',
      ]),
      lessonP('즉, 산술을 다룰 수 있을 만큼 강력하고 모순 없는 규칙 체계에는 "참이지만 증명할 수 없는 문장"이 반드시 있어요(불완전성 정리 1). 또 그런 체계는 자기 자신에 모순이 없다는 것도 스스로 증명할 수 없어요(불완전성 정리 2).'),
      lessonKey(context, '"이 문장은 거짓이다"는 참인지 거짓인지 정할 수 없었어요. 괴델은 "거짓" 대신 "증명할 수 없다"를 써서 모순 대신 "구멍"을 찾아냈어요. 영리한 방법이죠!', icon: Icons.lightbulb_rounded),
      lessonP('그렇다고 수학이 엉터리가 된 건 아니에요. 수학은 지금도 튼튼해요. 다만 힐베르트가 바란 "모든 참을 증명하는 완벽한 체계"는 (산술을 포함하는 한) 없다는 것을 알게 된 거예요.'),
      lessonH(context, '튜링과 정지 문제 (1936)'),
      lessonP('영국의 앨런 튜링(1912~1954)은 "계산이란 무엇인가"를 기계(튜링 기계)로 정의했어요. 이것이 오늘날 컴퓨터의 생각 틀이에요. 그리고 힐베르트의 세 번째 질문(결정 가능성)에도 답했어요. 모든 수학 문장의 참을 가려내는 만능 자동 기계는 없다는 거예요. 그 핵심이 "정지 문제"예요.'),
      const HaltingDemo(),
      lessonP('오늘날 어떤 프로그램이든 완벽하게 검사해 주는 "만능 버그 찾기 프로그램"을 만들 수 없는 것도 같은 이유예요.'),
      lessonKey(context, '예언 게임의 "자기를 망치는 숫자", 거짓말쟁이, 러셀의 R, 괴델의 문장, 정지 문제는 모두 "자기를 가리키는 고리"라는 같은 뿌리를 가졌어요. 호프스태터는 이것을 "이상한 고리(strange loop)"라고 불렀어요.', icon: Icons.loop_rounded),
    ];

List<Widget> _unitAxioms(BuildContext context) => [
      lessonH(context, '공리(公理)란?'),
      lessonP('공리는 증명하지 않고 "출발점으로 삼기로 약속한 문장"이에요. 규칙을 정하고 시작하는 게임과 같아요. 예를 들어 "서로 다른 두 점을 지나는 직선은 딱 하나다" 같은 것이 기하학의 공리예요. 공리들을 모아 놓은 것을 공리계라고 해요.'),
      lessonP('예언 게임의 규칙도 이 게임의 공리예요. "한 줄에 같은 숫자는 한 번만", "숫자는 1부터 가장 긴 줄의 칸 수까지" 같은 것들이죠.'),
      const LessonReveal(
        title: '"같은 숫자를 한 줄에 여러 번 써도 된다"로 규칙을 바꾸면 어떤 게임이 될까요?',
        child: Text(
          '같은 숫자가 한 줄에 여러 개 있을 수 있으니 줄이 끝났을 때 맞는 숫자가 여러 개가 될 수 있어요. 한 줄에서 점수를 여러 번 얻는 완전히 다른 게임이 돼요. 공리를 바꾸면 전혀 다른 세계가 되는 거예요.',
          style: TextStyle(fontSize: 15, height: 1.55),
        ),
      ),
      lessonP('수학에서도 마찬가지예요. 평행선에 대한 공리를 바꾸면 비유클리드 기하가 나와요. 둥근 공 표면(구면) 위의 기하에서는 삼각형 세 각의 합이 180도보다 크고, 말안장처럼 휜 면(쌍곡기하)에서는 180도보다 작아요.'),
      lessonH(context, '형식주의: 수학을 규칙 게임으로 보기'),
      lessonP('힐베르트와 동료들은 수학을 "기호와 규칙의 게임"처럼 바라보자고 했어요. 이런 생각을 형식주의라고 해요.'),
      lessonBullets(context, [
        '공리: 게임을 시작할 때 놓여 있는 기호들이에요.',
        '추론 규칙: 기호를 어떻게 바꿔도 되는지 정한 규칙이에요.',
        '증명: 공리에서 출발해 추론 규칙을 정해진 횟수만큼 적용해 얻은 기호의 줄이에요.',
      ]),
      lessonP('체스에서 말이 나무인지 플라스틱인지는 중요하지 않고, 어떻게 움직이는지만 중요하잖아요? 형식주의에서는 "점·직선·평면"이라는 낱말의 뜻을 잊고 규칙만 보아도 증명이 맞는지 가려낼 수 있어야 해요. 힐베르트는 "점, 직선, 평면 대신 탁자, 의자, 맥주잔이라고 불러도 정리가 성립해야 한다"고 말했다고 전해져요.'),
      lessonP('형식주의 덕분에 증명이 맞는지를 기계적으로 검사할 수 있게 되었고, 오늘날 컴퓨터가 증명을 검사하는 프로그램(증명 보조기)의 바탕이 되었어요. 다만 괴델이 보여 준 것처럼 이 방법에도 한계가 있어요.'),
      lessonH(context, '수학의 세 가지 입장'),
      lessonBullets(context, [
        '논리주의(러셀 등): 수학은 논리로 환원된다.',
        '직관주의(브라우어 등): 수학은 사람이 머릿속에서 구성할 수 있는 것만 인정한다.',
        '형식주의(힐베르트 등): 수학은 규칙에 따라 기호를 다루는 체계이고, 중요한 것은 모순이 없는 것이다.',
      ]),
      lessonH(context, 'ZFC 공리계'),
      lessonP('러셀의 역설을 피하기 위해 만들어진 집합론의 공리계예요. 체르멜로(Z)가 1908년에 처음 만들고, 프랭켈(F) 등이 다듬었고, 여기에 선택 공리(C, Choice)를 더한 것이 ZFC예요. 오늘날 수학 대부분이 ZFC 위에서 이루어져요. 대표적인 공리들을 쉬운 말로 볼게요.'),
      lessonBullets(context, [
        '외연 공리: 원소가 똑같은 두 집합은 같은 집합이에요.',
        '공집합 공리: 아무것도 안 든 집합이 있어요.',
        '쌍 공리: 집합 a, b가 있으면 {a, b}도 집합이에요.',
        '합집합 공리: 집합들의 모임을 하나로 합칠 수 있어요.',
        '멱집합 공리: 어떤 집합의 부분집합을 모두 모은 집합이 있어요.',
        '무한 공리: 0, 1, 2, … 를 모두 담은 무한집합(자연수 전체)이 있어요.',
        '분리 공리: 이미 있는 집합에서 어떤 성질을 가진 원소만 골라내면 그것도 집합이에요.',
        '치환 공리: 집합의 원소를 규칙에 따라 하나씩 바꿔 놓은 것도 집합이에요.',
        '정칙성 공리: 어떤 집합도 자기 자신을 원소로 가질 수 없어요.',
        '선택 공리: 비어 있지 않은 집합들이 있으면, 각 집합에서 원소를 하나씩 뽑을 수 있어요.',
      ]),
      const LessonReveal(
        title: 'ZFC에서는 러셀의 R이 왜 만들어지지 않을까요? (핵심은 분리 공리예요)',
        child: Text(
          '예전에는 "어떤 성질이든 그 성질을 가진 모든 것을 모으면 집합"이었어요. 분리 공리는 "이미 있는 집합 A에서만 골라낼 수 있다"로 바꿨어요. 그래서 R_A = {x ∈ A | x는 x를 원소로 갖지 않는다}는 집합이에요. '
          '그런데 R_A가 A의 원소라고 하면 예전처럼 모순이 나오니, R_A는 A의 원소가 아니에요. 어떤 집합 A를 가져와도 R_A는 그 밖에 있으니, 모든 집합을 담은 "집합들의 집합"은 존재할 수 없어요. 역설이 "그런 집합은 없다"로 바뀐 거예요.',
          style: TextStyle(fontSize: 15, height: 1.55),
        ),
      ),
      lessonH(context, 'ZFC도 괴델의 한계 안에 있어요'),
      lessonBullets(context, [
        'ZFC에 모순이 없다는 것은 ZFC 안에서는 증명할 수 없어요 (괴델의 불완전성 정리 2).',
        '칸토어가 던진 "연속체 가설"(자연수와 실수 사이에 크기가 중간인 무한은 없을까?)은 ZFC로 증명도 반증도 할 수 없다는 것이 밝혀졌어요. 괴델이 1940년에 반증할 수 없음을, 코언이 1963년에 증명할 수 없음을 보였어요.',
      ]),
      lessonKey(context, '공리를 정하는 일은 규칙을 정하는 일이에요. 규칙이 정해지면 그 안의 진리를 탐험하고, 규칙의 한계가 보이면 규칙을 고쳐 새 세계를 만들어요. 수학은 그렇게 자라 왔어요.', icon: Icons.rule_rounded),
    ];

List<Widget> _unitQuiz(BuildContext context) => [
      lessonP('배운 내용을 확인해 볼까요? 틀려도 괜찮아요. 해설을 읽고 다시 풀 수 있어요.'),
      LessonQuiz(
        question: '4행 5열 표에서 쓸 수 있는 가장 큰 숫자는 얼마일까요?',
        options: const ['4', '5', '8', '20'],
        answer: 1,
        explain: '쓸 수 있는 숫자는 1부터 "가장 긴 줄의 칸 수"까지예요. 한 행은 5칸, 한 열은 4칸이라 5까지 쓸 수 있어요.',
        figure: SizedBox(width: 220, height: 180, child: ProphBoardView(state: emptyBoard(), showCounts: false)),
      ),
      LessonQuiz(
        question: '같은 행에 이미 4가 있어요. 그 행의 다른 빈칸에 4를 쓸 수 있을까요?',
        options: const ['쓸 수 있어요', '쓸 수 없어요', '열이 다르면 쓸 수 있어요'],
        answer: 1,
        explain: '한 행이나 열에는 같은 숫자를 두 번 쓸 수 없어요. 같은 행이면 열이 달라도 안 돼요.',
        figure: SizedBox(width: 220, height: 180, child: ProphBoardView(state: repeatBoard(), flags: {kRepeatCell: const Color(0xFFD64545)}, showCounts: false)),
      ),
      const LessonQuiz(
        question: '5칸짜리 행이 다 채워졌어요: [2, X, 3, X, 5]. 이 행에서 점수를 얻는 숫자는 무엇일까요?',
        options: ['2', '3', '5', '아무도 없어요'],
        answer: 1,
        explain: '숫자는 2, 3, 5로 모두 3개예요. X는 세지 않아요. 3을 쓴 사람이 맞혔고 3점을 얻어요.',
      ),
      const LessonQuiz(
        question: '한 숫자가 행에서도 맞고 열에서도 맞으면 점수는 어떻게 될까요?',
        options: ['그 숫자만큼 한 번', '그 숫자만큼 두 번 (2배)', '점수가 없어요'],
        answer: 1,
        explain: '행에서 한 번, 열에서 한 번 득점해요. 그래서 5가 모두 맞으면 5 + 5 = 10점이에요.',
      ),
      const LessonQuiz(
        question: '러셀의 역설에서 R은 무엇을 모은 집합일까요?',
        options: ['모든 집합', '자기 자신을 원소로 갖지 않는 집합들', '자기 자신을 원소로 갖는 집합들', '공집합'],
        answer: 1,
        explain: 'R이 R을 원소로 가지는지 물으면 어느 쪽 답이든 모순이 나와요. 이것이 집합론의 규칙을 고치게 만들었어요.',
      ),
      const LessonQuiz(
        question: '이발사의 역설과 러셀의 역설이 결정적으로 다른 점은 무엇일까요?',
        options: [
          '이발사 이야기는 "그런 이발사는 없다"고 하면 끝나지만, 집합론은 R이 있어야 한다고 약속해서 규칙을 고쳐야 했어요',
          '이발사 이야기는 참이고 러셀의 역설은 거짓이에요',
          '두 이야기는 완전히 똑같아요',
        ],
        answer: 0,
        explain: '이발사는 상상 속 마을의 이야기라 "없다"로 끝낼 수 있어요. 하지만 집합론은 "어떤 성질이든 모으면 집합이 된다"고 했기 때문에 R을 부정할 수 없었어요.',
      ),
      const LessonQuiz(
        question: '괴델의 불완전성 정리가 말하는 것은 무엇일까요?',
        options: [
          '수학은 엉터리라는 것',
          '산술을 다루는 모순 없는 규칙 체계에는 참이지만 증명할 수 없는 문장이 있다는 것',
          '모든 수학 문장은 컴퓨터가 증명할 수 있다는 것',
        ],
        answer: 1,
        explain: '수학이 틀렸다는 뜻이 아니에요. "모든 참을 증명하는 완벽한 규칙 체계"는 불가능하다는 뜻이에요.',
      ),
      const LessonQuiz(
        question: '튜링의 정지 문제에서 심술쟁이 프로그램 D가 하는 일은 무엇일까요?',
        options: ['H의 예언과 반대로 행동해요', 'H의 예언을 그대로 따라 해요', '아무것도 안 해요'],
        answer: 0,
        explain: 'H가 "멈춘다"고 하면 영원히 돌고, "영원히 돈다"고 하면 멈춰요. 그래서 언제나 맞히는 H는 만들 수 없어요.',
      ),
      const LessonQuiz(
        question: 'ZFC 공리계에서 러셀의 역설을 피하는 핵심 규칙은 무엇일까요?',
        options: [
          '어떤 성질이든 그 성질을 가진 것을 모두 모으면 집합이에요',
          '이미 있는 집합에서 성질을 가진 원소만 골라낼 때 집합이 돼요 (분리 공리)',
          '집합은 원소를 하나만 가질 수 있어요',
        ],
        answer: 1,
        explain: '"모든 것의 모임"을 마음대로 만들 수 없게 막았어요. 그러면 자기 자신을 원소로 갖지 않는 모든 집합의 집합 R이 만들어지지 않아요.',
      ),
      const LessonQuiz(
        question: '형식주의에서 "증명"은 무엇일까요?',
        options: [
          '공리에서 출발해 추론 규칙을 정해진 횟수만큼 적용해 얻은 기호의 줄',
          '많은 사람이 믿는 주장',
          '컴퓨터가 계산한 결과',
        ],
        answer: 0,
        explain: '형식주의에서는 낱말의 뜻을 잊고 규칙만 따라 증명을 검사해요. 그래서 기계도 증명이 맞는지 확인할 수 있어요.',
      ),
      const SizedBox(height: 8),
      _playButtons(context),
    ];
