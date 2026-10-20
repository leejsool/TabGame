# 도트 캐논 기본 그림 만들기

`stages.json`에 적은 순서대로 기본 그림이 이어지고, 앞 그림을 깨야 다음 그림이 열립니다.
(쉬운 것부터 어려운 순서로 적으세요.)

```json
[
  {"file": "mona_lisa.jpg", "name": "모나리자", "size": 48, "colors": 10, "capacity": 4}
]
```

| 키 | 뜻 | 기본값 |
|---|---|---|
| `file` | 이 폴더 안의 그림 파일 | (필수) |
| `name` | 메뉴에 보이는 이름 | (필수) |
| `size` | 긴 쪽 도트 칸 수 (16~64) | 32 |
| `colors` | 쓸 색 수 (2~12) | 8 |
| `capacity` | 벨트 자리 (3 어렵게 ~ 5 쉽게). 풀리는 배치가 없으면 자동으로 늘어남 | 4 |
| `enhance` | 모양 또렷하게 | true |
| `exact` | 이미 도트 아트인 그림을 칸 그대로 읽기 (`tool/prepare_dot_sprites.py`로 1칸 = 1점인 PNG를 먼저 만든다) | false |
| `scale` | `exact`일 때 한 칸을 scale×scale 칸으로 키우기 | 1 |
| `removeBg` | 배경색 지우기 | false |
| `saturation`, `edge` | 선명하게 하는 정도, 윤곽 살리는 정도 (`enhance`가 켜져 있을 때) | 1.35, 0.8 |
| `crop` | 그림의 일부만 쓰기: `[왼쪽, 위, 너비, 높이]` (0~1 비율) | 전체 |
| `landTint` | 회색빛으로 바랜 칸을 `[r, g, b]` 쪽으로 물들이기 (지구의 육지를 초록으로) | 없음 |
| `merge` | 애매한 색 합치기: `[["앞 색", "뒤 색"], ...]` (`RRGGBB`, 앞 색 칸이 뒤 색이 된다. 차례대로 적용). 아래 색 합치기 도구로 고르면 저절로 적힌다 | 없음 |

만들기:

```
flutter test tool/make_dot_stages.dart
```

`lib/games/dotcannon/core/dot_stage_data.dart`가 다시 만들어집니다. 풀리지 않는 그림은 만들다가 멈춥니다.

### 색 합치기 도구

```
python tool/dot_stage_editor.py
```

브라우저에서 http://localhost:8765 을 열면 그림마다 색 목록과 "비슷한 색 짝"이 보입니다.
색 하나를 누르고 합칠 색을 누르면(그림의 점을 눌러도 된다) 바로 미리 보이고,
"저장하고 그림 다시 만들기"를 누르면 `stages.json`에 `merge`가 적히고 위 명령이 돌아가 게임 그림이 바뀝니다 (1~2분).
"모두 지우고 다시 만들기"는 그 그림의 합치기를 지우고 원래 색으로 되돌립니다.

**저작권:** 그림 파일은 저작권이 풀린(공유 저작물·퍼블릭 도메인·CC0) 것이나 직접 만든 것만 넣으세요.
출처와 라이선스는 아래에 적어 둡니다.

## 출처

모두 위키미디어 커먼즈(commons.wikimedia.org)에서 폭 600으로 내려받은 것입니다.
옛 그림은 저작권 보호 기간이 지난 공유 저작물이고, 지구 사진은 NASA 공개 사진(미국 정부 저작물)입니다.

| 파일 | 작품 | 파일 이름(커먼즈) |
|---|---|---|
| `earth_blue.jpg` | 아폴로 17호가 찍은 지구 (NASA, 색을 다듬은 판) | The_Blue_Marble_(remastered).jpg |
| `great_wave.jpg` | 가쓰시카 호쿠사이, 가나가와 해변의 큰 파도 | Tsunami_by_hokusai_19th_century.jpg |
| `sunflowers.jpg` | 빈센트 반 고흐, 해바라기 | Vincent_Willem_van_Gogh_127.jpg |
| `scream.jpg` | 에드바르 뭉크, 절규 | The_Scream.jpg |
| `kiss.jpg` | 구스타프 클림트, 키스 | The_Kiss_-_Gustav_Klimt_-_Google_Cultural_Institute.jpg |
| `pearl_earring.jpg` | 요하네스 페르메이르, 진주 귀걸이를 한 소녀 | 1665_Girl_with_a_Pearl_Earring.jpg |
| `starry_night.jpg` | 빈센트 반 고흐, 별이 빛나는 밤 | Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg |
| `van_gogh_self.jpg` | 빈센트 반 고흐, 자화상 (1887) | Vincent_van_Gogh_-_Self-Portrait_-_Google_Art_Project_(454045).jpg |
| `mona_lisa.jpg` | 레오나르도 다 빈치, 모나리자 | Mona_Lisa,_by_Leonardo_da_Vinci,_from_C2RMF_retouched.jpg |
| `iron_man.png` | **마블 캐릭터(저작권 있음)** — 출처 미상의 도트 그림. 스토어에 올리는 앱에는 넣지 마세요 | (사용자가 준 파일) |

### 저작권이 있는 그림 (개인 시험용)

아래는 사용자가 준 캐릭터 도트 그림입니다. 모두 회사의 저작물·상표라서 **스토어에 올리는 앱에는 넣지 마세요.**
(`tool/dot_stage_art/src/`에 원본, 같은 폴더의 `mario.png` 등에 칸 그대로 되돌린 그림이 있습니다.)

| 파일 | 그림 |
|---|---|
| `mario.png`, `mario_face.png` | 마리오 (닌텐도) |
| `bowser.png` | 쿠파 (닌텐도) |
| `charmander.png`, `pikachu.png` | 파이리, 피카츄 (포켓몬) |
| `dragon.png` | 푸른 용 (출처 미상) |
| `iron_man.png` | 아이언맨 (마블) |
