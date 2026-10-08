# 일일 영단어 파이프라인: 단어 추가(검증/재시도) -> GitHub Pages 동기화(재시도) -> 복습 푸시 알림
# 예약 작업 "ANA Daily Paper Vocab"(daily-paper-vocab.bat)이 호출한다. 순서가 코드로 보장된다.
# 어느 단계든 실패하면 로그에 남기고 웹푸시로 실패 알림을 보낸다.
# 로그: logs\daily-vocab-run.log (UTF-8)

param([switch]$SkipAdd)  # 시험용: 서버 확인/기동까지만 하고 단어 추가 단계 전에 종료

Set-Location -Path $PSScriptRoot

$logDir = Join-Path $PSScriptRoot "logs"
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir "daily-vocab-run.log"
$base = "http://127.0.0.1:8777"
$maxAddAttempts = 3
$maxSyncAttempts = 2
$claudeTimeoutSec = 900

function Log-Message {
    param([string]$msg, [string]$level = "INFO")
    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$level] $msg"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry -Encoding UTF8
}

function Get-VocabCount {
    try { return @((Invoke-RestMethod -Uri "$base/api/vocab" -TimeoutSec 15).words).Count } catch { return -1 }
}

# 웹푸시로 알림 전송 (서버가 꺼져 있으면 로그만 남는다)
function Send-Alert {
    param([string]$title, [string]$body)
    try {
        $json = @{ title = $title; body = $body; tag = "vocab-alert" } | ConvertTo-Json -Compress
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        Invoke-RestMethod -Uri "$base/api/push" -Method Post -ContentType "application/json; charset=utf-8" -Body $bytes -TimeoutSec 15 | Out-Null
    } catch { Log-Message "알림 전송 실패: $_" "WARN" }
}

function Fail-Run {
    param([string]$reason)
    Log-Message $reason "ERROR"
    Send-Alert "영단어 자동화 실패" $reason
    exit 1
}

Log-Message "일일 영단어 파이프라인 시작"

# 1) 서버 확인/기동
# 주의: ensure-server.bat을 "| Out-Null"로 호출하면, 서버(node)가 파이프 핸들을 물려받아
# 서버가 살아 있는 동안 파이프가 안 닫혀 스크립트가 영원히 멈춘다 (2026-10-09 사례).
# 그래서 PowerShell에서 직접 서버를 띄우고(핸들 비상속), 응답할 때까지 최대 30초 기다린다.
function Test-Server {
    try { Invoke-WebRequest -Uri "$base/api/state" -UseBasicParsing -TimeoutSec 3 | Out-Null; return $true } catch { return $false }
}
if (-not (Test-Server)) {
    Log-Message "서버가 응답하지 않아 기동합니다" "WARN"
    $env:ANA_REQUIRE_AUTH = "1"
    Start-Process -FilePath "node" -ArgumentList "server.js" -WorkingDirectory $PSScriptRoot -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $logDir "server.pipeline.out.log") -RedirectStandardError (Join-Path $logDir "server.pipeline.err.log")
    for ($w = 0; $w -lt 30 -and -not (Test-Server); $w++) { Start-Sleep -Seconds 1 }
    if (-not (Test-Server)) { Fail-Run "서버를 시작하지 못해 단어 추가를 중단했습니다 (logs\server.pipeline.err.log 확인)" }
    Log-Message "서버 기동 완료"
}

# 2) 단어 추가 (헤드리스 Claude) - 단어장 개수가 늘었는지로 성공을 검증하고, 실패하면 재시도
$before = Get-VocabCount
if ($before -lt 0) { Fail-Run "단어장(/api/vocab)을 읽지 못했습니다" }
$claude = Join-Path $env:APPDATA "npm\claude.cmd"
$prompt = Join-Path $PSScriptRoot "daily-paper-vocab-prompt.txt"
$paperLog = Join-Path $logDir "daily-paper-vocab.log"
$added = 0
for ($i = 1; $i -le $maxAddAttempts -and $added -le 0; $i++) {
    Log-Message "단어 추가 시도 $i/$maxAddAttempts (현재 $before 개)"
    if ($SkipAdd) { Log-Message "SkipAdd: 단어 추가 단계를 건너뜁니다 (시험 실행)" "WARN"; exit 0 }
    # 15분 안에 안 끝나면 claude를 종료하고 다음 시도로 넘어간다 (멈춤이 작업 전체를 막지 않게)
    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"`"$claude`" -p --permission-mode bypassPermissions --effort high < `"$prompt`" >> `"$paperLog`" 2>&1`"" -WindowStyle Hidden -PassThru
    if (-not $proc.WaitForExit($claudeTimeoutSec * 1000)) {
        Log-Message "claude가 $claudeTimeoutSec 초 안에 끝나지 않아 종료합니다" "WARN"
        & taskkill /PID $proc.Id /T /F | Out-Null
        $exitCode = "timeout"
    } else { $exitCode = $proc.ExitCode }
    $after = Get-VocabCount
    if ($after -ge 0) { $added = $after - $before }
    Log-Message "추가된 단어: $added 개 (claude exit $exitCode)"
}
if ($added -le 0) { Fail-Run "단어 추가 $maxAddAttempts 회 모두 실패 (추가 0개). logs\daily-paper-vocab.log 확인" }
if ($added -lt 10) { Log-Message "10개 미만($added 개)만 추가되었습니다" "WARN" }

# 3) GitHub Pages 동기화 (실패 시 재시도). sync-deploy.ps1은 실패하면 exit 1
$synced = $false
for ($i = 1; $i -le $maxSyncAttempts -and -not $synced; $i++) {
    Log-Message "GitHub 동기화 시도 $i/$maxSyncAttempts"
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "sync-deploy.ps1")
    if ($LASTEXITCODE -eq 0) { $synced = $true } else { Start-Sleep -Seconds 30 }
}
if (-not $synced) { Fail-Run "GitHub 푸시 실패 ($added 개 단어가 로컬에만 있음). logs\sync-deploy.log 확인" }

# 4) 복습 푸시 알림 (단어 추가/동기화가 끝난 뒤에 보낸다)
try {
    $r = Invoke-RestMethod -Uri "$base/api/vocab/push-today" -Method Post -TimeoutSec 15
    Log-Message "복습 알림 전송: due $($r.due), subs $($r.subs)"
} catch { Log-Message "복습 알림 전송 실패: $_" "WARN" }

Log-Message "일일 영단어 파이프라인 완료 (추가 $added 개)"
exit 0
