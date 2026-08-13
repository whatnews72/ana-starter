# Shows the current external URL + access key in a popup. Run as its own
# script file (not passed as inline -Command text) so Korean characters are
# read from files as UTF-8 instead of being mangled by console-codepage
# command-line argument parsing.
$ErrorActionPreference = "SilentlyContinue"
$urlFile = Join-Path $PSScriptRoot "logs\tunnel-url.txt"
$authFile = Join-Path $PSScriptRoot "data\auth.json"

$url = if (Test-Path $urlFile) { (Get-Content $urlFile -Raw).Trim() } else { "(logs\tunnel-url.txt 확인)" }
$pw = if (Test-Path $authFile) { (Get-Content $authFile -Raw -Encoding UTF8 | ConvertFrom-Json).password } else { "(data\auth.json 확인)" }

Add-Type -AssemblyName System.Windows.Forms | Out-Null
[System.Windows.Forms.MessageBox]::Show(
  "폰에서 접속할 주소 (자동으로 클립보드에 복사됨):`n$url`n`n접근 키: $pw",
  "ANA 대시보드 - 오늘의 외부 주소",
  [System.Windows.Forms.MessageBoxButtons]::OK,
  [System.Windows.Forms.MessageBoxIcon]::Information
) | Out-Null
