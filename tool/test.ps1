# 테스트를 돌린다. 한글 사용자 폴더 때문에 flutter_tester 가 죽는 일을 피하려고 임시 폴더를 영문 경로로 바꾼다.
#   powershell -ExecutionPolicy Bypass -File tool/test.ps1            빠른 것만 (느린 테스트 제외, 평소 개발 중에)
#   powershell -ExecutionPolicy Bypass -File tool/test.ps1 -All       전부 (릴리즈 전)
#   powershell -ExecutionPolicy Bypass -File tool/test.ps1 test/uttt  특정 폴더·파일만 (-All 없이 쓰면 느린 것은 빠짐)
param([switch]$All, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Paths)

Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force F:\MyApp\tools\tmp | Out-Null
$env:TEMP = 'F:\MyApp\tools\tmp'; $env:TMP = 'F:\MyApp\tools\tmp'

$testArgs = @('test')
if (-not $All) { $testArgs += @('--exclude-tags', 'slow') }
if ($Paths) { $testArgs += $Paths }
& flutter @testArgs
exit $LASTEXITCODE
