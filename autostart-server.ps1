# 로그온 시 ANA 대시보드 서버를 기동한다 (작업 "ANA Server Autostart"가 호출).
# 중요: 서버가 살아 있는 동안 이 스크립트가 끝나지 않아야 한다.
# 작업이 먼저 끝나면(결과 0) 작업 스케줄러가 자식 프로세스(node)를 함께 정리해 서버가 죽는다 (2026-10-09 사례).
# 그래서 node를 백그라운드로 띄우지 않고 포그라운드(cmd /c)로 실행해 작업이 Running을 유지하게 한다.
Set-Location -Path $PSScriptRoot
$logDir = Join-Path $PSScriptRoot "logs"
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

# 이미 서버가 떠 있으면 아무것도 하지 않는다
try { Invoke-WebRequest -Uri "http://127.0.0.1:8777/api/state" -UseBasicParsing -TimeoutSec 3 | Out-Null; exit 0 } catch {}

# 터널 트래픽에 로그인을 요구한다 (로컬 접근은 열려 있음). start-ana.bat도 같은 설정을 쓴다.
$env:ANA_REQUIRE_AUTH = "1"
cmd /c "node server.js >> logs\server.out.log 2>&1"
exit $LASTEXITCODE
