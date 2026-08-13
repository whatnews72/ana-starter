# Starts a Cloudflare quick tunnel for the ANA dashboard so it's reachable
# from outside the home Wi-Fi (LTE etc). The public URL changes every time
# this restarts (free "quick tunnel", no Cloudflare account needed).

$ErrorActionPreference = "SilentlyContinue"
$LogFile = Join-Path $PSScriptRoot "logs\tunnel.log"
if (Test-Path $LogFile) { Remove-Item $LogFile -Force }

$cf = Get-Command cloudflared -ErrorAction SilentlyContinue
if (-not $cf) {
  $candidate = "C:\Program Files (x86)\cloudflared\cloudflared.exe"
  if (Test-Path $candidate) { $cf = $candidate } else { $candidate = "C:\Program Files\cloudflared\cloudflared.exe"; if (Test-Path $candidate) { $cf = $candidate } }
}
if (-not $cf) {
  Write-Host "[FAIL] cloudflared.exe not found. Install it with: winget install --id Cloudflare.cloudflared"
  exit 1
}

Start-Process -FilePath $cf -ArgumentList "tunnel","--url","http://localhost:8777" `
  -RedirectStandardOutput $LogFile -RedirectStandardError "$LogFile.err" -WindowStyle Hidden

$url = $null
for ($i = 0; $i -lt 20; $i++) {
  Start-Sleep -Seconds 1
  $content = ""
  if (Test-Path $LogFile) { $content += Get-Content $LogFile -Raw }
  if (Test-Path "$LogFile.err") { $content += Get-Content "$LogFile.err" -Raw }
  $m = [regex]::Match($content, "https://[a-z0-9-]+\.trycloudflare\.com")
  if ($m.Success) { $url = $m.Value; break }
}

if ($url) {
  Write-Host "[OK] External URL: $url"
  Set-Content -Path (Join-Path $PSScriptRoot "logs\tunnel-url.txt") -Value $url -Encoding ascii
  try { Set-Clipboard -Value $url; Write-Host "(clipboard: this URL was copied — paste it anywhere, e.g. a message to your phone)" } catch {}
  try {
    # Runs show-tunnel-popup.ps1 as its own detached process (via -File, not
    # inline -Command text) so this script doesn't block waiting for the
    # popup to be dismissed, AND so the Korean message text is read from a
    # UTF-8 file instead of being passed through a command-line argument
    # (which was getting mangled by the console's codepage).
    Start-Process powershell -ArgumentList "-NoProfile","-WindowStyle","Hidden","-ExecutionPolicy","Bypass","-File","`"$(Join-Path $PSScriptRoot 'show-tunnel-popup.ps1')`""
  } catch {}
} else {
  Write-Host "[FAIL] Could not get tunnel URL in time. Check logs\tunnel.log"
}
