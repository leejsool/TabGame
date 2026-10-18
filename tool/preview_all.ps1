# 앱 화면을 한 번에 그림(PNG)으로 찍는다: 허브·설정·기록, 모든 게임의 첫 화면과 게임 화면을
# 폰(400x860) · 태블릿 세로(800x1280) · 태블릿 가로(1280x800)로, 세 크기를 나란히 붙인 <이름>_all.png 도 만든다.
#   powershell -ExecutionPolicy Bypass -File tool/preview_all.ps1                      전부 (약 1분)
#   powershell -ExecutionPolicy Bypass -File tool/preview_all.ps1 -Name "game (sudoku|mines)$"   이름이 맞는 것만
#   powershell -ExecutionPolicy Bypass -File tool/preview_all.ps1 -Out F:\somewhere      저장할 폴더 (기본: build\preview)
param([string]$Name, [string]$Out)

Set-Location (Split-Path $PSScriptRoot -Parent)
if (-not $Out) { $Out = Join-Path (Get-Location) 'build\preview' }
New-Item -ItemType Directory -Force $Out | Out-Null
$env:PREVIEW_DIR = $Out

$testArgs = @('test/preview_all_test.dart')
if ($Name) { $testArgs += @('--name', $Name) }
& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'test.ps1') @testArgs
$code = $LASTEXITCODE
Write-Host "Images: $Out"  # (BOM 없는 스크립트라 PowerShell 5.1이 한글을 깨뜨려서 영어로 쓴다)
exit $code
