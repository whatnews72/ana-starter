# 일일 영단어 파이프라인: 단어 추가(검증/재시도) -> GitHub Pages 동기화(재시도) -> 복습 푸시 알림
# 예약 작업 "ANA Daily Paper Vocab"(daily-paper-vocab.bat)이 호출한다. 순서가 코드로 보장된다.
# 어느 단계든 실패하면 로그에 남기고 웹푸시로 실패 알림을 보낸다.
# 로그: logs\daily-vocab-run.log (UTF-8)

Set-Location -Path $PSScriptRoot

$logDir = Join-Path $PSScriptRoot "logs"
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir "daily-vocab-run.log"
$base = "http://127.0.0.1:8777"
$maxAddAttempts = 3
$maxSyncAttempts = 2

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
cmd /c "`"$PSScriptRoot\ensure-server.bat`"" | Out-Null
if ($LASTEXITCODE -ne 0) { Fail-Run "서버를 시작하지 못해 단어 추가를 중단했습니다 (logs\server.log 확인)" }

# 2) 단어 추가 (헤드리스 Claude) - 단어장 개수가 늘었는지로 성공을 검증하고, 실패하면 재시도
$before = Get-VocabCount
if ($before -lt 0) { Fail-Run "단어장(/api/vocab)을 읽지 못했습니다" }
$claude = Join-Path $env:APPDATA "npm\claude.cmd"
$prompt = Join-Path $PSScriptRoot "daily-paper-vocab-prompt.txt"
$paperLog = Join-Path $logDir "daily-paper-vocab.log"
$added = 0
for ($i = 1; $i -le $maxAddAttempts -and $added -le 0; $i++) {
    Log-Message "단어 추가 시도 $i/$maxAddAttempts (현재 $before 개)"
    cmd /c "`"$claude`" -p --permission-mode bypassPermissions --effort high < `"$prompt`" >> `"$paperLog`" 2>&1"
    $after = Get-VocabCount
    if ($after -ge 0) { $added = $after - $before }
    Log-Message "추가된 단어: $added 개 (claude exit $LASTEXITCODE)"
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
