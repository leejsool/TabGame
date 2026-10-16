# TabGame

안드로이드 태블릿용 게임 모음 앱 (Flutter). 혼자 놀기와 함께 놀기 게임을 한 앱에 담아요.

## 게임

| 구분 | 게임 | 상태 |
| --- | --- | --- |
| 혼자 | 스도쿠 (3단계 난이도, 메모/빠른 입력, 논리 힌트, 자동 완성) | 완성 |
| 혼자 | 프리셀 (번호 판, 풀이 힌트, 난이도) | 완성 |
| 혼자 | 직소퍼즐 (갤러리 사진/샘플 그림, 내 퍼즐 보관함) | 완성 |
| 혼자 | 솔리테어 (1장/3장 뽑기, 풀이 힌트·망한 판 알림, 자동 올리기, 번호 판) | 완성 |
| 혼자 | 지뢰찾기 (초급/중급/고급, 논리 힌트, 깃발 모드, 확대) | 완성 |
| 혼자 | 겟 컬러 (물병 색 모으기, 4~13색 5단계(매우 어려움은 엄선한 어려운 판), 누르기·끌어서 붓기, 풀이 힌트·막힘 판정, 병 더하기) | 완성 |
| 혼자 | 리듬 검사단 (박자에 맞춰 검 휘두르기: 탭·2연속·꾹 누르기·옆으로 긋기, 코스 4개 — 4코스는 큰 슬라임 보스의 공격을 위로 밀어 막는 하트 3개짜리 보스전) | 만드는 중 |
| 혼자 | 핀볼 | 준비 중 |
| 함께 | 궁극 틱택토 (2인 / CPU 3단계 / 같은 Wi‑Fi) | 완성 |
| 함께 | 고블렛 고블러스 (2인 / CPU 3단계) | 완성 |
| 함께 | 콩나물 (Sprouts: 손가락으로 곡선 긋기, 점 2~6개, 2인 / CPU 3단계 / 같은 Wi‑Fi, 힌트, 교과학습(위상수학)) | 완성 |
| 함께 | 민들레 (5×5 초원, 꽃 심기 vs 바람 불기, 2인 / CPU 3단계 / 같은 Wi‑Fi, 튜토리얼, 교과학습(공간과 시간)) | 완성 |
| 함께 | 예언 (4×4~8×8 표에 숫자·X 쓰기, 표 크기 직접 고르기, 2인 / CPU 3단계 / 같은 Wi‑Fi, 튜토리얼, 교과학습(자기 참조·집합론·러셀·괴델·튜링·ZFC)) | 완성 |

**같은 Wi‑Fi로 함께 하기**: 예언·궁극 틱택토·콩나물·민들레는 같은 공유기에 연결된 두 기기끼리 겨룰 수 있어요 (인터넷·서버 필요 없음). 한 기기에서 "방 만들기", 다른 기기에서 "방 찾기"를 눌러요. 방 이름은 설정의 **내 별명**(처음에 "빨간 토끼"처럼 저절로 지어져요)이고, 방이 안 보이면 방 번호(주소 끝 숫자)나 주소를 직접 입력해요. 연결 코드는 `lib/net/`, 공통 화면은 `lib/net/lan_screens.dart`예요. 학교 공유기가 기기끼리의 연결을 막으면(클라이언트 격리) 안 돼요 — 이때는 한 기기의 핫스팟에 모두 연결하세요.

게임마다 **게임 방법 안내(튜토리얼)** 가 있어요. 게임을 처음 열면 한 번 자동으로 뜨고(언제든 건너뛸 수 있어요), 각 게임 첫 화면(난이도 고르는 곳)의 **튜토리얼 보기** 버튼으로 언제든 다시 볼 수 있어요. 설정에서 자동 안내를 끄거나 "다시 받기"로 되돌릴 수 있어요. 스도쿠는 진짜 판 위에서 직접 해 보는 기본 규칙 튜토리얼과, 원할 때 하나씩 연습하는 **심화 기술 연습**(싱글·포인팅·페어·X-윙 …)이 따로 있어요.

게임마다 기록 보드(전적/최고 기록)가 있고, 스도쿠·프리셀·솔리테어·직소퍼즐은 했던 판을 다시 플레이할 수 있어요 (지뢰찾기·겟 컬러는 난이도별 최고 기록).

## 개발

```
flutter pub get
flutter test
flutter build apk --release
```

구조: `lib/core`(공통), `lib/hub`(첫 화면), `lib/records`(기록), `lib/tutorial`(게임 방법 안내의 공통 틀), `lib/versus`(대결 게임 공통: CPU 생각 관리·설정 화면 틀), `lib/games/<게임>/{core,game,ui,data,tutorial}`.
규칙 엔진은 순수 Dart로 분리되어 있어 화면 없이 테스트돼요.

### 이 컴퓨터에서 테스트·빌드할 때 (한글 사용자 폴더)

사용자 폴더 이름이 한글이라 그대로 두면 `flutter_tester`가 죽고 안드로이드 네이티브(jni) 빌드도 실패해요. 임시 폴더와 패키지 캐시를 영문 경로로 돌려야 해요.
아래 스크립트가 대신 해 주니 되도록 이걸 쓰세요.

```
powershell -ExecutionPolicy Bypass -File tool/test.ps1          # 빠른 테스트 (느린 것 제외, 약 1분 반)
powershell -ExecutionPolicy Bypass -File tool/test.ps1 -All     # 전부 (릴리즈 전, 약 4~5분)
powershell -ExecutionPolicy Bypass -File tool/build_dev.ps1     # 개발용 앱을 만들어 태블릿에 설치
```

직접 돌릴 때는 `TEMP`/`TMP`를 `C:\ftmp`로, `PUB_CACHE`를 `C:\pubcache`로 바꾼 뒤 실행해요.
CPU끼리 겨루는 AI 검사처럼 오래 걸리는 테스트에는 `tags: 'slow'`를 붙여요 (`dart_test.yaml`). 빠른 확인은 `flutter test --exclude-tags slow`.

### 새 게임 추가 체크리스트

1. `lib/games/<게임>/`을 만든다: `core`(규칙, 순수 Dart) → `game`(컨트롤러) → `ui` → `data`(저장). 화면을 여는 `<게임>_entry.dart`에 `Widget build<게임>(BuildContext, PlayMode)`를 둔다.
2. `lib/core/game_registry.dart`의 `allGames`에 `GameInfo` 항목 하나를 더한다. 허브 카드, 모드 고르기, 기록 화면은 여기서 모두 이어진다.
   - `builder`(게임 화면), `tutorial`(게임 방법 안내 — 처음 열 때 자동으로 뜬다)
   - `iconPainter`(`lib/hub/game_icons.dart`에 `paint<게임>Icon`을 그려 연결) 또는 `iconImage`
   - `recordsTab`(기록 보드) — 게임 안에서는 `openRecords(context, game: id)`로 연다. 기록을 안 남기는 게임이면 `test/records/registry_test.dart`의 "준비된 게임은 모두 기록 보드를 가진다"에서 빼야 한다.
3. 기록 저장은 `JsonHistoryStore`(`lib/core/json_history.dart`)에 맡긴다: 기록 클래스에 `toJson`/`fromJson`만 있으면 읽기·쓰기·깨진 데이터 처리·개수 제한이 된다 (예: `UtttHistory`).
4. **대결 게임(CPU와 / 둘이서)** 이면 공통 틀을 쓴다:
   - 컨트롤러: `CpuTurnRunner`(`lib/versus/cpu_turn.dart`) — CPU 계산을 isolate에서 돌리고, 새 판·되돌리기·기권 때 낡은 결과를 버린다. `thinking`/`cancel()`/`dispose()` 사용법은 파일 맨 위 설명 참고.
   - 설정 화면: `VsSetupScaffold` + `VsChoiceCard` + `VsLevelPicker`(`lib/versus/vs_setup.dart`).
   - 기록 보드: `VsRecordsBoard`(`lib/records/vs_records.dart`) — 기록 한 개를 `VsTile`로 바꾸는 함수만 쓰면 된다.
5. 테스트: 규칙은 화면 없이 `test/<게임>/`에. 오래 걸리면 `tags: 'slow'`. 등록이 빠짐없이 됐는지는 `test/game_icon_test.dart`, `test/records/registry_test.dart`가 확인한다.

## 업데이트 (안드로이드)

앱을 켜면(6시간에 한 번) GitHub 최신 릴리즈를 확인하고, 새 버전이 있으면 알려 줘요. "업데이트"를 누르면 APK를 내려받아(진행률 표시, SHA-256 검증) 안드로이드 설치 화면을 열어요. 설정 화면에서 자동 확인을 끄거나 "지금 업데이트 확인"으로 바로 확인할 수 있어요.

새 버전을 내보내는 방법:

1. `pubspec.yaml`의 `version`을 올려요 (예: `1.0.1+2`). 앱은 이 버전과 릴리즈 태그를 비교해요.
2. 릴리즈 키로 서명해서 빌드해요: `flutter build apk --release`. 서명 키가 이전 버전과 다르면 설치가 거부돼요.
3. 태그(`v1.0.1`)로 GitHub 릴리즈를 만들고 APK(`.apk`)를 자산으로 올려요. (시험판·초안은 무시돼요)

```
gh release create v1.0.1 build/app/outputs/flutter-apk/app-release.apk#TabGame-1.0.1.apk --title "TabGame 1.0.1" --notes "바뀐 점"
```

릴리즈 본문이 업데이트 안내 창에 그대로 보여요. 처음 설치할 때 "이 앱에서 설치 허용"을 한 번 켜야 해요.

