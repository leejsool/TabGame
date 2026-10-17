# 개발용 앱을 만들어 연결된 태블릿에 설치한다 (릴리즈 앱과 나란히 설치되는 별개의 앱).
#   - 앱 ID: com.tabgame.tabgame.dev, 이름 "tabgame 개발", 아이콘에 '개발' 띠
#   - 릴리즈 키 대신 디버그 키로 서명, 릴리즈 업데이트 안내는 꺼짐
# 사용: powershell -File tool/build_dev.ps1 [-NoInstall]
param([switch]$NoInstall)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

# 한글 사용자 폴더 때문에 flutter_tester 가 죽는 일을 피한다 (테스트용 설정과 동일)
New-Item -ItemType Directory -Force F:\MyApp\tools\tmp | Out-Null
$env:TEMP = 'F:\MyApp\tools\tmp'; $env:TMP = 'F:\MyApp\tools\tmp'
# 안드로이드 네이티브(jni) 빌드도 한글 경로를 못 읽으니, 패키지 캐시를 영문 경로로 쓴다 (개발 도구는 모두 F:\MyApp\tools)
$env:PUB_CACHE = 'F:\MyApp\tools\pub-cache'
$env:TABGAME_DEV = '1'

flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
flutter build apk --release --dart-define=TABGAME_DEV=true
if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }

New-Item -ItemType Directory -Force build\dev | Out-Null
$apk = 'build\dev\TabGame-dev.apk'
Copy-Item build\app\outputs\flutter-apk\app-release.apk $apk -Force
Write-Host "만들었어요: $((Resolve-Path $apk).Path)"

if (-not $NoInstall) {
  $sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { 'F:\MyApp\tools\sdk' }
  $adb = Join-Path $sdk 'platform-tools\adb.exe'
  & $adb install -r $apk
}
