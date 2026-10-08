# ANA Starter 상태 확인 (읽기 전용: 아무것도 변경하지 않는다)
# 사용법: powershell -File .\check-status.ps1
# 점검: 서버, 단어 개수(로컬/커밋/원격), 미푸시 여부, 예약 작업, 오늘 파이프라인 결과, 최근 로그

Set-Location -Path $PSScriptRoot
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$today = Get-Date -Format "yyyy-MM-dd"
$ng = 0

function Show { param([string]$ok, [string]$label, [string]$detail)
    $color = switch ($ok) { "OK" { "Green" } "WARN" { "Yellow" } default { "Red" } }
    if ($ok -ne "OK") { $script:ng++ }
    Write-Host ("[{0,-4}] {1}: {2}" -f $ok, $label, $detail) -ForegroundColor $color
}

function Count-Words { param([string]$json)
    try { $v = $json | ConvertFrom-Json; return "$(@($v.words).Count)개 (v$($v.version))" } catch { return "읽기 실패" }
}

Write-Host "=== ANA Starter 상태 ($today $(Get-Date -Format 'HH:mm')) ===" -ForegroundColor Cyan

# 1) 서버
$localJson = $null
try {
    $localJson = (Invoke-WebRequest -Uri "http://127.0.0.1:8777/api/vocab" -UseBasicParsing -TimeoutSec 5).Content
    Show "OK" "서버" "http://localhost:8777 응답 중"
} catch { Show "FAIL" "서버" "응답 없음 (start-ana.bat 또는 node server.js 로 기동)" }

# 2) 단어 개수: 서버(또는 파일) vs 마지막 커밋 vs 원격
if (-not $localJson -and (Test-Path "data/vocab.json")) { $localJson = Get-Content "data/vocab.json" -Raw -Encoding UTF8 }
$local = if ($localJson) { Count-Words $localJson } else { "없음" }
$head = Count-Words ((git show HEAD:data/vocab.json) -join "`n")
$remote = "확인 불가"
git fetch --quiet 2>$null
if ($LASTEXITCODE -eq 0) { $remote = Count-Words ((git show origin/main:data/vocab.json) -join "`n") }
$level = if ($local -eq $remote) { "OK" } else { "WARN" }
Show $level "단어 개수" "로컬 $local / 커밋 $head / 원격 $remote"

# 3) 미푸시 여부
$dirty = git status -s data/vocab.json
$ahead = git rev-list --count origin/main..HEAD 2>$null
if ($dirty) { Show "WARN" "푸시 대기" "data/vocab.json이 커밋되지 않았습니다 (sync-deploy.ps1 실행 필요)" }
elseif ($ahead -gt 0) { Show "WARN" "푸시 대기" "푸시되지 않은 커밋 $ahead 개" }
else { Show "OK" "푸시 대기" "없음 (GitHub Pages와 동기화됨)" }
# 코드·문서 변경은 자동 커밋되지 않는다(sync-deploy.ps1은 vocab.json만). 이 PC에만 있는 변경을 경고한다
$others = @(git status -s | Where-Object { $_ -notmatch 'data/vocab\.json' })
if ($others.Count -gt 0) { Show "WARN" "미커밋 파일" ("{0}개: {1}" -f $others.Count, (($others | ForEach-Object { $_.Substring(3) }) -join ", ")) }
else { Show "OK" "미커밋 파일" "없음" }
$last = git log origin/main -1 --format='%h %ad %s' --date=format:'%m-%d %H:%M' 2>$null
Write-Host "       최근 원격 커밋: $last"

# 4) 예약 작업
Write-Host "--- 예약 작업 ---"
Get-ScheduledTask -TaskName 'ANA*' -ErrorAction SilentlyContinue | ForEach-Object {
    $i = Get-ScheduledTaskInfo $_
    $lvl = if ($i.LastTaskResult -eq 0 -or $i.LastTaskResult -eq 267011) { "OK" } else { "FAIL" }
    # 오래 Running이면 멈춘 것이다 (2026-10-09: 파이프라인이 서버 기동 단계에서 멈춤). Autostart는 서버 수명 동안 Running이 정상
    if ($_.State -eq 'Running' -and $_.TaskName -ne 'ANA Server Autostart' -and $i.LastRunTime -lt (Get-Date).AddMinutes(-30)) { $lvl = "FAIL" }
    if ($_.TaskName -eq 'ANA Server Autostart' -and $_.State -ne 'Running' -and $localJson) { $lvl = "WARN" }
    Show $lvl $_.TaskName ("상태 {0} / 마지막 {1:MM-dd HH:mm} / 결과 {2} / 다음 {3:MM-dd HH:mm}" -f $_.State, $i.LastRunTime, $i.LastTaskResult, $i.NextRunTime)
}

# 5) 오늘 파이프라인 결과
Write-Host "--- 오늘 파이프라인 ---"
$runLog = "logs/daily-vocab-run.log"
if (Test-Path $runLog) {
    $lines = @(Get-Content $runLog -Encoding UTF8 | Where-Object { $_ -like "*$today*" })
    if ($lines.Count -eq 0) { Show "WARN" "오늘 실행" "오늘자 기록 없음 (05:45 이전이거나 PC가 꺼져 있었음)" }
    elseif ($lines -match "\[ERROR\]") { Show "FAIL" "오늘 실행" (($lines -match "\[ERROR\]")[-1]) }
    elseif ($lines -match "파이프라인 완료") { Show "OK" "오늘 실행" (($lines -match "파이프라인 완료")[-1]) }
    else { Show "WARN" "오늘 실행" "시작됨, 완료 기록 없음 (진행 중이거나 중단됨)" }
} else { Show "WARN" "오늘 실행" "daily-vocab-run.log 없음 (새 파이프라인 첫 실행 전)" }

# 6) 최근 로그
foreach ($f in @("logs/daily-vocab-run.log", "logs/sync-deploy.log")) {
    if (Test-Path $f) {
        Write-Host "--- $f (최근 4줄) ---"
        Get-Content $f -Tail 4 -Encoding UTF8 | ForEach-Object { Write-Host "  $_" }
    }
}

Write-Host ""
if ($ng -eq 0) { Write-Host "결과: 이상 없음" -ForegroundColor Green } else { Write-Host "결과: 확인 필요 항목 $ng 개" -ForegroundColor Yellow }
exit 0
