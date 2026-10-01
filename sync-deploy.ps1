# GitHub Pages 배포 동기화 스크립트 (일일 실행)
# 사용법:
#   - 수동: .\sync-deploy.ps1
#   - 스케줄: Windows Task Scheduler "ANA Vocab Git Sync" (매일 05:50, 로컬 시간)
#   - 로그: logs\sync-deploy.log

# 작업 스케줄러는 cwd가 System32이므로 스크립트 위치로 반드시 이동한다
Set-Location -Path $PSScriptRoot

$logDir = Join-Path $PSScriptRoot "logs"
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir "sync-deploy.log"

function Log-Message {
    param([string]$msg, [string]$level = "INFO")
    $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$level] $msg"
    Write-Host $logEntry
    # PowerShell 5.1의 Add-Content 기본 인코딩(ANSI)이 한글을 깨뜨리므로 UTF-8 지정
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
}

Log-Message "단어장 배포 동기화 시작"

if (!(Test-Path "data/vocab.json")) {
    Log-Message "data/vocab.json을 찾을 수 없습니다. (cwd: $(Get-Location))" "ERROR"
    exit 1
}

# 변경 사항이 있는지 확인
$status = git status -s data/vocab.json
if ([string]::IsNullOrWhiteSpace($status)) {
    Log-Message "data/vocab.json에 변경 사항이 없습니다. 스킵합니다." "SKIP"
    exit 0
}

# git 네이티브 명령은 예외를 던지지 않으므로 종료 코드를 직접 검사한다
function Invoke-Git {
    param([string[]]$GitArgs)
    $out = & git @GitArgs 2>&1 | Out-String
    if ($out.Trim()) { Log-Message ($out.Trim()) }
    if ($LASTEXITCODE -ne 0) {
        Log-Message "git $($GitArgs -join ' ') 실패 (exit $LASTEXITCODE)" "ERROR"
        exit 1
    }
}

Invoke-Git @("add", "data/vocab.json")
Log-Message "data/vocab.json 스테이징 완료"

$date = Get-Date -Format "yyyy-MM-dd"
Invoke-Git @("commit", "-m", "data: daily vocab sync ($date)", "--", "data/vocab.json")
Log-Message "커밋 완료: data/vocab.json ($date)"

# 다른 곳(GitHub 웹 등)에서 올라간 커밋이 있어도 push가 거부되지 않도록 먼저 rebase
Invoke-Git @("pull", "--rebase", "--autostash")
Invoke-Git @("push")
Log-Message "원격 저장소 푸시 완료. 배포됨: https://whatnews72.github.io/ana-starter/"
