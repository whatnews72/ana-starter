# Create the "ANA Vocab Git Sync" scheduled task
# Usage: powershell -File "create-vocab-sync-task.ps1"
# This task runs daily at 05:50 to commit and push new vocab words to GitHub.

param(
    [string]$AnaDir = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

$taskName = "ANA Vocab Git Sync"
$syncScript = Join-Path $AnaDir "sync-deploy.ps1"

Write-Host "Creating scheduled task: $taskName" -ForegroundColor Cyan
Write-Host "Script directory: $AnaDir"
Write-Host "Sync script: $syncScript"

# Verify the sync script exists
if (!(Test-Path $syncScript)) {
    Write-Host "ERROR: $syncScript not found!" -ForegroundColor Red
    exit 1
}

# Check if task already exists and delete it
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($null -ne $existingTask) {
    Write-Host "Existing task found. Removing..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Start-Sleep -Seconds 1
}

# Create the task
try {
    # Action: Run PowerShell with the sync script
    # Use -NoProfile to skip profile loading (faster), -ExecutionPolicy Bypass to allow script execution
    $scriptBlock = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$syncScript`""
    # WorkingDirectory 미지정 시 cwd가 System32가 되어 상대경로가 모두 깨진다
    $action = New-ScheduledTaskAction -Execute "powershell" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$syncScript`"" -WorkingDirectory $AnaDir

    # Trigger: Daily at 05:50
    $trigger = New-ScheduledTaskTrigger -Daily -At "05:50"

    # RunLevel Highest(관리자 토큰)로 실행하면 Git Credential Manager가 일반 세션의 wincredman 자격 증명을
    # 읽지 못해 push가 인증 오류로 실패한다. git push에는 관리자 권한이 필요 없으므로 Limited로 등록한다
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Compatibility Win8 -StartWhenAvailable

    Register-ScheduledTask -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description "Commits and pushes daily vocab words to GitHub (runs at 05:50, 5 min after word fetch)" `
        -Force | Out-Null

    Write-Host "✓ Task '$taskName' created successfully!" -ForegroundColor Green
    Write-Host "  Trigger: Daily at 05:50" -ForegroundColor Green
    Write-Host "  Log: logs\sync-deploy.log" -ForegroundColor Green
    Write-Host "  Status: Ready" -ForegroundColor Green
    exit 0
} catch {
    Write-Host "ERROR: Failed to create task: $_" -ForegroundColor Red
    exit 1
}
