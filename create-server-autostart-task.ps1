# Create the "ANA Server Autostart" scheduled task
# Usage: powershell -File "create-server-autostart-task.ps1"
# This task starts the dashboard server at system startup.

param(
    [string]$AnaDir = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

$taskName = "ANA Server Autostart"
$autoStartBat = Join-Path $AnaDir "autostart-server.bat"

Write-Host "Creating scheduled task: $taskName" -ForegroundColor Cyan
Write-Host "Script directory: $AnaDir"
Write-Host "Batch file: $autoStartBat"

# Verify the batch file exists
if (!(Test-Path $autoStartBat)) {
    Write-Host "ERROR: $autoStartBat not found!" -ForegroundColor Red
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
    # WorkingDirectory 지정 필수(미지정 시 cwd=System32)
    $action = New-ScheduledTaskAction -Execute $autoStartBat -WorkingDirectory $AnaDir
    # Interactive 로그온 유형은 사용자 로그온이 있어야 실행되므로 부팅(AtStartup) 트리거는 동작하지 않는다 → 로그온 트리거 사용
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Compatibility Win8 -StartWhenAvailable

    Register-ScheduledTask -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description "Starts the ANA dashboard server at system startup" `
        -Force | Out-Null

    Write-Host "✓ Task '$taskName' created successfully!" -ForegroundColor Green
    Write-Host "  Trigger: At system startup" -ForegroundColor Green
    Write-Host "  Status: Ready" -ForegroundColor Green
    exit 0
} catch {
    Write-Host "ERROR: Failed to create task: $_" -ForegroundColor Red
    exit 1
}
