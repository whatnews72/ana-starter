# Starts the ANA "brain" (claude --background --channels fakechat) on a project-
# dedicated port, retrying a few times since the fakechat channel plugin is
# experimental and its background-mode connection sometimes silently fails.
# Also clears any stale/orphaned process squatting on our dedicated port first,
# so this project never fights another Claude session over the default 8787 port.

$ErrorActionPreference = "SilentlyContinue"
# Without this, capturing claude.cmd's UTF-8 output (paths with Korean chars
# in "cwd") gets mangled by the console's default codepage, which can corrupt
# the JSON badly enough that ConvertFrom-Json throws (breaks session cleanup).
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null
$Port = 8798
$ClaudeCmd = "$env:APPDATA\npm\claude.cmd"
$LogFile = Join-Path $PSScriptRoot "logs\claude_start.log"
$MaxAttempts = 4
$WaitSeconds = 4

function Get-ListenPid($port) {
  (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty OwningProcess)
}
function Get-AnaBackgroundIds() {
  try {
    $j = & $ClaudeCmd agents --json 2>$null | Out-String | ConvertFrom-Json -ErrorAction SilentlyContinue
    return @($j | Where-Object { $_.kind -eq "background" -and $_.cwd -and ($_.cwd -like "*ana-starter*") } | ForEach-Object { $_.id })
  } catch { return @() }
}

# 0) Stop every background session already tied to this project (regardless of
# whether earlier retry attempts were cleaned up correctly) so they never pile
# up across repeated start-ana.bat runs.
try {
  $agentsJson = & $ClaudeCmd agents --json 2>$null | Out-String
  $agents = $agentsJson | ConvertFrom-Json -ErrorAction SilentlyContinue
  foreach ($a in $agents) {
    if ($a.kind -eq "background" -and $a.cwd -and ($a.cwd -like "*ana-starter*")) {
      Write-Host "Stopping stale background session $($a.id)..."
      & $ClaudeCmd stop $a.id 2>&1 | Out-Null
    }
  }
} catch {}

# 1) Clear any stale process already on our dedicated port (safe: this port is project-only).
$stalePid = Get-ListenPid $Port
if ($stalePid) {
  Write-Host "Clearing stale process on port $Port (pid $stalePid)..."
  Stop-Process -Id $stalePid -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 1
}

$env:FAKECHAT_PORT = "$Port"

for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
  Write-Host "Starting Claude background session (attempt $attempt/$MaxAttempts, channel port $Port)..."
  $before = Get-AnaBackgroundIds
  $output = & $ClaudeCmd --background --permission-mode bypassPermissions --channels plugin:fakechat@claude-plugins-official 2>&1
  $output | Out-File -FilePath $LogFile -Encoding utf8 -Append

  $bound = $false
  for ($i = 0; $i -lt $WaitSeconds; $i++) {
    Start-Sleep -Seconds 1
    if (Get-ListenPid $Port) { $bound = $true; break }
  }

  # Identify the session this attempt just created by diffing the agent list
  # (more reliable than regex-parsing console text, which can get mangled by
  # console codepage/encoding and silently fail to match).
  $after = Get-AnaBackgroundIds
  $newIds = @($after | Where-Object { $before -notcontains $_ })
  $sessionId = if ($newIds.Count -gt 0) { $newIds[0] } else { $null }

  if ($bound) {
    Write-Host "[OK] fakechat channel connected on port $Port (session $sessionId)."
    exit 0
  }

  Write-Host "[retry] Channel did not bind this attempt."
  if ($sessionId) { & $ClaudeCmd stop $sessionId 2>&1 | Out-Null }
}

Write-Host "[FAIL] Could not establish fakechat channel after $MaxAttempts attempts."
Write-Host "       Dashboard chat will not get automatic replies until this connects."
Write-Host "       You can keep using the app; try re-running start-ana.bat, or ask Claude to retry."
exit 1
